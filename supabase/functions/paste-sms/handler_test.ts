import assert from "node:assert/strict";
import { handlePaste, PASTED_SENDER, type PasteDeps, withinWindow } from "./handler.ts";
import type { IngestDeps, RawMessageRow, SaveParsedArgs } from "../ingest/handler.ts";
import type { Ob } from "../_shared/obligations.ts";
import type { AiParseOutcome } from "../_shared/ai_parse.ts";

const FIXTURES = new URL("../../tests/fixtures/", import.meta.url);
const fixture = (p: string) =>
  JSON.parse(Deno.readTextFileSync(new URL(p, FIXTURES))) as {
    body: string;
    receivedAt: string;
  };
const PURCHASE = fixture("alinma/purchase_mcdonalds.json");
const SE_BILL = fixture("se/bill_issued.json");
const STC_BILL = fixture("stc900/mobile_bill.json");

const SE_OB: Ob = {
  id: "ob-se",
  name: "Electricity",
  kind: "bill",
  expectedHalalas: 45000,
  dueRule: { type: "day_of_month", day: 25 },
  match: { line: "4579", biller: "se" },
} as Ob;

function setup(opts: {
  user?: string | null;
  bills?: Ob[];
  duplicates?: Awaited<ReturnType<PasteDeps["findDuplicates"]>>;
  aiAvailable?: boolean;
  aiParse?: IngestDeps["aiParse"];
} = {}) {
  const raws: RawMessageRow[] = [];
  const saved: SaveParsedArgs[] = [];
  const notices: unknown[] = [];
  const dupQueries: unknown[] = [];
  const aiFlags: boolean[] = [];
  const ingest = (ai: boolean): IngestDeps => {
    aiFlags.push(ai);
    return {
      aiParse: ai ? opts.aiParse : undefined,
      findToken: () => Promise.resolve(null),
      bumpRateLimit: () => Promise.resolve(1),
      insertRaw: (row) => {
        if (raws.some((r) => r.dedupe_hash === row.dedupe_hash)) return Promise.resolve(null);
        raws.push(row);
        return Promise.resolve(`raw${raws.length}`);
      },
      findRetryableRaw: () => Promise.resolve(null),
      touchToken: () => Promise.resolve(),
      loadOwnAccounts: () => Promise.resolve([]),
      loadCategorization: () => Promise.resolve({ ids: {}, rules: [] }),
      findTransferCounterparts: () => Promise.resolve([]),
      markInternal: () => Promise.resolve(),
      saveOwnAccounts: () => Promise.resolve(),
      saveParsed: (a) => {
        saved.push(a);
        return Promise.resolve({ ids: Object.fromEntries(a.rows.map((r) => [r.type, "tx1"])) });
      },
      obligations: {
        refresh: () => Promise.resolve(),
        loadObligations: () => Promise.resolve({ obs: opts.bills ?? [], open: [] }),
        upsertNoticeInstance: (a) => {
          notices.push(a);
          return Promise.resolve();
        },
        applyMatch: () => Promise.resolve(),
        setDueDate: () => Promise.resolve(),
      },
    };
  };
  const deps: PasteDeps = {
    authUser: () => Promise.resolve(opts.user === undefined ? "user1" : opts.user),
    bumpRateLimit: () => Promise.resolve(1),
    loadOwnAccounts: () => Promise.resolve([]),
    loadCategorization: () =>
      Promise.resolve({
        ids: { Dining: "c-din" },
        rules: [{
          id: "r1",
          pattern: "mcdonalds",
          matchType: "contains" as const,
          categoryId: "c-din",
          status: "confirmed" as const,
          source: "user" as const,
        }],
      }),
    loadBills: () => Promise.resolve(opts.bills ?? []),
    findDuplicates: (_u, q) => {
      dupQueries.push(q);
      return Promise.resolve(opts.duplicates ?? []);
    },
    aiAvailable: () => Promise.resolve(opts.aiAvailable ?? false),
    ingest,
  };
  const call = async (body: Record<string, unknown>) => {
    const res = await handlePaste(
      new Request("https://x.test/paste-sms", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(body),
      }),
      deps,
    );
    return { status: res.status, json: await res.json() };
  };
  return { call, raws, saved, notices, dupQueries, aiFlags };
}

