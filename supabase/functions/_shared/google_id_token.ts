/**
 * Checks a Google ID token without signing anyone in (delete-account, 2026-11-16). Signing in with the token to see
 * whose it is would create an account for an unknown Google user, or start a session for another existing one; this
 * only reads it. The token must:
 *   - be signed (RS256) by one of Google's current keys,
 *   - come from Google (`iss`) for one of our own client IDs (`aud`),
 *   - be unexpired and freshly issued (`iat` within FRESH_SECONDS), since Supabase's nonce check is off for Google
 *     and an older token must not count as "the owner just proved it is them".
 * Returns the Google account id (`sub`), or null.
 */
export const GOOGLE_CERTS_URL = "https://www.googleapis.com/oauth2/v3/certs";
export const FRESH_SECONDS = 10 * 60;
const ISSUERS = ["accounts.google.com", "https://accounts.google.com"];

/** Public identifiers of the Google Cloud project "Halala" (same as AppConfig in the app). */
export const GOOGLE_CLIENT_IDS = [
  "785025965315-u1hqm7s7dndse7t6u9hcn0av44igael7.apps.googleusercontent.com", // web (Supabase)
  "785025965315-e9dj46u9bk97322l99f3jdnbn7rq07gu.apps.googleusercontent.com", // iOS
];

export interface GoogleTokenDeps {
  fetch: typeof fetch;
  /** Seconds since the epoch. */
  now(): number;
  clientIds?: string[];
}

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

export async function verifyGoogleIdToken(
  deps: GoogleTokenDeps,
  token: string,
): Promise<string | null> {
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  const header = b64urlJson(parts[0]);
  const claims = b64urlJson(parts[1]);
  if (!header || !claims || header.alg !== "RS256" || typeof header.kid !== "string") return null;

  const res = await deps.fetch(GOOGLE_CERTS_URL, { signal: AbortSignal.timeout(5000) });
  if (!res.ok) throw new Error("google_certs_unavailable");
  const { keys } = await res.json() as { keys?: Array<JsonWebKey & { kid?: string }> };
  const jwk = (keys ?? []).find((k) => k.kid === header.kid && k.kty === "RSA");
  if (!jwk) return null;
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
  const ids = deps.clientIds ?? GOOGLE_CLIENT_IDS;
  const aud = claims.aud;
  if (typeof claims.iss !== "string" || !ISSUERS.includes(claims.iss)) return null;
  if (typeof aud !== "string" || !ids.includes(aud)) return null;
  if (typeof claims.exp !== "number" || claims.exp <= now) return null;
  if (
    typeof claims.iat !== "number" || claims.iat < now - FRESH_SECONDS || claims.iat > now + 300
  ) {
    return null;
  }
  return typeof claims.sub === "string" && claims.sub !== "" ? claims.sub : null;
}
