import assert from "node:assert/strict";
import { type BudgetDb, createBudget } from "./ai_reserve.ts";

function fakeDb(reply: { data: unknown; error?: unknown }) {
  const calls: { fn: string; args: Record<string, unknown> }[] = [];
  const db: BudgetDb = {
    rpc(fn, args) {
      calls.push({ fn, args });
      return Promise.resolve({
        data: fn === "ai_reserve" ? reply.data : null,
        error: reply.error ?? null,
      });
    },
  };
  return { db, calls };
}
const opts = {
  userId: "u1",
  purpose: "parse" as const,
  userCapHalalas: 300,
  monthStartIso: "2026-10-31T21:00:00.000Z",
};

Deno.test("reserve passes the user cap, the global ceiling and a rounded-up estimate to the database", async () => {
  const { db, calls } = fakeDb({ data: "r1" });
  const ok = await createBudget(db, { ...opts, globalCapEnv: "900" }).reserve(1.2);
  assert.equal(ok, true);
  assert.equal(calls[0].fn, "ai_reserve");
  assert.equal(calls[0].args.p_estimate, 2);
  assert.equal(calls[0].args.p_user_cap, 300);
  assert.equal(calls[0].args.p_global_cap, 900);
});

Deno.test("reserve is false when the database says the cap would be passed (null id)", async () => {
  const { db } = fakeDb({ data: null });
  assert.equal(await createBudget(db, opts).reserve(2), false);
});

Deno.test("reserve fails loudly when the database errors", async () => {
  const { db } = fakeDb({ data: null, error: { message: "x" } });
  await assert.rejects(() => createBudget(db, opts).reserve(2), {
    message: "usage_reserve_failed",
  });
});

Deno.test("recordUsage settles the reservation once, and a later release does nothing", async () => {
  const { db, calls } = fakeDb({ data: "r1" });
  const b = createBudget(db, opts);
  await b.reserve(2);
  await b.recordUsage({ inputTokens: 100, outputTokens: 20, costHalalas: 1 });
  await b.release();
  assert.deepEqual(calls.map((c) => c.fn), ["ai_reserve", "ai_settle"]);
  assert.equal(calls[1].args.p_id, "r1");
});

Deno.test("release gives the reservation back when the call never billed", async () => {
  const { db, calls } = fakeDb({ data: "r1" });
  const b = createBudget(db, opts);
  await b.reserve(2);
  await b.release();
  await b.release();
  assert.deepEqual(calls.map((c) => c.fn), ["ai_reserve", "ai_release"]);
});

Deno.test("recordUsage without a reservation is an error (a spend must never go unrecorded)", async () => {
  const { db } = fakeDb({ data: "r1" });
  await assert.rejects(
    () => createBudget(db, opts).recordUsage({ inputTokens: 1, outputTokens: 1, costHalalas: 1 }),
    { message: "usage_write_failed" },
  );
});