Deno.test("paste: needs a signed-in user", async () => {
  const s = setup({ user: null });
  const r = await s.call({ action: "preview", body: PURCHASE.body });
  assert.equal(r.status, 401);
});

Deno.test("paste preview: finds the bank, reads the purchase, applies the rule, writes nothing", async () => {
  const s = setup();
  const r = await s.call({
    action: "preview",
    body: PURCHASE.body,
    received_at: PURCHASE.receivedAt,
  });
  assert.equal(r.status, 200);
  assert.equal(r.json.reader, "alinma");
  assert.equal(r.json.detected, true);
  assert.equal(r.json.result.kind, "transaction");
  assert.equal(r.json.result.amountHalalas, 3900);
  assert.equal(r.json.result.cardLast4, "8119");
  assert.equal(r.json.result.categoryId, "c-din");
  assert.deepEqual(s.dupQueries, [{
    amountHalalas: 3900,
    occurredAt: r.json.result.occurredAt,
    last4s: ["8119"],
  }]);
  assert.equal(s.raws.length, 0);
  assert.equal(s.saved.length, 0);
});

Deno.test("paste preview: shows a stored purchase that looks the same", async () => {
  const dup = {
    id: "t9",
    merchant: "MCDONALDS",
    amountHalalas: 3900,
    occurredAt: "2026-10-28T18:32:00.000Z",
    categoryId: "c-din",
  };
  const s = setup({ duplicates: [dup] });
  const r = await s.call({ action: "preview", body: PURCHASE.body });
  assert.deepEqual(r.json.duplicates, [dup]);
});

Deno.test("paste: the duplicate window is 10 minutes both ways, inclusive", () => {
  const t = "2026-11-20T11:00:00.000Z";
  assert.ok(withinWindow(t, "2026-11-20T11:10:00.000Z"));
  assert.ok(withinWindow(t, "2026-11-20T10:50:00.000Z"));
  assert.ok(!withinWindow(t, "2026-11-20T11:10:01.000Z"));
});

Deno.test("paste commit: stored under the bank's sender and saved like a Shortcut message", async () => {
  const s = setup();
  const r = await s.call({
    action: "commit",
    body: PURCHASE.body,
    received_at: PURCHASE.receivedAt,
  });
  assert.equal(r.status, 200);
  assert.equal(r.json.outcome, "parsed");
  assert.equal(s.raws[0].sender, "alinma");
  assert.ok(!/1,000\.00/.test(s.raws[0].body), "balance stripped");
  assert.equal(s.saved[0].rows[0].amount_halalas, 3900);
  assert.deepEqual(s.aiFlags, [false]);
  // pasting it again is the same message, not a second purchase
  const again = await s.call({
    action: "commit",
    body: PURCHASE.body,
    received_at: PURCHASE.receivedAt,
  });
  assert.equal(again.json.duplicate, true);
  assert.equal(s.saved.length, 1);
});

Deno.test("paste preview: an electricity bill finds its bill; an STC line with the same digits does not", async () => {
  const stcSameDigits = { ...SE_OB, id: "ob-stc", match: { line: "4579" } } as Ob;
  const s = setup({ bills: [stcSameDigits, SE_OB] });
  const r = await s.call({
    action: "preview",
    body: SE_BILL.body,
    received_at: SE_BILL.receivedAt,
  });
  assert.equal(r.json.reader, "se");
  assert.equal(r.json.result.kind, "bill");
  assert.equal(r.json.result.biller, "se");
  assert.equal(r.json.result.totalHalalas, 50016);
  assert.equal(r.json.result.bill.id, "ob-se");
  assert.equal(r.json.result.bill.periodStart, "2026-11-01");
  assert.equal(s.notices.length, 0);
});

Deno.test("paste preview: a bill with no matching bill offers to create one", async () => {
  const s = setup({ bills: [] });
  const r = await s.call({ action: "preview", body: STC_BILL.body });
  assert.equal(r.json.reader, "stc900");
  assert.equal(r.json.result.bill, null);
  assert.equal(r.json.result.lineLast4, "0569");
});

