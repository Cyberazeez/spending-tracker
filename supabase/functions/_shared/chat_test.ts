import assert from "node:assert/strict";
import type { AiDeps } from "./ai.ts";
import { buildSystem, generateChat, MAX_CHAT_CHARS, sanitizeMessages } from "./chat.ts";
import { type Aggregates, sanitizeAggregates } from "./tips.ts";

const CATS = ["Groceries", "Dining"];
const AGG = sanitizeAggregates({
  month: "2026-11",
  spendHalalas: 500000,
  lastMonthToDateHalalas: 400000,
  savingsRatePct: 40,
  salaryAboveBase: false,
  subscriptionsMonthlyHalalas: 10000,
  categories: [
    { name: "Groceries", spentHalalas: 300000, avg3Halalas: 250000, budgetHalalas: 320000 },
    { name: "Dining", spentHalalas: 90000, avg3Halalas: 100000, budgetHalalas: null },
  ],
}, CATS) as Aggregates;

function deps(
  over: Partial<AiDeps> = {},
  calls = { n: 0, body: "", used: [] as number[] },
): AiDeps {
  return {
    apiKey: "k",
    fetch: ((_u: string, init: RequestInit) => {
      calls.n++;
      calls.body = String(init.body);
      return Promise.resolve(
        new Response(
          JSON.stringify({
            content: [{ text: " Dining is 900.00 SAR, under its average. " }],
            usage: { input_tokens: 300, output_tokens: 60 },
          }),
          { status: 200 },
        ),
      );
    }) as typeof fetch,
    aiEnabled: true,
    reserve: () => Promise.resolve(true),
    release: () => Promise.resolve(),
    recordUsage: (u) => {
      calls.used.push(u.costHalalas);
      return Promise.resolve();
    },
    ...over,
  };
}

Deno.test("chat messages: a normal conversation passes and is trimmed", () => {
  const m = sanitizeMessages([
    { role: "user", content: "  Why is dining high? " },
    { role: "assistant", content: "Dining is 900.00 SAR." },
    { role: "user", content: "and groceries 1250?" },
  ])!;
  assert.equal(m.length, 3);
  assert.equal(m[0].content, "Why is dining high?");
  assert.ok(m[2].content.includes("1250"));
  assert.ok(m[1].content.includes("900.00"));
});

Deno.test("chat messages: shape rules reject bad input", () => {
  const u = (c: string) => ({ role: "user", content: c });
  const a = (c: string) => ({ role: "assistant", content: c });
  assert.equal(sanitizeMessages(null), null);
  assert.equal(sanitizeMessages([]), null);
  assert.equal(sanitizeMessages([a("hi")]), null, "must start with the person");
  assert.equal(sanitizeMessages([u("hi"), a("yo")]), null, "must end with the person");
  assert.equal(sanitizeMessages([{ role: "system", content: "x" }]), null);
  assert.equal(sanitizeMessages([{ role: "user", content: 5 }]), null);
  assert.equal(sanitizeMessages([u("   ")]), null);
  assert.equal(
    sanitizeMessages(Array.from({ length: 13 }, (_, i) => i % 2 === 0 ? u("x") : a("y"))),
    null,
  );
});

Deno.test("chat messages: emails, urls, long digit runs and control characters are removed, length is capped", () => {
  const m = sanitizeMessages([{
    role: "user",
    content: "my iban SA0380000000608010167519 card 4111 1111 1111 1111 mail a@b.co " +
      "see https://x.y\nline " + "z".repeat(1000),
  }])!;
  const c = m[0].content;
  assert.ok(!/@|https?:|\d{7,}|\n/.test(c), c);
  assert.ok(!c.includes("4111"));
  assert.ok(c.length <= MAX_CHAT_CHARS);
});

Deno.test("chat: the request carries the system prompt with the numbers and the conversation only", async () => {
  const calls = { n: 0, body: "", used: [] as number[] };
  const msgs = sanitizeMessages([{ role: "user", content: "Where can I cut?" }])!;
  const r = await generateChat(deps({}, calls), AGG, msgs, "en");
  assert.deepEqual(r, {
    ok: true,
    reply: "Dining is 900.00 SAR, under its average.",
    costHalalas: 1,
  });
  const body = JSON.parse(calls.body);
  assert.equal(body.system, buildSystem(AGG, "en"));
  assert.deepEqual(body.messages, msgs);
  assert.ok(body.system.includes("Groceries") && body.system.includes("3000.00"));
  assert.ok(!/@|https?:|\d{7,}|IBAN/i.test(body.system));
  assert.equal(calls.used.length, 1);
});

Deno.test("chat: disabled, no key and cap reached make no network call", async () => {
  const msgs = sanitizeMessages([{ role: "user", content: "hi" }])!;
  for (
    const [over, reason] of [
      [{ aiEnabled: false }, "disabled"],
      [{ apiKey: undefined }, "no_key"],
      [{ reserve: () => Promise.resolve(false) }, "cap_reached"],
    ] as const
  ) {
    const calls = { n: 0, body: "", used: [] as number[] };
    assert.deepEqual(await generateChat(deps(over, calls), AGG, msgs, "en"), {
      ok: false,
      reason,
    });
    assert.equal(calls.n, 0);
  }
});

Deno.test("chat: API errors and empty answers fail closed", async () => {
  const msgs = sanitizeMessages([{ role: "user", content: "hi" }])!;
  const bad = await generateChat(
    deps({ fetch: (() => Promise.resolve(new Response("no", { status: 500 }))) as typeof fetch }),
    AGG,
    msgs,
    "ar",
  );
  assert.deepEqual(bad, { ok: false, reason: "failed" });
  const empty = await generateChat(
    deps({
      fetch: (() =>
        Promise.resolve(
          new Response(JSON.stringify({ content: [{ text: "  " }] }), { status: 200 }),
        )) as typeof fetch,
    }),
    AGG,
    msgs,
    "en",
  );
  assert.deepEqual(empty, { ok: false, reason: "failed" });
});
