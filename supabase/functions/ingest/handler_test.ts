import assert from "node:assert/strict";
import {
  handleIngest,
  type IngestDeps,
  RATE_LIMIT_PER_DAY,
  RATE_LIMIT_PER_MINUTE,
  type RawMessageRow,
  type SaveParsedArgs,
} from "./handler.ts";
import type { Inst, Ob } from "../_shared/obligations.ts";
import type { AiParseOutcome } from "../_shared/ai_parse.ts";
import { generateToken, sha256Hex } from "../_shared/token.ts";

const OWN = [
  { bank: "alinma", last4: "6000" },
  { bank: "d360", last4: "5911" },
];

const CATS = {
  Dining: "c-dining",
  Fees: "c-fees",
  Transfers: "c-transfers",
  Horse: "c-horse",
  Subscriptions: "c-subs",
};
const RULES = [
  {
    id: "r1",
    pattern: "apple com bill",
    matchType: "contains" as const,
    categoryId: "c-subs",
    status: "confirmed" as const,
    source: "seed" as const,
  },
  {
    id: "r2",
    pattern: "acct:7892",
    matchType: "exact" as const,
    categoryId: "c-horse",
    status: "confirmed" as const,
    source: "seed" as const,
  },
];

type Cand = import("../_shared/enrich.ts").TransferCandidate;
/** A stored transfer that could be the other bank's message of the same move. */
function cand(c: Partial<Cand> & { id: string }): Cand {
  return {
    isInternal: false,
    type: "transfer_out",
    bank: "barq",
    accountLast4: null,
    counterpartyLast4: null,
    ...c,
  };
}

async function setup(
  opts: {
    minute?: number;
    day?: number;
    failSave?: boolean;
    failRules?: boolean;
    failObligations?: boolean;
    failNotice?: boolean;
    failPairLookup?: boolean;
    counterparts?: Cand[];
    /** What a second lookup (after the row is stored) finds: the partner that arrived at the same moment. */
    counterpartsLater?: Cand[];
    obs?: Ob[];
    open?: Inst[];
    aiParse?: IngestDeps["aiParse"];
    aiTrusted?: IngestDeps["aiTrusted"];
  } = {},
) {
  const token = generateToken();
  const hash = await sha256Hex(token);
  const rows: RawMessageRow[] = [];
  const saved: SaveParsedArgs[] = [];
  const seen = new Set<string>();
  const noticeInstances: Parameters<IngestDeps["obligations"]["upsertNoticeInstance"]>[0][] = [];
  const matches: Parameters<IngestDeps["obligations"]["applyMatch"]>[0][] = [];
  const dueDates: [string, string][] = [];
  let refreshed = 0;
  let touched = 0;
  const transferLookups: {
    type: string;
    bank: string;
    amountHalalas: number;
    occurredAt: string;
  }[] = [];
  const marked: { ids: string[]; cat: string | null }[] = [];
  const learned: { bank: string; last4: string }[][] = [];
  const deps: IngestDeps = {
    aiParse: opts.aiParse,
    aiTrusted: opts.aiTrusted,
    findToken: (h) => Promise.resolve(h === hash ? { id: "tok1", userId: "user1" } : null),
    bumpRateLimit: (_user, window) =>
      Promise.resolve(window === "minute" ? (opts.minute ?? 1) : (opts.day ?? 1)),
    insertRaw: (row) => {
      if (seen.has(row.dedupe_hash)) return Promise.resolve(null);
      seen.add(row.dedupe_hash);
      rows.push(row);
      return Promise.resolve(`id${rows.length}`);
    },
    findRetryableRaw: (_u, h) => {
      const i = rows.findIndex((r) => r.dedupe_hash === h);
      if (i < 0) return Promise.resolve(null);
      const id = `id${i + 1}`;
      return Promise.resolve(saved.some((s) => s.rawId === id) ? null : id);
    },
    touchToken: () => {
      touched++;
      return Promise.resolve();
    },
    loadOwnAccounts: () => Promise.resolve(OWN),
    loadCategorization: () =>
      opts.failRules
        ? Promise.reject(new Error("db down"))
        : Promise.resolve({ ids: CATS, rules: RULES }),
    findTransferCounterparts: (_u, t) => {
      transferLookups.push(t);
      if (opts.failPairLookup) return Promise.reject(new Error("db down"));
      const first = transferLookups.length === 1;
      return Promise.resolve(
        (first ? opts.counterparts : opts.counterpartsLater ?? opts.counterparts) ?? [],
      );
    },
    markInternal: (_u, ids, cat) => {
      marked.push({ ids, cat });
      return Promise.resolve();
    },
    saveOwnAccounts: (_u, accounts) => {
      learned.push(accounts);
      return Promise.resolve();
    },
    saveParsed: (a) => {
      if (opts.failSave) return Promise.reject(new Error("db down"));
      saved.push(a);
      return Promise.resolve({
        ids: Object.fromEntries(a.rows.map((r, i) => [r.type, `tx${saved.length}-${i}`])),
      });
    },
    obligations: {
      refresh: () => {
        refreshed++;
        return Promise.resolve();
      },
      loadObligations: () => {
        if (opts.failObligations) return Promise.reject(new Error("db down"));
        return Promise.resolve({ obs: opts.obs ?? [], open: opts.open ?? [] });
      },
      upsertNoticeInstance: (a) => {
        if (opts.failNotice) return Promise.reject(new Error("db down"));
        noticeInstances.push(a);
        return Promise.resolve();
      },
      applyMatch: (a) => {
        matches.push(a);
        return Promise.resolve();
      },
      setDueDate: (_u, id, due) => {
        dueDates.push([id, due]);
        return Promise.resolve();
      },
    },
  };
  const call = (
    body: unknown,
    headers: Record<string, string> = { "x-ingest-token": token },
    method = "POST",
  ) =>
    handleIngest(
      new Request("https://x.test/ingest", {
        method,
        headers: { "content-type": "application/json", ...headers },
        body: method === "POST"
          ? (typeof body === "string" ? body : JSON.stringify(body))
          : undefined,
      }),
      deps,
    );
  return {
    call,
    rows,
    saved,
    token,
    touched: () => touched,
    noticeInstances,
    matches,
    dueDates,
    refreshed: () => refreshed,
    transferLookups,
    marked,
    learned,
  };
}

