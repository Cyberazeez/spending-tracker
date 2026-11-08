import { dedupeKey } from "../_shared/dedupe.ts";
import { isOtpLike, REDACTED_BODY } from "../_shared/otp.ts";
import { stripBalances } from "../_shared/redact.ts";
import { parseIngestPayload } from "../_shared/request.ts";
import { isWellFormedToken, sha256Hex } from "../_shared/token.ts";
import { applyCategories, buildRows, type OwnAccount, type TxRow } from "../_shared/enrich.ts";
import type { CategoryIds, Rule } from "../_shared/categorize.ts";
import { type ParseResult, parseSms } from "../_shared/parsers/index.ts";
import type { AiParseOutcome } from "../_shared/ai_parse.ts";
import { applyNotice, applyTransactions, type ObligationDeps } from "./obligations_flow.ts";

export const RATE_LIMIT_PER_MINUTE = 60;
export const RATE_LIMIT_PER_DAY = 500;

export interface RawMessageRow {
  user_id: string;
  sender: string;
  body: string;
  received_at: string;
  dedupe_hash: string;
  parse_status: "needs_review" | "ignored";
  ignore_reason: string | null;
}

export interface IngestDeps {
  /** Returns the active (not revoked) token's owner, or null. */
  findToken(hash: string): Promise<{ id: string; userId: string } | null>;
  /** Increments and returns the count for the current minute or day window. */
  bumpRateLimit(userId: string, window: "minute" | "day"): Promise<number>;
  /** Returns the new id, or null when the dedupe hash already exists. */
  insertRaw(row: RawMessageRow): Promise<string | null>;
  /**
   * The id of an already stored copy of this message that was never parsed (an earlier try failed after the raw row
   * was saved), so a retry can finish the job instead of being dropped as a duplicate. Null when there is none.
   */
  findRetryableRaw(userId: string, dedupeHash: string): Promise<string | null>;
  touchToken(tokenId: string): Promise<void>;
  loadOwnAccounts(userId: string): Promise<OwnAccount[]>;
  loadCategorization(userId: string): Promise<{ ids: CategoryIds; rules: Rule[] }>;
  /** Stores the transactions (if any) and updates the raw message's parse status in one go. */
  saveParsed(args: SaveParsedArgs): Promise<SaveResult>;
  /**
   * Transfers of the opposite direction, same amount, from another bank, within 5 minutes of this one: a move
   * between the owner's own accounts is reported once by each bank.
   */
  findTransferCounterparts(
    userId: string,
    t: { type: string; bank: string; amountHalalas: number; occurredAt: string },
  ): Promise<{ id: string; isInternal: boolean }[]>;
  /** Flags stored transfers as internal (not spending) and files the uncategorised ones under Transfers. */
  markInternal(userId: string, ids: string[], transfersCategoryId: string | null): Promise<void>;
  obligations: ObligationDeps;
  /**
   * Reads an SMS that no regex parser understood, with AI. Only for paying accounts that switched AI reading on; the
   * implementation returns null otherwise. Optional: without it ingest behaves exactly as before.
   */
  aiParse?(
    userId: string,
    sender: string,
    body: string,
    receivedAt: Date,
  ): Promise<AiParseOutcome | null>;
  /**
   * True once this person has confirmed enough AI readings from this sender (AI_TRUST_AFTER): later readings are
   * saved as plain `parsed` instead of waiting for a check. Optional; without it every AI reading is checked.
   */
  aiTrusted?(userId: string, sender: string): Promise<boolean>;
}

/** Confirmed AI readings from one sender after which that sender no longer needs checking. */
export const AI_TRUST_AFTER = 5;

/** Ids of the stored transactions by type (a transfer and its fee are two rows of one SMS). */
export interface SaveResult {
  ids: Record<string, string>;
}

export interface SaveParsedArgs {
  userId: string;
  rawId: string;
  parser: string;
  status: "parsed" | "ignored" | "ai_parsed";
  /** How sure the reader was (1 for regex parsers). */
  confidence?: number;
  ignoreReason?: string;
  /** The parser recognised a one-time code the generic filter missed: blank the stored body. */
  redactBody?: boolean;
  /** Replaces the stored body (a bill notice keeps only its facts, not the name, account or payment links). */
  replaceBody?: string;
  rows: TxRow[];
}

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });
}

/**
 * Authenticates, rate-limits, dedupes and stores the raw message, then parses it. A message that cannot
 * be parsed stays `needs_review`; a failure while saving the parse result also leaves it there, so no
 * SMS is ever lost. Never logs or echoes the message body.
 */
