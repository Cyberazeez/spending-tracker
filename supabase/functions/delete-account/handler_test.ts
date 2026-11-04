import assert from "node:assert/strict";
import { DELETE_LIMIT_PER_DAY, type DeleteDeps, handleDeleteAccount } from "./handler.ts";

function setup(over: Partial<DeleteDeps> = {}) {
  const deleted: string[] = [];
  const verified: [string, string][] = [];
  const deps: DeleteDeps = {
    getUser: (a) =>
      Promise.resolve(a === "Bearer good" ? { id: "u1", email: "me@example.test" } : null),
    verifyPassword: (e, p) => {
      verified.push([e, p]);
      return Promise.resolve(p === "right-password");
    },
    requestDeletion: (id) => {
      deleted.push(id);
      return Promise.resolve();
    },
    bumpRateLimit: () => Promise.resolve(1),
    ...over,
  };
  const call = (
    body: unknown,
    headers: Record<string, string> = { authorization: "Bearer good" },
    method = "POST",
  ) =>
    handleDeleteAccount(
      new Request("https://x.test/delete-account", {
        method,
        headers,
        body: method === "POST" ? JSON.stringify(body) : undefined,
      }),
      deps,
    );
  return { call, deleted, verified };
}

Deno.test("the right password marks the caller's own account for deletion and nothing else", async () => {
  const { call, deleted, verified } = setup();
  const res = await call({ password: "right-password" });
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { ok: true, grace_days: 30 });
  assert.deepEqual(deleted, ["u1"]);
  assert.deepEqual(verified, [["me@example.test", "right-password"]]);
});

Deno.test("a wrong password deletes nothing", async () => {
  const { call, deleted } = setup();
  const res = await call({ password: "nope" });
  assert.equal(res.status, 403);
  assert.deepEqual(await res.json(), { error: "wrong_password" });
  assert.deepEqual(deleted, []);
});

Deno.test("no or bad token, wrong method, missing password: nothing is deleted", async () => {
  const { call, deleted } = setup();
  assert.equal((await call({ password: "right-password" }, {})).status, 401);
  assert.equal(
    (await call({ password: "right-password" }, { authorization: "Bearer bad" })).status,
    401,
  );
  assert.equal((await call(undefined, { authorization: "Bearer good" }, "GET")).status, 405);
  assert.equal((await call({})).status, 400);
  assert.equal((await call({ password: "" })).status, 400);
  assert.equal((await call({ password: 123 })).status, 400);
  assert.deepEqual(deleted, []);
});

Deno.test("the account to delete comes from the token, never from the body", async () => {
  const { call, deleted } = setup();
  await call({ password: "right-password", user_id: "someone-else", userId: "x" });
  assert.deepEqual(deleted, ["u1"]);
});

Deno.test("password guessing is rate limited before the password is checked", async () => {
  const { call, deleted, verified } = setup({
    bumpRateLimit: () => Promise.resolve(DELETE_LIMIT_PER_DAY + 1),
  });
  const res = await call({ password: "right-password" });
  assert.equal(res.status, 429);
  assert.deepEqual(deleted, []);
  assert.deepEqual(verified, []);
});

Deno.test("the response carries nothing but ok and the grace period", async () => {
  const { call } = setup();
  const text = await (await call({ password: "right-password" })).text();
  assert.equal(text, '{"ok":true,"grace_days":30}');
});