const SMS = {
  sender: "barq app",
  body:
    "Online Purchase\nVISA card **1224\nAmount 3.99 SAR\nBalance 621.89\nAt APPLE COM BILL\n2026-10-26 17:19",
  received_at: "2026-10-26T14:19:05Z",
};

Deno.test("ingest: rejects non-POST, missing token and unknown token with 405/401", async () => {
  const s = await setup();
  assert.equal((await s.call(SMS, {}, "GET")).status, 405);
  assert.equal((await s.call(SMS, {})).status, 401);
  assert.equal((await s.call(SMS, { "x-ingest-token": generateToken() })).status, 401);
  assert.equal((await s.call(SMS, { "x-ingest-token": "garbage" })).status, 401);
  assert.equal(s.rows.length, 0);
});

Deno.test("ingest: stores a message as needs_review and updates last_used", async () => {
  const s = await setup();
  const res = await s.call(SMS);
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { ok: true, duplicate: false });
  assert.equal(s.rows.length, 1);
  assert.equal(s.rows[0].user_id, "user1");
  assert.equal(s.rows[0].parse_status, "needs_review");
  assert.equal(s.rows[0].body, SMS.body.replace("\nBalance 621.89", ""));
  assert.equal(s.touched(), 1);
});

Deno.test("ingest: a replayed message is reported as duplicate and not stored twice", async () => {
  const s = await setup();
  await s.call(SMS);
  const res = await s.call({ ...SMS, received_at: "2026-10-26T14:19:40Z" });
  assert.deepEqual(await res.json(), { ok: true, duplicate: true });
  assert.equal(s.rows.length, 1);
});

Deno.test("ingest: two different messages in the same minute both land", async () => {
  const s = await setup();
  await s.call({ ...SMS, body: "Refund 18.16" });
  await s.call({ ...SMS, body: "Refund 73.12" });
  assert.equal(s.rows.length, 2);
});

Deno.test("ingest: OTP bodies are redacted and marked ignored", async () => {
  const s = await setup();
  const res = await s.call({
    sender: "D360 Bank",
    body: "OTP: 887448\nFor: Adding card to digital wallet",
  });
  assert.equal(res.status, 200);
  assert.equal(s.rows[0].body, "[redacted]");
  assert.equal(s.rows[0].parse_status, "ignored");
  assert.equal(s.rows[0].ignore_reason, "otp");
  assert.ok(!JSON.stringify(s.rows).includes("887448"));
});

Deno.test("ingest: rate limit returns 429 over the per-minute cap and stores nothing", async () => {
  const s = await setup({ minute: RATE_LIMIT_PER_MINUTE + 1 });
  assert.equal((await s.call(SMS)).status, 429);
  assert.equal(s.rows.length, 0);
});

Deno.test("ingest: bad payloads return 400", async () => {
  const s = await setup();
  assert.equal((await s.call("not json")).status, 400);
  assert.equal((await s.call({ sender: "x" })).status, 400);
  assert.equal((await s.call({ sender: "x", body: "y", received_at: "nope" })).status, 400);
  assert.equal(s.rows.length, 0);
});

