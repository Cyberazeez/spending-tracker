import assert from "node:assert/strict";
import { FRESH_SECONDS, GOOGLE_CERTS_URL, verifyGoogleIdToken } from "./google_id_token.ts";

const NOW = 1_800_000_000;
const WEB = "785025965315-u1hqm7s7dndse7t6u9hcn0av44igael7.apps.googleusercontent.com";

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
  const jwk = await crypto.subtle.exportKey("jwk", pair.publicKey);
  return { privateKey: pair.privateKey, jwk };
}

const google = await keyPair();
const stranger = await keyPair();

async function sign(
  claims: Record<string, unknown>,
  opts: { kid?: string; alg?: string; key?: CryptoKey } = {},
): Promise<string> {
  const head = b64url(JSON.stringify({ alg: opts.alg ?? "RS256", kid: opts.kid ?? "k1" }));
  const body = b64url(JSON.stringify(claims));
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    opts.key ?? google.privateKey,
    new TextEncoder().encode(`${head}.${body}`),
  );
  return `${head}.${body}.${b64url(new Uint8Array(sig))}`;
}

const good = {
  iss: "https://accounts.google.com",
  aud: WEB,
  sub: "1234567890",
  iat: NOW - 30,
  exp: NOW + 3600,
};

const fetched: string[] = [];
const deps = {
  fetch: ((u: string) => {
    fetched.push(u);
    return Promise.resolve(
      new Response(JSON.stringify({ keys: [{ ...google.jwk, kid: "k1", alg: "RS256" }] })),
    );
  }) as unknown as typeof fetch,
  now: () => NOW,
};

Deno.test("a fresh token signed by Google for our client gives its Google account id", async () => {
  assert.equal(await verifyGoogleIdToken(deps, await sign(good)), "1234567890");
  assert.equal(fetched.at(-1), GOOGLE_CERTS_URL);
  // the iOS client and the short issuer form are ours too
  assert.equal(
    await verifyGoogleIdToken(
      deps,
      await sign({
        ...good,
        iss: "accounts.google.com",
        aud: "785025965315-e9dj46u9bk97322l99f3jdnbn7rq07gu.apps.googleusercontent.com",
      }),
    ),
    "1234567890",
  );
});

Deno.test("a token signed by someone else, or tampered with, is refused", async () => {
  assert.equal(
    await verifyGoogleIdToken(deps, await sign(good, { key: stranger.privateKey })),
    null,
  );
  const t = await sign(good);
  const [h, , s] = t.split(".");
  const forged = `${h}.${b64url(JSON.stringify({ ...good, sub: "victim" }))}.${s}`;
  assert.equal(await verifyGoogleIdToken(deps, forged), null);
  assert.equal(await verifyGoogleIdToken(deps, await sign(good, { kid: "unknown" })), null);
  assert.equal(await verifyGoogleIdToken(deps, await sign(good, { alg: "none" })), null);
});

Deno.test("another app's token, another issuer, or an expired or old token is refused", async () => {
  for (
    const claims of [
      { ...good, aud: "someone-else.apps.googleusercontent.com" },
      { ...good, aud: [WEB] },
      { ...good, iss: "https://evil.example" },
      { ...good, exp: NOW - 1 },
      { ...good, iat: NOW - FRESH_SECONDS - 1 },
      { ...good, iat: NOW + 3600 },
      { ...good, sub: "" },
      { ...good, sub: undefined },
    ]
  ) {
    assert.equal(await verifyGoogleIdToken(deps, await sign(claims)), null, JSON.stringify(claims));
  }
});

Deno.test("garbage is refused without throwing", async () => {
  for (const t of ["", "a.b", "a.b.c", "!!.??.**", "x".repeat(50)]) {
    assert.equal(await verifyGoogleIdToken(deps, t), null);
  }
});

Deno.test("when Google's keys cannot be fetched it fails loudly, not open", async () => {
  const down = {
    ...deps,
    fetch: (() => Promise.resolve(new Response("", { status: 503 }))) as unknown as typeof fetch,
  };
  let threw = false;
  try {
    await verifyGoogleIdToken(down, await sign(good));
  } catch {
    threw = true;
  }
  assert.equal(threw, true);
});
