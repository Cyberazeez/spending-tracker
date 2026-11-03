import assert from "node:assert/strict";
import { INGEST_TOKEN_KINDS, generateToken, sha256Hex } from "../_shared/token.ts";
import { handleWidgetSummary, WIDGET_LIMIT_PER_DAY, type WidgetDeps } from "./handler.ts";

async function setup(over: Partial<WidgetDeps> = {}) {
  const token = generateToken();
  const hash = await sha256Hex(token);
  const touched: string[] = [];
  const deps: WidgetDeps = {
    findWidgetToken: (h) => Promise.resolve(h === hash ? { id: "t1", userId: "u1" } : null),
    bumpRateLimit: () => Promise.resolve(1),
    summary: () => Promise.resolve({ todayHalalas: 4500, monthHalalas: 58055, budgetHalalas: 800000 }),
    touchToken: (id) => {
      touched.push(id);
      return Promise.resolve();
    },
    ...over,
  };
  const call = (headers: Record<string, string>, method = "GET") =>
    handleWidgetSummary(new Request("https://x.test/widget-summary", { method, headers }), deps);
  return { token, call, touched };
}

Deno.test("a valid widget token gets exactly three numbers", async () => {
  const { token, call, touched } = await setup();
  const res = await call({ "x-widget-token": token });
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { today: 4500, month: 58055, budget: 800000 });
  assert.deepEqual(touched, ["t1"]);
});

Deno.test("no budget is null, not zero", async () => {
  const { token, call } = await setup({
    summary: () => Promise.resolve({ todayHalalas: 0, monthHalalas: 0, budgetHalalas: null }),
  });
  assert.deepEqual(await (await call({ "x-widget-token": token }, "POST")).json(), {
    today: 0,
    month: 0,
    budget: null,
  });
});

Deno.test("missing, malformed or unknown tokens are refused", async () => {
  const { call } = await setup();
  assert.equal((await call({})).status, 401);
  assert.equal((await call({ "x-widget-token": "stk_short" })).status, 401);
  assert.equal((await call({ "x-widget-token": generateToken() })).status, 401);
});

Deno.test("the daily limit returns 429 and reads nothing", async () => {
  let read = false;
  const { token, call } = await setup({
    bumpRateLimit: () => Promise.resolve(WIDGET_LIMIT_PER_DAY + 1),
    summary: () => {
      read = true;
      return Promise.resolve({ todayHalalas: 1, monthHalalas: 1, budgetHalalas: null });
    },
  });
  assert.equal((await call({ "x-widget-token": token })).status, 429);
  assert.equal(read, false);
});

Deno.test("other methods are refused", async () => {
  const { token, call } = await setup();
  assert.equal((await call({ "x-widget-token": token }, "DELETE")).status, 405);
});

Deno.test("ingest never accepts the widget token kind", () => {
  assert.deepEqual([...INGEST_TOKEN_KINDS], ["shortcut", "app"]);
});