Deno.test("ingest: responses never echo the message body", async () => {
  const s = await setup();
  const text = await (await s.call(SMS)).text();
  assert.ok(!text.includes("APPLE"));
});

Deno.test("ingest: the daily cap returns 429 even when the per-minute count is fine", async () => {
  const s = await setup({ day: RATE_LIMIT_PER_DAY + 1 });
  assert.equal((await s.call(SMS)).status, 429);
  assert.equal(s.rows.length, 0);
});

Deno.test("ingest: the dedupe hash of an OTP message does not depend on the code", async () => {
  const s = await setup();
  await s.call({ sender: "D360 Bank", body: "OTP: 111111\nFor: Adding card" });
  const second = await s.call({ sender: "D360 Bank", body: "OTP: 222222\nFor: Adding card" });
  assert.deepEqual(await second.json(), { ok: true, duplicate: true });
  assert.equal(s.rows.length, 1);
  assert.ok(!JSON.stringify(s.rows).includes("111111"));
});

Deno.test("ingest: a purchase SMS is parsed and saved as a transaction", async () => {
  const s = await setup();
  await s.call(SMS);
  assert.equal(s.saved.length, 1);
  const a = s.saved[0];
  assert.equal(a.status, "parsed");
  assert.equal(a.parser, "barq/v1");
  assert.equal(a.rows.length, 1);
  assert.equal(a.rows[0].amount_halalas, 399);
  assert.equal(a.rows[0].merchant_norm, "apple com bill");
  assert.equal(a.rows[0].is_internal, false);
  assert.ok(!JSON.stringify(a).includes("621.89"), "balance must not be stored");
  assert.ok(
    !JSON.stringify(s.rows).includes("621.89"),
    "balance must not be stored in the raw message either",
  );
  assert.ok(s.rows[0].body.includes("APPLE COM BILL"));
});

Deno.test("ingest: a one-time code only the parser recognises gets its stored body blanked", async () => {
  const s = await setup();
  await s.call({
    sender: "STC Bank",
    body: "رمز العملية 4821",
    received_at: "2026-10-26T14:19:05Z",
  });
  assert.equal(s.saved[0].ignoreReason, "otp");
  assert.equal(s.saved[0].redactBody, true);
});

Deno.test("ingest: a transfer to an own account is internal and excluded from spend", async () => {
  const s = await setup();
  await s.call({
    sender: "alinma",
    body: "حوالة صادرة محلية\nمبلغ SAR 500\nلـ PERSON\nلحساب *5911\nفي 21:39 09-10-26",
    received_at: "2026-10-09T18:39:05Z",
  });
  const r = s.saved[0].rows[0];
  assert.equal(r.type, "transfer_out");
  assert.equal(r.is_internal, true);
  assert.equal(r.excluded_from_spend, true);
});

Deno.test("ingest: a transfer fee becomes its own fee transaction", async () => {
  const s = await setup();
  await s.call({
    sender: "alinma",
    body:
      "حوالة صادرة محلية\nمبلغ SAR 1,800\nرسوم: SAR 0.58\nلـ PERSON H\nلحساب *7892\nفي 23:58 30-10-26",
    received_at: "2026-10-30T20:58:05Z",
  });
  const rows = s.saved[0].rows;
  assert.deepEqual(rows.map((r) => [r.type, r.amount_halalas, r.is_internal]), [[
    "transfer_out",
    180000,
    false,
  ], ["fee", 58, false]]);
});

Deno.test("ingest: a top-up purchase is internal on both banks and never counts as spend", async () => {
  const s = await setup();
  await s.call({
    sender: "D360 Bank",
    body:
      "Local Online Purchase\nAmount: SAR 1.00\nCard: *7705 - mada (Apple Pay)\nAt: barq\nAccount number: *5911\nOn: 2026-10-31 13:56",
    received_at: "2026-10-31T10:57:06Z",
  });
  assert.equal(s.saved[0].rows[0].type, "wallet_topup");
  assert.equal(s.saved[0].rows[0].excluded_from_spend, true);
});

Deno.test("ingest: declined and notice SMS are marked ignored with a reason, no transaction", async () => {
  const s = await setup();
  await s.call({
    sender: "D360 Bank",
    body:
      "Transaction Declined: Insufficient balance\nAmount: SAR 374.00\nCard: *8920 - Visa\nAt: Gopray\nOn: 2026-08-22 08:26:44",
    received_at: "2026-08-22T05:26:50Z",
  });
  assert.deepEqual([s.saved[0].status, s.saved[0].ignoreReason, s.saved[0].rows.length], [
    "ignored",
    "declined",
    0,
  ]);
});

