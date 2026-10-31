import { dedupeKey } from "../_shared/dedupe.ts";
import { isOtpLike, REDACTED_BODY } from "../_shared/otp.ts";
import { stripBalances } from "../_shared/redact.ts";
import { parseIngestPayload } from "../_shared/request.ts";
import { isWellFormedToken, sha256Hex } from "../_shared/token.ts";
import { applyCategories, buildRows, type OwnAccount, type TxRow } from "../_shared/enrich.ts";
import type { CategoryIds, Rule } from "../_shared/categorize.ts";
import { parseSms } from "../_shared/parsers/index.ts";
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
  touchToken(tokenId: string): Promise<void>;
  loadOwnAccounts(userId: string): Promise<OwnAccount[]>;
  loadCategorization(userId: string): Promise<{ ids: CategoryIds; rules: Rule[] }>;
  /** Stores the transactions (if any) and updates the raw message's parse status in one go. */
  saveParsed(args: SaveParsedArgs): Promise<SaveResult>;
  obligations: ObligationDeps;
}

/** Ids of the stored transactions by type (a transfer and its fee are two rows of one SMS). */
export interface SaveResult {
  ids: Record<string, string>;
}

export interface SaveParsedArgs {
  userId: string;
  rawId: string;
  parser: string;
  status: "parsed" | "ignored";
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
  const id = await deps.insertRaw({
    user_id: found.userId,
    sender,
    body: storedBody,
    received_at: receivedAt.toISOString(),
    // Hash what is stored, so a one-time code can never be recovered from the hash.
    dedupe_hash: await dedupeKey(sender, storedBody, receivedAt),
    parse_status: otp ? "ignored" : "needs_review",
    ignore_reason: otp ? "otp" : null,
  });
  await deps.touchToken(found.id);

  if (id !== null && !otp) {
    try {
      const r = parseSms(sender, body, receivedAt);
      if (r.kind === "transaction") {
        // A failed rules load must not cost the transaction: save it uncategorised.
        const cat = await deps.loadCategorization(found.userId).catch(() => ({
          ids: {} as CategoryIds,
          rules: [] as Rule[],
        }));
        const rows = applyCategories(
          buildRows(r.txn, await deps.loadOwnAccounts(found.userId)),
          cat.rules,
          cat.ids,
        );
        const saved = await deps.saveParsed({
          userId: found.userId,
          rawId: id,
          parser: r.parser,
          status: "parsed",
          rows,
        });
        // The transaction is safe by now; tracking obligations is best effort and never fails the SMS.
        await applyTransactions(deps.obligations, found.userId, rows, saved.ids).catch((e) =>
          console.error("obligation_match_failed", (e as Error).message)
        );
      } else if (r.kind === "notice") {
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
        await applyNotice(deps.obligations, found.userId, id, receivedAt, r).catch((e) =>
          console.error("obligation_notice_failed", (e as Error).message)
        );
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
      console.error("parse_save_failed", (e as Error).message);
    }
  }

  return json(200, { ok: true, duplicate: id === null });
}