export async function handleIngest(req: Request, deps: IngestDeps): Promise<Response> {
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  const token = req.headers.get("x-ingest-token");
  if (!isWellFormedToken(token)) return json(401, { error: "unauthorized" });
  const found = await deps.findToken(await sha256Hex(token));
  if (!found) return json(401, { error: "unauthorized" });

  if (
    (await deps.bumpRateLimit(found.userId, "minute")) > RATE_LIMIT_PER_MINUTE ||
    (await deps.bumpRateLimit(found.userId, "day")) > RATE_LIMIT_PER_DAY
  ) {
    return json(429, { error: "rate_limited" });
  }

  let payload: unknown;
  try {
    payload = await req.json();
  } catch {
    return json(400, { error: "invalid_json" });
  }
  const parsed = parseIngestPayload(payload);
  if (!parsed.ok) return json(400, { error: parsed.error });
  const { sender, body, receivedAt } = parsed.value;

  const otp = isOtpLike(body);
  const storedBody = otp ? REDACTED_BODY : stripBalances(body);
  // Hash what is stored, so a one-time code can never be recovered from the hash.
  const hash = await dedupeKey(sender, storedBody, receivedAt);
  let id = await deps.insertRaw({
    user_id: found.userId,
    sender,
    body: storedBody,
    received_at: receivedAt.toISOString(),
    dedupe_hash: hash,
    parse_status: otp ? "ignored" : "needs_review",
    ignore_reason: otp ? "otp" : null,
  });
  const duplicate = id === null;
  // A replay of a message whose first parse failed finishes the parse now (rows are unique per raw message and type).
  if (id === null && !otp) id = await deps.findRetryableRaw(found.userId, hash);
  // The first attempt that fails is answered with an error so the app sends it again; a second failure is answered
  // with success so one message that can never be parsed does not stay in the app's queue forever.
  const retrying = duplicate && id !== null;
  await deps.touchToken(found.id);

  if (id !== null && !otp) {
    try {
      let r: ParseResult = parseSms(sender, body, receivedAt);
      let aiConfidence: number | undefined;
      let aiTrusted = false;
      if (r.kind === "unparsed" && deps.aiParse) {
        // The AI reading never blocks ingest: any problem leaves the message in Needs review as before.
        const ai = await deps.aiParse(found.userId, sender, body, receivedAt).catch((e) => {
          console.error("ai_parse_failed", (e as Error).message);
          return null;
        });
        if (ai?.ok) {
          const a = ai.result;
          if (a.kind === "transaction") {
            aiConfidence = a.confidence;
            aiTrusted = await (deps.aiTrusted?.(found.userId, sender) ?? Promise.resolve(false))
              .catch(
                () => false,
              );
            r = {
              kind: "transaction",
              parser: a.parser,
              txn: { bank: "other", ...a.txn },
            };
          } else if (a.kind === "ignored") {
            r = { kind: "ignored", parser: a.parser, reason: a.reason };
          }
        }
      }
      if (r.kind === "transaction") {
        // A failed rules load must not cost the transaction: save it uncategorised.
        const cat = await deps.loadCategorization(found.userId).catch(() => ({
          ids: {} as CategoryIds,
          rules: [] as Rule[],
        }));
        const built = buildRows(r.txn, await deps.loadOwnAccounts(found.userId));
        // The other bank's message of the same move: tells an unmarked incoming transfer it is internal, or
        // (below, once saved) an earlier incoming one. Best effort: a failed lookup leaves the rows as parsed.
        const head = built[0];
        let toMark: string[] = [];
        if (head.type === "transfer_in" || head.type === "transfer_out") {
          const others = await deps.findTransferCounterparts(found.userId, {
            type: head.type === "transfer_in" ? "transfer_out" : "transfer_in",
            bank: head.bank,
            amountHalalas: head.amount_halalas,
            occurredAt: head.occurred_at,
          }).catch(() => []);
          if (head.is_internal) {
            toMark = others.filter((o) => !o.isInternal).map((o) => o.id);
          } else if (others.some((o) => o.isInternal)) {
            // Either direction: the other bank's message of the same move is already known to be internal.
            head.is_internal = true;
            head.excluded_from_spend = true;
          }
        }
        const rows = applyCategories(built, cat.rules, cat.ids);
        const saved = await deps.saveParsed({
          userId: found.userId,
          rawId: id,
          parser: r.parser,
          status: aiConfidence === undefined || aiTrusted ? "parsed" : "ai_parsed",
          confidence: aiConfidence,
          rows,
        });
        if (toMark.length) {
          await deps.markInternal(found.userId, toMark, cat.ids["Transfers"] ?? null).catch((e) =>
            console.error("mark_internal_failed", (e as Error).message)
          );
        }
        // The transaction is safe by now; tracking obligations is best effort and never fails the SMS.
        await applyTransactions(deps.obligations, found.userId, rows, saved.ids).catch((e) =>
          console.error("obligation_match_failed", (e as Error).message)
        );
      } else if (r.kind === "notice") {
        // The instance comes first and is not best effort: if it fails the raw row stays needs_review, the call
        // fails and the retry runs this again (the upsert is safe to repeat). Marking the SMS parsed first would
        // make the replay a plain duplicate and the bill or statement would never appear.
        await applyNotice(deps.obligations, found.userId, id, receivedAt, r);
        await deps.saveParsed({
          userId: found.userId,
          rawId: id,
          parser: r.parser,
          status: "parsed",
          replaceBody: r.notice === "bill_issued"
            ? `[bill notice] STC line ending ${r.lineLast4}, total ${
              (r.totalHalalas / 100).toFixed(2)
            } SAR`
            : undefined,
          rows: [],
        });
      } else if (r.kind === "ignored") {
        await deps.saveParsed({
          userId: found.userId,
          rawId: id,
          parser: r.parser,
          status: "ignored",
          ignoreReason: r.reason,
          redactBody: r.reason === "otp",
          rows: [],
        });
      }
    } catch (e) {
      // The raw message is stored; answering with an error makes the app send it again, and the retry parses it.
      console.error("parse_save_failed", (e as Error).message);
      if (!retrying) throw e;
    }
  }

  return json(200, { ok: true, duplicate });
}