Deno.test("ingest: an unknown format stays needs_review and nothing is saved", async () => {
  const s = await setup();
  const res = await s.call({
    sender: "snb-alahli",
    body: "دائن مدخرات شركات سابقة\nمبلغ 944.96SAR\nحساب*0103\nفي 30/08/26 12:50",
    received_at: "2026-08-30T09:50:05Z",
  });
  assert.equal(res.status, 200);
  assert.equal(s.saved.length, 0);
  assert.equal(s.rows[0].parse_status, "needs_review");
});

Deno.test("ingest: if saving the parse fails the SMS is stored and the call fails so the app retries", async () => {
  const s = await setup({ failSave: true });
  const res = await s.call(SMS).catch(() => null);
  // handleIngest rethrows; the real server turns that into a 500
  assert.equal(res, null);
  assert.equal(s.rows.length, 1);
  assert.equal(s.rows[0].parse_status, "needs_review");
  assert.equal(s.saved.length, 0);
});

Deno.test("ingest: the retry after a failed save parses the stored message once and never twice", async () => {
  const opts = { failSave: true };
  const s = await setup(opts);
  await s.call(SMS).catch(() => null);
  opts.failSave = false;
  const retry = await s.call(SMS);
  assert.equal(retry.status, 200);
  assert.equal(s.rows.length, 1, "no second raw row");
  assert.equal(s.saved.length, 1, "parsed on the retry");
  await s.call(SMS);
  assert.equal(s.saved.length, 1, "a third delivery is a plain duplicate");
});

Deno.test("ingest: a message that fails twice is answered with success the second time (no endless retry)", async () => {
  const s = await setup({ failSave: true });
  const first = await s.call(SMS).catch(() => null);
  assert.equal(first, null);
  const second = await s.call(SMS);
  assert.equal(second.status, 200);
  assert.equal(s.rows.length, 1);
  assert.equal(s.rows[0].parse_status, "needs_review");
});

Deno.test("ingest: a duplicate delivery is not parsed twice", async () => {
  const s = await setup();
  await s.call(SMS);
  await s.call(SMS);
  assert.equal(s.saved.length, 1);
});

Deno.test("ingest: transactions are categorised from the rules, and the fee row goes to Fees", async () => {
  const s = await setup();
  await s.call(SMS);
  assert.equal(s.saved[0].rows[0].category_id, "c-subs");
  assert.equal(s.saved[0].rows[0].rule_id, "r1");
  assert.equal(s.saved[0].rows[0].category_source, "rule");
  const t = await setup();
  await t.call({
    sender: "alinma",
    body:
      "حوالة صادرة محلية\nمبلغ SAR 1,800\nرسوم: SAR 0.58\nلـ PERSON H\nلحساب *7892\nفي 23:58 30-10-26",
    received_at: "2026-10-30T20:58:05Z",
  });
  assert.deepEqual(t.saved[0].rows.map((r) => [r.type, r.category_id]), [[
    "transfer_out",
    "c-horse",
  ], ["fee", "c-fees"]]);
});

Deno.test("ingest: a merchant no rule knows is saved uncategorised", async () => {
  const s = await setup();
  await s.call({
    ...SMS,
    body: SMS.body.replace("APPLE COM BILL", "SOME NEW SHOP"),
    received_at: "2026-10-26T14:19:05Z",
  });
  assert.equal(s.saved[0].rows[0].category_id, undefined);
});

Deno.test("ingest: if the rules cannot be loaded the transaction is still saved, uncategorised", async () => {
  const s = await setup({ failRules: true });
  const res = await s.call(SMS);
  assert.equal(res.status, 200);
  assert.equal(s.saved.length, 1);
  assert.equal(s.saved[0].status, "parsed");
  assert.equal(s.saved[0].rows[0].category_id, undefined);
});

