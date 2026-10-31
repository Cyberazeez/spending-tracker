import assert from "node:assert/strict";
import { type AiDeps, categorizeMerchants, costHalalas, maskMerchant } from "./ai.ts";
import { runBatch } from "../categorize-batch/handler.ts";

const CATS = ["Dining", "Groceries", "Other"];
function deps(over: Partial<AiDeps> & { reply?: unknown; status?: number } = {}) {
  const calls: { url: string; init: RequestInit }[] = [];
  const usage: { inputTokens: number; outputTokens: number; costHalalas: number }[] = [];
  const d: AiDeps = {
    apiKey: "sk-test",
    aiEnabled: true,
    capHalalas: 1900,
    spentHalalas: () => Promise.resolve(0),
    recordUsage: (u) => {
      usage.push(u);
      return Promise.resolve();
    },
    fetch: ((url: string, init: RequestInit) => {
      calls.push({ url, init });
      return Promise.resolve(
        new Response(
          JSON.stringify(
            over.reply ??
              {
                content: [{ type: "text", text: '{"hungerstation llc":"Dining"}' }],
                usage: { input_tokens: 400, output_tokens: 20 },
              },
          ),
          {
            status: over.status ?? 200,
          },
        ),
      );
    }) as typeof fetch,
    ...over,
  };
  return { d, calls, usage };
}

Deno.test("masking removes anything that looks like a number, address or link", () => {
  assert.equal(maskMerchant("HUNGERSTATION LLC 1234567890"), "hungerstation llc");
  assert.equal(maskMerchant("PAY TO SA0380000000608010167519"), "pay to");
  assert.equal(maskMerchant("shop@example.com Bolt"), "bolt");
  assert.equal(maskMerchant("https://pay.example.com/x Noon"), "noon");
  assert.equal(maskMerchant("Store 52"), "store 52");
  assert.ok(maskMerchant("x".repeat(500)).length <= 60);
});

Deno.test("cost rounds up and is never zero, so the cap errs on the safe side", () => {
  assert.equal(costHalalas(0, 0), 1);
  assert.equal(costHalalas(400, 20), 1);
  assert.equal(costHalalas(1_000_000, 0), 38); // $0.10 -> 37.5 halalas -> 38
  assert.equal(costHalalas(0, 1_000_000), 188); // $0.50 -> 187.5 -> 188
});

Deno.test("disabled and keyless: no network call at all", async () => {
  const off = deps({ aiEnabled: false });
  assert.deepEqual(await categorizeMerchants(off.d, ["x"], CATS), {
    ok: false,
    reason: "disabled",
  });
  assert.equal(off.calls.length, 0);
  const nokey = deps({ apiKey: undefined });
  assert.deepEqual(await categorizeMerchants(nokey.d, ["x"], CATS), {
    ok: false,
    reason: "no_key",
  });
  assert.equal(nokey.calls.length, 0);
});

Deno.test("at or over the monthly cap: no network call", async () => {
  const x = deps({ spentHalalas: () => Promise.resolve(1900) });
  assert.deepEqual(await categorizeMerchants(x.d, ["x"], CATS), {
    ok: false,
    reason: "cap_reached",
  });
  assert.equal(x.calls.length, 0);
});

Deno.test("the request contains only masked merchants and category names, nothing else", async () => {
  const x = deps();
  const r = await categorizeMerchants(x.d, ["HUNGERSTATION LLC 99887766", "Noon"], CATS);
  assert.ok(r.ok);
  const body = String(x.calls[0].init.body);
  assert.ok(body.includes("hungerstation llc"));
  assert.ok(!body.includes("99887766"));
  assert.equal(x.calls[0].url, "https://api.anthropic.com/v1/messages");
  assert.equal((x.calls[0].init.headers as Record<string, string>)["x-api-key"], "sk-test");
});

Deno.test("usage is recorded with the cost; answers outside the category list are dropped", async () => {
  const x = deps({
    reply: {
      content: [{
        type: "text",
        text: 'Here you go: {"hungerstation llc":"Dining","noon":"Spaceships"}',
      }],
      usage: { input_tokens: 400, output_tokens: 20 },
    },
  });
  const r = await categorizeMerchants(x.d, ["HUNGERSTATION LLC", "Noon"], CATS);
  assert.deepEqual(r.ok && r.categories, { "hungerstation llc": "Dining" });
  assert.deepEqual(x.usage, [{ inputTokens: 400, outputTokens: 20, costHalalas: 1 }]);
});

Deno.test("API errors, bad JSON and thrown errors all fail closed", async () => {
  assert.deepEqual(await categorizeMerchants(deps({ status: 500 }).d, ["x"], CATS), {
    ok: false,
    reason: "failed",
  });
  const junk = deps({ reply: { content: [{ type: "text", text: "no json" }], usage: {} } });
  assert.deepEqual(await categorizeMerchants(junk.d, ["x"], CATS), { ok: false, reason: "failed" });
  const boom = deps({ fetch: (() => Promise.reject(new Error("network"))) as typeof fetch });
  assert.deepEqual(await categorizeMerchants(boom.d, ["x"], CATS), { ok: false, reason: "failed" });
});

Deno.test("batch: guesses become rules for the right category and report how many transactions changed", async () => {
  const x = deps();
  const saved: { merchantNorm: string; categoryId: string }[] = [];
  const r = await runBatch({
    ai: x.d,
    categoryIds: {
      Dining: "c-d",
      Groceries: "c-g",
      Other: "c-o",
      Income: "c-i",
      Transfers: "c-t",
      Fees: "c-f",
    },
    uncategorizedMerchants: () => Promise.resolve(["hungerstation llc", "mystery 12345"]),
    saveGuesses: (g) => {
      saved.push(...g);
      return Promise.resolve(3);
    },
  });
  assert.deepEqual(r, { ok: true, guessed: 1, updated: 3, costHalalas: 1 });
  assert.deepEqual(saved, [{ merchantNorm: "hungerstation llc", categoryId: "c-d" }]);
  assert.ok(!String(x.calls[0].init.body).includes("12345"));
});

Deno.test("batch: the AI is never asked about Income, Transfers or Fees", async () => {
  const x = deps();
  await runBatch({
    ai: x.d,
    categoryIds: { Dining: "c-d", Income: "c-i", Transfers: "c-t", Fees: "c-f" },
    uncategorizedMerchants: () => Promise.resolve(["hungerstation llc"]),
    saveGuesses: () => Promise.resolve(0),
  });
  const body = String(x.calls[0].init.body);
  assert.ok(body.includes("Dining") && !body.includes("Income") && !body.includes("Transfers"));
});

Deno.test("batch: when the switch is off nothing is sent and nothing changes", async () => {
  const x = deps({ aiEnabled: false });
  let saved = 0;
  const r = await runBatch({
    ai: x.d,
    categoryIds: { Dining: "c-d" },
    uncategorizedMerchants: () => Promise.resolve(["hungerstation llc"]),
    saveGuesses: () => {
      saved++;
      return Promise.resolve(1);
    },
  });
  assert.deepEqual(r, { ok: false, reason: "disabled" });
  assert.equal(x.calls.length, 0);
  assert.equal(saved, 0);
});
