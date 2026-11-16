/**
 * Reads a sign-in provider's ID token (a JWT) without signing anyone in: delete-account uses it to check that a fresh
 * Apple or Google sign-in belongs to the account being deleted. Signing in with the token to see whose it is would
 * create an account for an unknown Apple ID or Google account, or start a session for someone else's (and a sign-in
 * cancels a pending deletion); this only reads it. The token must:
 *   - be signed (RS256) by one of the provider's current published keys,
 *   - come from the provider (`iss`) for one of our own client IDs (`aud`),
 *   - be unexpired and freshly issued (`iat` within FRESH_SECONDS),
 *   - name an account (`sub`).
 * Returns its claims, or null. Throws when the provider's keys cannot be fetched (the caller fails closed).
 */
export const FRESH_SECONDS = 10 * 60;
/** How far a provider's clock may run ahead of ours. */
const SKEW_SECONDS = 5 * 60;

export interface IdTokenDeps {
  fetch: typeof fetch;
  /** Seconds since the epoch. */
  now(): number;
}

export interface IdTokenRules {
  /** The provider's JSON Web Key Set. */
  certsUrl: string;
  issuers: string[];
  audiences: string[];
}

export type IdTokenClaims = Record<string, unknown> & { sub: string };

function b64urlBytes(s: string): Uint8Array<ArrayBuffer> {
  const b64 = s.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(s.length / 4) * 4, "=");
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function b64urlJson(s: string): Record<string, unknown> | null {
  try {
    const v = JSON.parse(new TextDecoder().decode(b64urlBytes(s)));
    return v && typeof v === "object" && !Array.isArray(v) ? v : null;
  } catch {
    return null;
  }
}

export async function verifyIdToken(
  deps: IdTokenDeps,
  rules: IdTokenRules,
  token: string,
): Promise<IdTokenClaims | null> {
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  const header = b64urlJson(parts[0]);
  const claims = b64urlJson(parts[1]);
  // Only RS256: "none", HS256 (a key confusion) and anything else are refused before any key is used.
  if (!header || !claims || header.alg !== "RS256" || typeof header.kid !== "string") return null;

  const res = await deps.fetch(rules.certsUrl, { signal: AbortSignal.timeout(5000) });
  if (!res.ok) throw new Error("id_token_keys_unavailable");
  const { keys } = await res.json() as { keys?: Array<JsonWebKey & { kid?: string }> };
  const jwk = (Array.isArray(keys) ? keys : []).find((k) =>
    k.kid === header.kid && k.kty === "RSA"
  );
  if (!jwk || typeof jwk.n !== "string" || typeof jwk.e !== "string") return null;
  const key = await crypto.subtle.importKey(
    "jwk",
    { kty: "RSA", n: jwk.n, e: jwk.e, alg: "RS256", ext: true },
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"],
  );
  let signature: Uint8Array<ArrayBuffer>;
  try {
    signature = b64urlBytes(parts[2]);
  } catch {
    return null;
  }
  const ok = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    key,
    signature,
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
  );
  if (!ok) return null;

  const now = deps.now();
  const aud = claims.aud;
  if (typeof claims.iss !== "string" || !rules.issuers.includes(claims.iss)) return null;
  if (typeof aud !== "string" || !rules.audiences.includes(aud)) return null;
  if (typeof claims.exp !== "number" || claims.exp <= now) return null;
  if (
    typeof claims.iat !== "number" || claims.iat < now - FRESH_SECONDS ||
    claims.iat > now + SKEW_SECONDS
  ) {
    return null;
  }
  if (typeof claims.sub !== "string" || claims.sub === "") return null;
  return claims as IdTokenClaims;
}