const BILL_BODY = Deno.readTextFileSync(
  new URL("../../tests/fixtures/stc900/internet_bill.json", import.meta.url),
);
const NET_OB: Ob = {
  id: "ob-net",
  name: "Internet",
  kind: "bill",
  expectedHalalas: 17250,
  dueRule: { day: 2, next_month: true },
  match: { line: "7356", merchant: ["stc"] },
};
const HORSE_OB: Ob = {
  id: "ob-horse",
  name: "Horse and foal",
  kind: "fixed",
  expectedHalalas: 180000,
  dueRule: { after: "salary", fallback_day: 28, grace: 3 },
  match: { types: ["transfer_out"], counterparty_last4: "7892", tolerance_pct: 0 },
};
const HORSE_INST: Inst = {
  id: "inst-horse",
  obligationId: "ob-horse",
  periodStart: "2026-10-01",
  dueDate: "2026-10-28",
  expectedHalalas: 180000,
  actualHalalas: null,
  status: "pending",
  transactionId: null,
  matchState: "none",
  createdAt: "2026-10-01T00:00:00Z",
};
const HORSE_SMS = {
  sender: "alinma",
  body:
    "حوالة صادرة محلية\nمبلغ SAR 1,800\nرسوم: SAR 0.58\nلـ PERSON H\nلحساب *7892\nفي 23:58 30-10-26",
  received_at: "2026-10-30T20:58:05Z",
};

Deno.test("ingest: an STC bill SMS creates that month's internet instance", async () => {
  const s = await setup({ obs: [NET_OB] });
  const f = JSON.parse(BILL_BODY);
  const res = await s.call({ sender: f.sender, body: f.body, received_at: f.receivedAt });
  assert.equal(res.status, 200);
  assert.equal(s.saved[0].status, "parsed");
  assert.equal(s.noticeInstances.length, 1);
  assert.deepEqual(s.noticeInstances[0].inst, {
    periodStart: "2026-10-01",
    dueDate: "2026-11-02",
    expectedHalalas: 17250,
  });
});

Deno.test("ingest: a bill for a line nobody tracks is parsed but creates no instance", async () => {
  const s = await setup({ obs: [] });
  const f = JSON.parse(BILL_BODY);
  await s.call({ sender: f.sender, body: f.body, received_at: f.receivedAt });
  assert.equal(s.saved[0].status, "parsed");
  assert.equal(s.noticeInstances.length, 0);
});

Deno.test("ingest: the 1,800 transfer to 7892 pays the horse instance, the fee row does not", async () => {
  const s = await setup({ obs: [HORSE_OB], open: [HORSE_INST] });
  await s.call(HORSE_SMS);
  assert.equal(s.matches.length, 1);
  assert.equal(s.matches[0].match.instanceId, "inst-horse");
  assert.equal(s.matches[0].match.status, "paid");
  assert.equal(s.matches[0].match.transactionId, "tx1-0");
});

Deno.test("ingest: a salary moves an 'after salary' due date to the day it landed", async () => {
  const s = await setup({ obs: [HORSE_OB], open: [HORSE_INST] });
  await s.call({
    sender: "alinma",
    body: "تم إيداع الراتب\nمبلغ SAR 14,100.00\nلحساب *6000\nفي 05:10 29-10-26",
    received_at: "2026-10-29T02:10:05Z",
  });
  assert.deepEqual(s.dueDates, [["inst-horse", "2026-10-29"]]);
});

Deno.test("ingest: if tracking obligations fails the transaction is still saved and the call succeeds", async () => {
  const s = await setup({ failObligations: true });
  const res = await s.call(SMS);
  assert.equal(res.status, 200);
  assert.equal(s.saved.length, 1);
  assert.equal(s.saved[0].rows.length, 1);
});

Deno.test("ingest: instances are refreshed before a payment is matched, so an early payment finds its instance", async () => {
  const s = await setup({ obs: [HORSE_OB], open: [HORSE_INST] });
  await s.call(HORSE_SMS);
  assert.equal(s.refreshed(), 1);
});

Deno.test("ingest: a bill SMS keeps only its facts in the stored body", async () => {
  const s = await setup({ obs: [NET_OB] });
  const f = JSON.parse(BILL_BODY);
  await s.call({ sender: f.sender, body: f.body, received_at: f.receivedAt });
  assert.equal(s.saved[0].replaceBody, "[bill notice] STC line ending 7356, total 172.50 SAR");
});

const BARQ_LOCAL =
  "Debit Transfer local\nAmount: 50.00 SAR\nFees: 0.00 SAR\nTo: PERSON A\nBank: INMA BANK \na/c: **6000\n2026-11-04 06:40";
const ALINMA_IN = "حوالة واردة محلية\nمبلغ 50 SAR\nمن PERSON A\nحساب *6000\nفي 06:41 26-11-04";

Deno.test("ingest: a barq local transfer to an own account is internal, not spending", async () => {
  const s = await setup();
  const res = await s.call(
    { sender: "barq app", body: BARQ_LOCAL, received_at: "2026-11-04T03:40:58Z" },
    { "x-ingest-token": s.token },
  );
  assert.equal(res.status, 200);
  const row = s.saved[0].rows[0];
  assert.equal(row.type, "transfer_out");
  assert.equal(row.is_internal, true);
  assert.equal(row.excluded_from_spend, true);
  assert.equal(row.counterparty_last4, "6000");
});

