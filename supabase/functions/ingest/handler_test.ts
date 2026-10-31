import assert from "node:assert/strict";
import {
  handleIngest,
  type IngestDeps,
  RATE_LIMIT_PER_DAY,
  RATE_LIMIT_PER_MINUTE,
  type RawMessageRow,
  type SaveParsedArgs,
} from "./handler.ts";
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

async function setup(opts: { minute?: number; day?: number; failSave?: boolean } = {}) {
  const token = generateToken();
  const hash = await sha256Hex(token);
  const rows: RawMessageRow[] = [];
  const saved: SaveParsedArgs[] = [];
  const seen = new Set<string>();
  let touched = 0;
  const deps: IngestDeps = {
    findToken: (h) => Promise.resolve(h === hash ? { id: "tok1", userId: "user1" } : null),
    bumpRateLimit: (_user, window) =>
      Promise.resolve(window === "minute" ? (opts.minute ?? 1) : (opts.day ?? 1)),
    insertRaw: (row) => {
      if (seen.has(row.dedupe_hash)) return Promise.resolve(null);
      seen.add(row.dedupe_hash);
      rows.push(row);
      return Promise.resolve(`id${rows.length}`);
    },
    touchToken: () => {
      touched++;
      return Promise.resolve();
    },
    loadOwnAccounts: () => Promise.resolve(OWN),
    loadCategorization: () => Promise.resolve({ ids: CATS, rules: RULES }),
    saveParsed: (a) => {
      if (opts.failSave) return Promise.reject(new Error("db down"));
      saved.push(a);
      return Promise.resolve();
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
  return { call, rows, saved, token, touched: () => touched };
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

Deno.test("ingest: if saving the parse fails the SMS is still stored and the call still succeeds", async () => {
  const s = await setup({ failSave: true });
  const res = await s.call(SMS);
  assert.equal(res.status, 200);
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
