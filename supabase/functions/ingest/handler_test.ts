import assert from "node:assert/strict";
import {
  handleIngest,
  type IngestDeps,
  RATE_LIMIT_PER_MINUTE,
  type RawMessageRow,
} from "./handler.ts";
import { generateToken, sha256Hex } from "../_shared/token.ts";

async function setup(opts: { count?: number } = {}) {
  const token = generateToken();
  const hash = await sha256Hex(token);
  const rows: RawMessageRow[] = [];
  const seen = new Set<string>();
  let touched = 0;
  const deps: IngestDeps = {
    findToken: (h) => Promise.resolve(h === hash ? { id: "tok1", userId: "user1" } : null),
    bumpRateLimit: () => Promise.resolve(opts.count ?? 1),
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
  return { call, rows, token, touched: () => touched };
}

const SMS = {
  sender: "barq app",
  body: "Online Purchase\nVISA card **1224\nAmount 3.99 SAR\nAt APPLE COM BILL\n2026-10-26 17:19",
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
  assert.equal(s.rows[0].body, SMS.body);
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
  const s = await setup({ count: RATE_LIMIT_PER_MINUTE + 1 });
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