Deno.test("ingest: the other bank's incoming message of the same move is internal too", async () => {
  const s = await setup({
    counterparts: [cand({ id: "out1", isInternal: true, counterpartyLast4: "6000" })],
  });
  await s.call(
    { sender: "alinma", body: ALINMA_IN, received_at: "2026-11-04T03:41:32Z" },
    { "x-ingest-token": s.token },
  );
  const row = s.saved[0].rows[0];
  assert.equal(row.type, "transfer_in");
  assert.equal(row.is_internal, true);
  assert.equal(row.excluded_from_spend, true);
  assert.equal(s.transferLookups[0].type, "transfer_out");
  assert.equal(s.transferLookups[0].amountHalalas, 5000);
});

Deno.test("ingest: an incoming transfer with no matching own transfer stays real income", async () => {
  const s = await setup({ counterparts: [] });
  await s.call(
    { sender: "alinma", body: ALINMA_IN, received_at: "2026-11-04T03:41:32Z" },
    { "x-ingest-token": s.token },
  );
  assert.equal(s.saved[0].rows[0].is_internal, false);
});

Deno.test("ingest: an own-account transfer out finds the incoming row that arrived first and marks it", async () => {
  const s = await setup({
    counterparts: [cand({ id: "in1", type: "transfer_in", bank: "alinma", accountLast4: "6000" })],
  });
  await s.call(
    { sender: "barq app", body: BARQ_LOCAL, received_at: "2026-11-04T03:40:58Z" },
    { "x-ingest-token": s.token },
  );
  assert.deepEqual(s.marked, [{ ids: ["in1"], cat: "c-transfers" }]);
  assert.equal(s.transferLookups[0].type, "transfer_in");
});

Deno.test("ingest: an outgoing transfer is internal when the incoming one of the same move already is", async () => {
  const s = await setup({
    counterparts: [cand({ id: "in1", isInternal: true, type: "transfer_in", bank: "alinma" })],
  });
  await s.call(
    {
      sender: "barq app",
      body: BARQ_LOCAL.replace("**6000", "**9999"),
      received_at: "2026-11-04T03:40:58Z",
    },
    { "x-ingest-token": s.token },
  );
  const row = s.saved[0].rows[0];
  assert.equal(row.type, "transfer_out");
  assert.equal(row.is_internal, true);
  assert.equal(row.excluded_from_spend, true);
});

Deno.test("ingest: an out and an in of the same amount a minute apart are one internal move: both left out, accounts saved", async () => {
  // Al Rajhi sends 50.00 from 1111 to 2222; SNB's message about the same move arrives second
  const s = await setup({
    counterparts: [
      cand({
        id: "out1",
        bank: "alrajhi",
        accountLast4: "1111",
        counterpartyLast4: "2222",
      }),
    ],
  });
  await s.call(
    {
      sender: "SNB-AlAhli",
      body: "حوالة واردة\nمبلغ:SAR 50\nمرسل:PERSON A\nمن:*1111\nإلى:*2222\nفي:06:41 04/11/26",
      received_at: "2026-11-04T03:41:32Z",
    },
    { "x-ingest-token": s.token },
  );
  const row = s.saved[0].rows[0];
  assert.equal(row.type, "transfer_in");
  assert.equal(row.is_internal, true);
  assert.equal(row.excluded_from_spend, true);
  assert.deepEqual(s.marked, [{ ids: ["out1"], cat: "c-transfers" }]);
  assert.deepEqual(s.learned, [[
    { bank: "alrajhi", last4: "1111" },
    { bank: "snb", last4: "2222" },
  ]]);
});

Deno.test("ingest: a pair whose digits point at different accounts is two separate payments, not one internal move", async () => {
  // the out went to 9999, but the in landed on 6000 from an unrelated account
  const s = await setup({
    counterparts: [cand({ id: "out1", bank: "barq", counterpartyLast4: "9999" })],
  });
  await s.call(
    { sender: "alinma", body: ALINMA_IN, received_at: "2026-11-04T03:41:32Z" },
    { "x-ingest-token": s.token },
  );
  assert.equal(s.saved[0].rows[0].is_internal, false, "stays income");
  assert.deepEqual(s.marked, []);
  assert.deepEqual(s.learned, []);
});

