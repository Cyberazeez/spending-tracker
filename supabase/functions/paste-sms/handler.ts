import { isOtpLike } from "../_shared/otp.ts";
import { MAX_BODY } from "../_shared/request.ts";
import { applyCategories, buildRows, type OwnAccount } from "../_shared/enrich.ts";
import type { CategoryIds, Rule } from "../_shared/categorize.ts";
import { instanceFromBill, type Ob, obligationForBill } from "../_shared/obligations.ts";
import { detectReader, parseWith, READERS, SENDER_OF } from "../_shared/parsers/index.ts";
import { type IngestDeps, storeAndParse, type StoreOutcome } from "../ingest/handler.ts";

/** How close in time a stored purchase must be to count as the same one (owner's pick 2026-11-20). */
export const DUPLICATE_WINDOW_MS = 10 * 60 * 1000;
export const PASTE_LIMIT_PER_DAY = 200;
const MAX_FUTURE_MS = 10 * 60 * 1000;
/** The sender a pasted message is stored under when no reader understood it (only an AI reading can save it). */
export const PASTED_SENDER = "pasted";

export interface Duplicate {
  id: string;
  merchant: string | null;
  amountHalalas: number;
  occurredAt: string;
  categoryId: string | null;
}

export interface PasteDeps {
  /** The signed-in user from the request's JWT, or null. Never a user id from the body. */
  authUser(req: Request): Promise<string | null>;
  bumpRateLimit(userId: string): Promise<number>;
  loadOwnAccounts(userId: string): Promise<OwnAccount[]>;
  loadCategorization(userId: string): Promise<{ ids: CategoryIds; rules: Rule[] }>;
  loadBills(userId: string): Promise<Ob[]>;
  /** Stored, not deleted transactions of this amount within the window, on one of these cards or accounts. */
  findDuplicates(
    userId: string,
    q: { amountHalalas: number; occurredAt: string; last4s: string[] },
  ): Promise<Duplicate[]>;
  /** The person's AI switch and the paid plan: Read with AI is offered. */
  aiAvailable(userId: string): Promise<boolean>;
  /** The ingest pipeline: without an AI reader, or with one (only when the person tapped Read with AI). */
  ingest(ai: boolean): IngestDeps;
}

const json = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });

interface PasteRequest {
  action: "preview" | "commit";
  body: string;
  reader: string | null;
  receivedAt: Date;
  ai: boolean;
}

export function parsePasteRequest(
  raw: unknown,
  now = new Date(),
): { ok: true; value: PasteRequest } | { ok: false; error: string } {
  if (typeof raw !== "object" || raw === null) return { ok: false, error: "invalid_json" };
  const r = raw as Record<string, unknown>;
  if (r.action !== "preview" && r.action !== "commit") {
    return { ok: false, error: "invalid_action" };
  }
  if (typeof r.body !== "string" || r.body.trim() === "" || r.body.length > MAX_BODY) {
    return { ok: false, error: "invalid_body" };
  }
  let reader: string | null = null;
  if (r.reader !== undefined && r.reader !== null) {
    if (typeof r.reader !== "string" || !Object.hasOwn(READERS, r.reader)) {
      return { ok: false, error: "invalid_reader" };
    }
    reader = r.reader;
  }
  let receivedAt = now;
  if (r.received_at !== undefined && r.received_at !== null) {
    const d = new Date(String(r.received_at));
    if (Number.isNaN(d.getTime())) return { ok: false, error: "invalid_received_at" };
    receivedAt = d.getTime() - now.getTime() > MAX_FUTURE_MS ? now : d;
  }
  return {
    ok: true,
    value: { action: r.action, body: r.body, reader, receivedAt, ai: r.ai === true },
  };
}

/**
 * A bank or bill message the person pasted. `preview` reads it and writes nothing: what was found, the category its
 * rules give, the bill it updates and any stored purchase that looks the same. `commit` stores it through the same
 * pipeline as the Shortcut's messages. Never logs or echoes the message body.
 */
