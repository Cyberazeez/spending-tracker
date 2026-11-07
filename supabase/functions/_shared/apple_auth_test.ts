import assert from "node:assert/strict";
import {
  appleClientSecret,
  type AppleConfig,
  appleConfigFromEnv,
  revokeAppleAccess,
} from "./apple_auth.ts";

async function makeConfig() {
  const pair = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, [
    "sign",
    "verify",
  ]);
  const der = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  let s = "";
  for (const b of der) s += String.fromCharCode(b);
  const pem = `-----BEGIN PRIVATE KEY-----\n${btoa(s)}\n-----END PRIVATE KEY-----`;
  const cfg: AppleConfig = {
    teamId: "TEAM123456",
    keyId: "KEY1234567",
    privateKey: pem,
    clientId: "com.example.app",
  };
  return { cfg, pub: pair.publicKey };
}

const dec = (p: string) => JSON.parse(atob(p.replaceAll("-", "+").replaceAll("_", "/")));

Deno.test("the client secret is a valid ES256 JWT with Apple's required claims", async () => {
  const { cfg, pub } = await makeConfig();
  const now = new Date("2026-11-05T12:00:00Z");
  const jwt = await appleClientSecret(cfg, now);
  const [h, c, sig] = jwt.split(".");
  assert.deepEqual(dec(h), { alg: "ES256", kid: "KEY1234567", typ: "JWT" });
  const claims = dec(c);
  assert.equal(claims.iss, "TEAM123456");
  assert.equal(claims.sub, "com.example.app");
  assert.equal(claims.aud, "https://appleid.apple.com");
  assert.equal(claims.iat, Math.floor(now.getTime() / 1000));
  assert.ok(claims.exp - claims.iat <= 300);
  const raw = Uint8Array.from(
    atob(sig.replaceAll("-", "+").replaceAll("_", "/") + "=".repeat((4 - (sig.length % 4)) % 4)),
    (x) => x.charCodeAt(0),
  );
  assert.equal(raw.length, 64);
  const ok = await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    pub,
    raw,
    new TextEncoder().encode(`${h}.${c}`),
  );
  assert.equal(ok, true);
});

Deno.test("a key saved on one line with literal \\n is accepted", async () => {
  const { cfg } = await makeConfig();
  const oneLine = { ...cfg, privateKey: cfg.privateKey.replaceAll("\n", "\\n") };
  assert.equal((await appleClientSecret(oneLine)).split(".").length, 3);
});

Deno.test("revoke exchanges the code for a refresh token, then revokes it", async () => {
  const { cfg } = await makeConfig();
  const calls: { url: string; body: URLSearchParams }[] = [];
  const fakeFetch = ((url: string, init: RequestInit) => {
    calls.push({ url, body: new URLSearchParams(String(init.body)) });
    return Promise.resolve(
      url.endsWith("/token")
        ? new Response(JSON.stringify({ refresh_token: "r-token" }))
        : new Response("", { status: 200 }),
    );
  }) as unknown as typeof fetch;
  assert.equal(await revokeAppleAccess({ fetch: fakeFetch }, cfg, "the-code"), true);
  assert.equal(calls.length, 2);
  assert.equal(calls[0].url, "https://appleid.apple.com/auth/token");
  assert.equal(calls[0].body.get("grant_type"), "authorization_code");
  assert.equal(calls[0].body.get("code"), "the-code");
  assert.equal(calls[0].body.get("client_id"), "com.example.app");
  assert.equal(calls[1].url, "https://appleid.apple.com/auth/revoke");
  assert.equal(calls[1].body.get("token"), "r-token");
  assert.equal(calls[1].body.get("token_type_hint"), "refresh_token");
});

Deno.test("failures return false and log neither the code nor the token", async () => {
  const { cfg } = await makeConfig();
  const logs: unknown[][] = [];
  const orig = console.error;
  console.error = (...a: unknown[]) => logs.push(a);
  try {
    const bad = (() =>
      Promise.resolve(new Response("{}", { status: 400 }))) as unknown as typeof fetch;
    assert.equal(await revokeAppleAccess({ fetch: bad }, cfg, "secret-code"), false);
    const down = (() => Promise.reject(new Error("net"))) as unknown as typeof fetch;
    assert.equal(await revokeAppleAccess({ fetch: down }, cfg, "secret-code"), false);
    assert.equal(
      await revokeAppleAccess({ fetch: bad }, { ...cfg, privateKey: "not a key" }, "secret-code"),
      false,
    );
  } finally {
    console.error = orig;
  }
  assert.ok(!JSON.stringify(logs).includes("secret-code"));
  assert.ok(!JSON.stringify(logs).includes(cfg.privateKey));
});

Deno.test("config needs the team, the key id and the key; the bundle id has a default", () => {
  assert.equal(appleConfigFromEnv(() => undefined), null);
  assert.equal(appleConfigFromEnv((k) => (k === "APPLE_TEAM_ID" ? "T" : undefined)), null);
  const cfg = appleConfigFromEnv((k) =>
    ({ APPLE_TEAM_ID: "T", APPLE_KEY_ID: "K", APPLE_PRIVATE_KEY: "P" } as Record<string, string>)[k]
  );
  assert.deepEqual(cfg, {
    teamId: "T",
    keyId: "K",
    privateKey: "P",
    clientId: "com.cyberazeez.spendingtracker",
  });
});