Deno.test("ingest: a partner that arrived at the same moment is found by the second look and both are flipped", async () => {
  const s = await setup({
    counterparts: [],
    counterpartsLater: [
      cand({ id: "out1", bank: "alrajhi", accountLast4: "1111", counterpartyLast4: "2222" }),
    ],
  });
  await s.call(
    {
      sender: "SNB-AlAhli",
      body: "حوالة واردة\nمبلغ:SAR 50\nمرسل:PERSON A\nمن:*1111\nإلى:*2222\nفي:06:41 04/11/26",
      received_at: "2026-11-04T03:41:32Z",
    },
    { "x-ingest-token": s.token },
  );
  assert.equal(s.transferLookups.length, 2);
  assert.equal(s.marked.length, 1);
  assert.ok(s.marked[0].ids.includes("out1"));
  assert.deepEqual(s.learned, [[
    { bank: "alrajhi", last4: "1111" },
    { bank: "snb", last4: "2222" },
  ]]);
});

Deno.test("ingest: a transfer with no matching message stays an expense or income and learns nothing", async () => {
  const s = await setup({ counterparts: [] });
  await s.call(
    { sender: "alinma", body: ALINMA_IN, received_at: "2026-11-04T03:41:32Z" },
    { "x-ingest-token": s.token },
  );
  assert.equal(s.saved[0].rows[0].is_internal, false);
  assert.deepEqual(s.learned, []);
});

Deno.test("ingest: a failed counterpart lookup never costs the transaction", async () => {
  const s = await setup({ failPairLookup: true });
  const res = await s.call(
    { sender: "alinma", body: ALINMA_IN, received_at: "2026-11-04T03:41:32Z" },
    { "x-ingest-token": s.token },
  );
  assert.equal(res.status, 200);
  assert.equal(s.saved.length, 1);
  assert.equal(s.saved[0].rows[0].is_internal, false);
});

Deno.test("ingest: paying the owner's credit card is internal, never spending", async () => {
  const s = await setup();
  const res = await s.call(
    {
      sender: "alinma",
      body:
        "تم سداد البطاقة الائتمانية **8119\nمبلغ 14,834.50 SAR\nحساب **6000\nفي 2026-11-04 06:42\nحد الصرف المتبقي 14,886 SAR",
      received_at: "2026-11-04T03:42:10Z",
    },
    { "x-ingest-token": s.token },
  );
  assert.equal(res.status, 200);
  const row = s.saved[0].rows[0];
  assert.equal(row.type, "card_payment");
  assert.equal(row.amount_halalas, 1483450);
  assert.equal(row.is_internal, true);
  assert.equal(row.excluded_from_spend, true);
  assert.ok(!s.rows[0].body.includes("14,886"), "the remaining limit line is not stored");
});

Deno.test("ingest: a bill SMS whose instance cannot be saved is retried, not lost", async () => {
  const opts = { obs: [NET_OB], failNotice: true };
  const s = await setup(opts);
  const f = JSON.parse(BILL_BODY);
  const first = await s.call({ sender: f.sender, body: f.body, received_at: f.receivedAt }).catch(
    () => null,
  );
  assert.equal(first, null, "the call fails so the app sends it again");
  assert.equal(s.rows[0].parse_status, "needs_review");
  assert.equal(s.saved.length, 0, "not marked parsed");
  opts.failNotice = false;
  const retry = await s.call({ sender: f.sender, body: f.body, received_at: f.receivedAt });
  assert.equal(retry.status, 200);
  assert.equal(s.noticeInstances.length, 1, "the instance is created on the retry");
  assert.equal(s.saved.length, 1);
  assert.equal(s.saved[0].status, "parsed");
});

// ---------------------------------------------------------------------------------------------------------------
// AI fallback for messages no regex parser understands

const UNKNOWN_BANK = {
  sender: "NewBank",
  body: "Purchase SAR 47.50 at MCDONALDS RIYADH card 8920 on 2026-10-26 17:19",
  received_at: "2026-10-26T14:19:05Z",
};
const AI_TXN: AiParseOutcome = {
  ok: true,
  costHalalas: 1,
  result: {
    kind: "transaction",
    parser: "ai/v1",
    confidence: 0.93,
    txn: {
      type: "purchase",
      direction: "out",
      amountHalalas: 4750,
      merchant: "MCDONALDS RIYADH",
      cardLast4: "8920",
      occurredAt: "2026-10-26T14:19:00.000Z",
    },
  },
};

