import assert from "node:assert/strict";
import { DEFAULT_GLOBAL_CAP_HALALAS, effectiveSpent, globalCapFromEnv } from "./ai_budget.ts";

Deno.test("a user is measured by their own spend, not everybody's", () => {
  assert.equal(effectiveSpent(100, 2000), 100);
  assert.equal(effectiveSpent(0, 5699), 0);
});

Deno.test("once everybody together reaches the ceiling every user is over their cap", () => {
  assert.equal(effectiveSpent(0, 5700), Number.MAX_SAFE_INTEGER);
  assert.ok(effectiveSpent(1, 9999) >= 1900);
});

Deno.test("the ceiling comes from a secret when set, otherwise the default", () => {
  assert.equal(globalCapFromEnv(undefined), DEFAULT_GLOBAL_CAP_HALALAS);
  assert.equal(globalCapFromEnv("abc"), DEFAULT_GLOBAL_CAP_HALALAS);
  assert.equal(globalCapFromEnv("-5"), DEFAULT_GLOBAL_CAP_HALALAS);
  assert.equal(globalCapFromEnv("3800"), 3800);
});