export async function handlePaste(req: Request, deps: PasteDeps): Promise<Response> {
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });
  const userId = await deps.authUser(req);
  if (!userId) return json(401, { error: "unauthorized" });
  if ((await deps.bumpRateLimit(userId)) > PASTE_LIMIT_PER_DAY) {
    return json(429, { error: "rate_limited" });
  }
  let payload: unknown;
  try {
    payload = await req.json();
  } catch {
    return json(400, { error: "invalid_json" });
  }
  const p = parsePasteRequest(payload);
  if (!p.ok) return json(400, { error: p.error });
  const { action, body, receivedAt, ai } = p.value;
  // A one-time code is never read or stored from a paste.
  if (isOtpLike(body)) {
    return json(200, { reader: null, result: { kind: "ignored", reason: "otp" } });
  }
  const reader = p.value.reader ?? detectReader(body, receivedAt);
  const detected = p.value.reader === null && reader !== null;

  if (action === "commit") {
    if (!reader && !ai) return json(400, { error: "no_reader" });
    const sender = reader ? SENDER_OF[reader] : PASTED_SENDER;
    const out: StoreOutcome = await storeAndParse(
      deps.ingest(ai),
      userId,
      sender,
      body,
      receivedAt,
      undefined,
      reader ? (b, d) => parseWith(reader, b, d) : () => ({ kind: "unparsed" }),
    );
    return json(200, { ok: true, ...out });
  }

  const r = reader ? parseWith(reader, body, receivedAt) : { kind: "unparsed" as const };
  if (r.kind === "transaction") {
    const [own, cat] = await Promise.all([
      deps.loadOwnAccounts(userId),
      deps.loadCategorization(userId).catch(() => ({
        ids: {} as CategoryIds,
        rules: [] as Rule[],
      })),
    ]);
    const head = applyCategories(buildRows(r.txn, own), cat.rules, cat.ids)[0];
    const last4s = [head.card_last4, head.account_last4].filter((x): x is string => !!x);
    const duplicates = await deps.findDuplicates(userId, {
      amountHalalas: head.amount_halalas,
      occurredAt: head.occurred_at,
      last4s,
    });
    return json(200, {
      reader,
      detected,
      result: {
        kind: "transaction",
        type: head.type,
        direction: head.direction,
        bank: head.bank,
        amountHalalas: head.amount_halalas,
        merchant: head.merchant_raw,
        cardLast4: head.card_last4,
        accountLast4: head.account_last4,
        occurredAt: head.occurred_at,
        isInternal: head.is_internal,
        categoryId: head.category_id ?? null,
      },
      duplicates,
    });
  }
  if (r.kind === "notice" && r.notice === "bill_issued") {
    const bills = await deps.loadBills(userId);
    const ob = obligationForBill(bills, r.lineLast4, r.biller);
    const inst = ob ? instanceFromBill(ob, r.totalHalalas, receivedAt) : null;
    return json(200, {
      reader,
      detected,
      result: {
        kind: "bill",
        biller: r.biller,
        lineLast4: r.lineLast4,
        totalHalalas: r.totalHalalas,
        issuedAt: receivedAt.toISOString(),
        bill: ob && inst
          ? {
            id: ob.id,
            name: ob.name,
            expectedHalalas: ob.expectedHalalas,
            periodStart: inst.periodStart,
            dueDate: inst.dueDate,
          }
          : null,
      },
    });
  }
  if (r.kind === "notice") {
    return json(200, {
      reader,
      detected,
      result: {
        kind: "statement",
        cardLast4: r.cardLast4 ?? null,
        totalDueHalalas: r.totalDueHalalas,
        dueDate: r.dueDate,
      },
    });
  }
  if (r.kind === "ignored") {
    return json(200, { reader, detected, result: { kind: "ignored", reason: r.reason } });
  }
  return json(200, {
    reader,
    detected,
    result: { kind: "unparsed", aiAvailable: await deps.aiAvailable(userId).catch(() => false) },
  });
}

/** Within the duplicate window of [occurredAt], both ways (exactly 10 minutes counts). */
export function withinWindow(a: string, b: string): boolean {
  return Math.abs(new Date(a).getTime() - new Date(b).getTime()) <= DUPLICATE_WINDOW_MS;
}