Deno.test("ingest AI: an unknown bank is read by AI, saved as ai_parsed with its confidence, and categorised", async () => {
  const calls: string[][] = [];
  const s = await setup({
    aiParse: (u, sender, body) => {
      calls.push([u, sender, body]);
      return Promise.resolve(AI_TXN);
    },
  });
  const res = await s.call(UNKNOWN_BANK);
  assert.equal(res.status, 200);
  assert.equal(calls.length, 1);
  assert.equal(calls[0][0], "user1");
  assert.equal(s.saved.length, 1);
  const saved = s.saved[0];
  assert.equal(saved.status, "ai_parsed");
  assert.equal(saved.parser, "ai/v1");
  assert.equal(saved.confidence, 0.93);
  assert.equal(saved.rows[0].bank, "other");
  assert.equal(saved.rows[0].amount_halalas, 4750);
  assert.equal(saved.rows[0].type, "purchase");
  assert.equal(saved.rows[0].merchant_norm, "mcdonalds riyadh");
  assert.equal(saved.rows[0].is_internal, false);
});

Deno.test("ingest AI: a credit-card payoff read by AI is internal, not spending", async () => {
  const s = await setup({
    aiParse: () =>
      Promise.resolve({
        ok: true,
        costHalalas: 1,
        result: {
          kind: "transaction",
          parser: "ai/v1",
          confidence: 0.9,
          txn: {
            type: "card_payment",
            direction: "out",
            amountHalalas: 1483450,
            occurredAt: "2026-10-26T14:19:00.000Z",
          },
        },
      }),
  });
  await s.call(UNKNOWN_BANK);
  assert.equal(s.saved[0].rows[0].is_internal, true);
  assert.equal(s.saved[0].rows[0].excluded_from_spend, true);
});

Deno.test("ingest AI: a rejected, failed or unavailable reading leaves the message in Needs review and still answers 200", async () => {
  const cases: IngestDeps["aiParse"][] = [
    () =>
      Promise.resolve({
        ok: true,
        costHalalas: 1,
        result: { kind: "rejected", reason: "amount_not_in_sms" },
      }),
    () => Promise.resolve({ ok: false, reason: "failed" }),
    () => Promise.resolve(null),
    () => Promise.reject(new Error("anthropic down")),
    undefined,
  ];
  for (const aiParse of cases) {
    const s = await setup({ aiParse });
    const res = await s.call(UNKNOWN_BANK);
    assert.equal(res.status, 200);
    assert.equal(s.saved.length, 0);
    assert.equal(s.rows[0].parse_status, "needs_review");
  }
});

Deno.test("ingest AI: marketing or declined messages are ignored, a one-time code is also blanked", async () => {
  for (const reason of ["marketing", "declined", "otp"] as const) {
    const s = await setup({
      aiParse: () =>
        Promise.resolve({
          ok: true,
          costHalalas: 1,
          result: { kind: "ignored", parser: "ai/v1", reason },
        }),
    });
    await s.call({ ...UNKNOWN_BANK, body: "Special offer 20% off this week" });
    assert.equal(s.saved[0].status, "ignored");
    assert.equal(s.saved[0].ignoreReason, reason);
    assert.equal(s.saved[0].redactBody, reason === "otp");
  }
});

Deno.test("ingest AI: formats the regex parsers know never reach the model", async () => {
  let called = 0;
  const s = await setup({
    aiParse: () => {
      called++;
      return Promise.resolve(AI_TXN);
    },
  });
  await s.call(SMS); // a known barq purchase
  assert.equal(called, 0);
  assert.equal(s.saved[0].parser.startsWith("barq"), true);
  assert.equal(s.saved[0].status, "parsed");
});

Deno.test("ingest AI: a bill notice stays in Needs review for now (nothing is saved from it)", async () => {
  const s = await setup({
    aiParse: () =>
      Promise.resolve({
        ok: true,
        costHalalas: 1,
        result: {
          kind: "bill_notice",
          parser: "ai/v1",
          amountHalalas: 69200,
          dueDate: "2026-11-28",
          confidence: 0.9,
        },
      }),
  });
  const res = await s.call({ ...UNKNOWN_BANK, body: "Electricity bill SAR 692.00 due 2026-11-28" });
  assert.equal(res.status, 200);
  assert.equal(s.saved.length, 0);
  assert.equal(s.rows[0].parse_status, "needs_review");
});

Deno.test("ingest AI: after enough confirmed readings from a sender, its readings are saved as parsed (no check needed)", async () => {
  const trusted = await setup({
    aiParse: () => Promise.resolve(AI_TXN),
    aiTrusted: () => Promise.resolve(true),
  });
  await trusted.call(UNKNOWN_BANK);
  assert.equal(trusted.saved[0].status, "parsed");
  assert.equal(trusted.saved[0].parser, "ai/v1");

  const failing = await setup({
    aiParse: () => Promise.resolve(AI_TXN),
    aiTrusted: () => Promise.reject(new Error("db")),
  });
  await failing.call(UNKNOWN_BANK);
  assert.equal(failing.saved[0].status, "ai_parsed"); // a failed lookup never skips the check
});
