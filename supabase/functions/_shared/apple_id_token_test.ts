import assert from "node:assert/strict";
import { APPLE_CERTS_URL, verifyAppleIdToken } from "./apple_id_token.ts";
import { FRESH_SECONDS } from "./id_token.ts";
import { sha256Hex } from "./token.ts";

const NOW = 1_800_000_000;
const BUNDLE = "com.cyberazeez.spendingtracker";
const RAW = "Qx7-raw.nonce_0123456789abcdefABCD";

function b64url(bytes: Uint8Array | string): string {
  const b = typeof bytes === "string" ? new TextEncoder().encode(bytes) : bytes;
  let s = "";
  for (const x of b) s += String.fromCharCode(x);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function keyPair() {
  const pair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  return { privateKey: pair.privateKey, jwk: await crypto.subtle.exportKey("jwk", pair.publicKey) };
}

const apple = await keyPair();
const stranger = await keyPair();

async function sign(
  claims: Record<string, unknown>,
  opts: { kid?: string; alg?: string; key?: CryptoKey } = {},
): Promise<string> {
  const head = b64url(JSON.stringify({ alg: opts.alg ?? "RS256", kid: opts.kid ?? "A1" }));
  const body = b64url(JSON.stringify(claims));
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    opts.key ?? apple.privateKey,
    new TextEncoder().encode(`${head}.${body}`),
  );
  return `${head}.${body}.${b64url(new Uint8Array(sig))}`;
}

const good = {
  iss: "https://appleid.apple.com",
  aud: BUNDLE,
  sub: "001234.abcdef0123456789abcdef0123456789.0042",
  iat: NOW - 20,
  exp: NOW + 600,
  nonce: await sha256Hex(RAW),
  nonce_supported: true,
};

const fetched: string[] = [];
const deps = {
  fetch: ((u: string) => {
    fetched.push(u);
    return Promise.resolve(
      new Response(
        JSON.stringify({ keys: [{ ...apple.jwk, kid: "A1", alg: "RS256", use: "sig" }] }),
      ),
    );
  }) as unknown as typeof fetch,
  now: () => NOW,
};
const verify = (t: string, raw = RAW, ids = [BUNDLE]) => verifyAppleIdToken(deps, t, raw, ids);

Deno.test("a fresh Apple token for our app and this sign-in's nonce gives its Apple account id", async () => {
  assert.equal(await verify(await sign(good)), good.sub);
  assert.equal(fetched.at(-1), APPLE_CERTS_URL);
});

Deno.test("the nonce must be the one the app sent for this sign-in", async () => {
  const t = await sign(good);
  assert.equal(await verify(t, "another-raw-nonce"), null);
  assert.equal(await verify(t, ""), null);
  assert.equal(await verify(t, good.nonce), null); // the hash itself is not the raw nonce
  assert.equal(await verify(await sign({ ...good, nonce: undefined })), null);
  assert.equal(await verify(await sign({ ...good, nonce: RAW })), null); // unhashed nonce in the token
});

Deno.test("a token signed by someone else, or tampered with, is refused", async () => {
  assert.equal(await verify(await sign(good, { key: stranger.privateKey })), null);
  const [h, , s] = (await sign(good)).split(".");
  assert.equal(
    await verify(`${h}.${b64url(JSON.stringify({ ...good, sub: "victim" }))}.${s}`),
    null,
  );
  assert.equal(await verify(await sign(good, { kid: "unknown" })), null);
  assert.equal(await verify(await sign(good, { alg: "HS256" })), null);
  assert.equal(await verify(await sign(good, { alg: "none" })), null);
});

Deno.test("another app's token, another issuer, an expired or old token is refused", async () => {
  for (
    const claims of [
      { ...good, aud: "com.someone.else" },
      { ...good, aud: [BUNDLE] },
      { ...good, iss: "https://accounts.google.com" },
      { ...good, exp: NOW },
      { ...good, iat: NOW - FRESH_SECONDS - 1 },
      { ...good, iat: NOW + 3600 },
      { ...good, sub: "" },
    ]
  ) {
    assert.equal(await verify(await sign(claims)), null, JSON.stringify(claims));
  }
  // a second configured client id of ours is accepted
  assert.equal(
    await verify(await sign({ ...good, aud: "com.example.services" }), RAW, [
      BUNDLE,
      "com.example.services",
    ]),
    good.sub,
  );
});

Deno.test("garbage is refused, and unreachable Apple keys fail closed", async () => {
  for (const t of ["", "a.b", "a.b.c", "x".repeat(50)]) assert.equal(await verify(t), null);
  const down = {
    ...deps,
    fetch: (() => Promise.resolve(new Response("", { status: 500 }))) as unknown as typeof fetch,
  };
  await assert.rejects(() =>
    verifyAppleIdToken(down, "eyJhbGciOiJSUzI1NiIsImtpZCI6IkExIn0.e30.e30", RAW, [BUNDLE])
  );
});
