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
  assert.deepEqual(await res.json(), { ok: true, grace_days: 30, apple_revoked: false });
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

Deno.test("the response carries nothing but ok, the grace period and whether Apple was revoked", async () => {
  const { call } = setup();
  const text = await (await call({ password: "right-password" })).text();
  assert.equal(text, '{"ok":true,"grace_days":30,"apple_revoked":false}');
});

Deno.test("the deletion mail goes to the caller, and a mail failure does not undo the deletion", async () => {
  const mailed: string[] = [];
  const ok = setup({
    notifyDeletion: (e) => {
      mailed.push(e);
      return Promise.resolve();
    },
  });
  assert.equal((await ok.call({ password: "right-password" })).status, 200);
  assert.deepEqual(mailed, ["me@example.test"]);

  const broken = setup({ notifyDeletion: () => Promise.reject(new Error("smtp down")) });
  const res = await broken.call({ password: "right-password" });
  assert.equal(res.status, 200);
  assert.deepEqual(broken.deleted, ["u1"]);

  const wrong = setup({
    notifyDeletion: (e) => {
      mailed.push(e);
      return Promise.resolve();
    },
  });
  await wrong.call({ password: "nope" });
  assert.deepEqual(mailed, ["me@example.test"]); // unchanged: no mail without a deletion
});

function appleSetup(over: Partial<DeleteDeps> = {}, providers = ["apple"]) {
  const deleted: string[] = [];
  const revoked: string[] = [];
  const verified: [string, string][] = [];
  const deps: DeleteDeps = {
    getUser: (a) =>
      Promise.resolve(
        a === "Bearer good" ? { id: "u1", email: "relay@privaterelay.test", providers } : null,
      ),
    verifyPassword: () => Promise.resolve(false),
    verifyApple: (t, n) => {
      verified.push([t, n]);
      return Promise.resolve(t === "good-token" ? "u1" : t === "other-users-token" ? "u2" : null);
    },
    revokeApple: (code) => {
      revoked.push(code);
      return Promise.resolve(true);
    },
    requestDeletion: (id) => {
      deleted.push(id);
      return Promise.resolve();
    },
    bumpRateLimit: () => Promise.resolve(1),
    ...over,
  };
  const call = (body: unknown) =>
    handleDeleteAccount(
      new Request("https://x.test/delete-account", {
        method: "POST",
        headers: { authorization: "Bearer good" },
        body: JSON.stringify(body),
      }),
      deps,
    );
  return { call, deleted, revoked, verified };
}

Deno.test("an Apple account deletes with a fresh Apple proof and Apple's token is revoked", async () => {
  const { call, deleted, revoked, verified } = appleSetup();
  const res = await call({
    apple: { id_token: "good-token", nonce: "n1", authorization_code: "code1" },
  });
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { ok: true, grace_days: 30, apple_revoked: true });
  assert.deepEqual(deleted, ["u1"]);
  assert.deepEqual(revoked, ["code1"]);
  assert.deepEqual(verified, [["good-token", "n1"]]);
});

Deno.test("an Apple token for another account or a bad token deletes nothing", async () => {
  const { call, deleted, revoked } = appleSetup();
  assert.equal((await call({ apple: { id_token: "other-users-token", nonce: "n" } })).status, 403);
  assert.equal((await call({ apple: { id_token: "garbage", nonce: "n" } })).status, 403);
  assert.deepEqual(deleted, []);
  assert.deepEqual(revoked, []);
});

Deno.test("a missing Apple code still deletes, and a failing revoke does not undo the deletion", async () => {
  const noCode = appleSetup();
  const r1 = await noCode.call({ apple: { id_token: "good-token", nonce: "n" } });
  assert.equal(r1.status, 200);
  assert.equal((await r1.json()).apple_revoked, false);
  assert.deepEqual(noCode.revoked, []);

  const broken = appleSetup({ revokeApple: () => Promise.reject(new Error("apple down")) });
  const r2 = await broken.call({
    apple: { id_token: "good-token", nonce: "n", authorization_code: "c" },
  });
  assert.equal(r2.status, 200);
  assert.deepEqual(broken.deleted, ["u1"]);
});

Deno.test("the Apple path is only for accounts that signed in with Apple, and the password path only with a password", async () => {
  const emailOnly = appleSetup({}, ["email"]);
  assert.equal(
    (await emailOnly.call({ apple: { id_token: "good-token", nonce: "n" } })).status,
    400,
  );
  assert.deepEqual(emailOnly.deleted, []);

  const appleOnly = appleSetup();
  const res = await appleOnly.call({ password: "anything" });
  assert.equal(res.status, 400);
  assert.deepEqual(await res.json(), { error: "use_apple" });
  assert.deepEqual(appleOnly.deleted, []);
});

Deno.test("malformed Apple proofs are refused", async () => {
  const { call, deleted } = appleSetup();
  for (
    const apple of [null, "x", {}, { id_token: "", nonce: "n" }, { id_token: "t" }, {
      id_token: "x".repeat(5000),
      nonce: "n",
    }]
  ) {
    assert.equal((await call({ apple })).status, 400);
  }
  assert.deepEqual(deleted, []);
});

Deno.test("Apple deletions are rate limited like password ones", async () => {
  const { call, deleted } = appleSetup({
    bumpRateLimit: () => Promise.resolve(DELETE_LIMIT_PER_DAY + 1),
  });
  assert.equal((await call({ apple: { id_token: "good-token", nonce: "n" } })).status, 429);
  assert.deepEqual(deleted, []);
});