Deno.test("paste commit: a bill updates that month's bill and keeps only the facts", async () => {
  const s = setup({ bills: [SE_OB] });
  const r = await s.call({
    action: "commit",
    body: SE_BILL.body,
    received_at: SE_BILL.receivedAt,
  });
  assert.equal(r.json.outcome, "notice");
  assert.equal(s.notices.length, 1);
  assert.equal(s.raws[0].sender, "se");
  assert.match(
    String(s.saved[0].replaceBody),
    /Saudi Electricity account ending 4579, total 500\.16/,
  );
});

Deno.test("paste: an unknown message offers AI only while it is on; nothing is guessed", async () => {
  const off = await setup().call({ action: "preview", body: "Hello, your parcel is on the way" });
  assert.equal(off.json.reader, null);
  assert.deepEqual(off.json.result, { kind: "unparsed", ambiguous: false, aiAvailable: false });
  const on = await setup({ aiAvailable: true }).call({
    action: "preview",
    body: "Hello, your parcel is on the way",
  });
  assert.equal(on.json.result.aiAvailable, true);
  // committing an unread message without asking for AI is refused
  const s = setup();
  const c = await s.call({ action: "commit", body: "Hello, your parcel is on the way" });
  assert.equal(c.status, 400);
  assert.equal(s.raws.length, 0);
});

Deno.test("paste commit with AI: only when asked, stored under the pasted sender", async () => {
  const ai: AiParseOutcome = {
    ok: true,
    result: {
      kind: "transaction",
      parser: "ai/v1",
      confidence: 0.9,
      txn: {
        type: "purchase",
        direction: "out",
        amountHalalas: 2500,
        merchant: "SHOP",
        occurredAt: "2026-11-20T10:00:00.000Z",
      },
    },
  } as AiParseOutcome;
  const s = setup({ aiParse: () => Promise.resolve(ai) });
  const r = await s.call({ action: "commit", body: "Unknown bank: paid 25 SAR at SHOP", ai: true });
  assert.equal(r.status, 200);
  assert.equal(r.json.outcome, "review");
  assert.equal(s.raws[0].sender, PASTED_SENDER);
  assert.deepEqual(s.aiFlags, [true]);
});

Deno.test("paste: a one-time code is never read or stored", async () => {
  const s = setup();
  const r = await s.call({ action: "commit", body: "Your OTP is 123456. Do not share it." });
  assert.equal(r.json.result.kind, "ignored");
  assert.equal(s.raws.length, 0);
});

Deno.test("paste: a chosen bank must be one we read", async () => {
  const r = await setup().call({ action: "preview", body: "x", reader: "constructor" });
  assert.equal(r.status, 400);
});

Deno.test("paste commit: checks for the same purchase again; Add anyway (force) saves it", async () => {
  const dup = {
    id: "t9",
    merchant: "MCDONALDS",
    amountHalalas: 3900,
    occurredAt: "2026-10-28T18:32:00.000Z",
    categoryId: null,
  };
  const s = setup({ duplicates: [dup] });
  const r = await s.call({
    action: "commit",
    body: PURCHASE.body,
    received_at: PURCHASE.receivedAt,
  });
  assert.equal(r.status, 409);
  assert.deepEqual(r.json.duplicates, [dup]);
  assert.equal(s.raws.length, 0);
  const f = await s.call({
    action: "commit",
    body: PURCHASE.body,
    received_at: PURCHASE.receivedAt,
    force: true,
  });
  assert.equal(f.status, 200);
  assert.equal(s.saved.length, 1);
});

Deno.test("paste: preview answers with the time it read with, and refuses a very old one", async () => {
  const ok = await setup().call({
    action: "preview",
    body: PURCHASE.body,
    received_at: PURCHASE.receivedAt,
  });
  assert.equal(ok.json.receivedAt, PURCHASE.receivedAt);
  const old = await setup().call({
    action: "preview",
    body: PURCHASE.body,
    received_at: "1990-01-01T00:00:00Z",
  });
  assert.equal(old.status, 400);
  assert.equal(old.json.error, "too_old");
});

Deno.test("paste with AI and a chosen bank: stored under the pasted sender, never the bank's", async () => {
  const s = setup({
    aiParse: () => Promise.resolve({ ok: false, reason: "not_allowed" } as AiParseOutcome),
  });
  await s.call({ action: "commit", body: "Unknown text", reader: "alinma", ai: true });
  assert.equal(s.raws[0].sender, PASTED_SENDER);
});
