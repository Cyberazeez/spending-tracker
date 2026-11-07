/**
 * Apple requires an app that offers Sign in with Apple to revoke the person's Apple token when they delete their
 * account. Apple's endpoints want a short-lived "client secret": a JWT signed (ES256) with the Sign in with Apple
 * key (.p8) of the owner's developer account. The key lives in Supabase secrets and is never logged.
 */
export interface AppleConfig {
  teamId: string;
  keyId: string;
  /** The .p8 file's PEM text. A secret saved on one line with literal "\n" is accepted too. */
  privateKey: string;
  /** The app's bundle ID (the Client ID Apple issued the token for). */
  clientId: string;
}

const APPLE_AUDIENCE = "https://appleid.apple.com";
const TOKEN_URL = "https://appleid.apple.com/auth/token";
const REVOKE_URL = "https://appleid.apple.com/auth/revoke";

function b64url(bytes: Uint8Array | string): string {
  const raw = typeof bytes === "string" ? new TextEncoder().encode(bytes) : bytes;
  let s = "";
  for (const b of raw) s += String.fromCharCode(b);
  return btoa(s).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}

function pemToDer(pem: string): Uint8Array<ArrayBuffer> {
  const body = pem
    .replaceAll("\\n", "\n")
    .replace(/-----(BEGIN|END) PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const bin = atob(body);
  const out = new Uint8Array(new ArrayBuffer(bin.length));
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

export async function appleClientSecret(cfg: AppleConfig, now: Date = new Date()): Promise<string> {
  const iat = Math.floor(now.getTime() / 1000);
  const header = { alg: "ES256", kid: cfg.keyId, typ: "JWT" };
  const claims = {
    iss: cfg.teamId,
    iat,
    exp: iat + 300,
    aud: APPLE_AUDIENCE,
    sub: cfg.clientId,
  };
  const signingInput = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(claims))}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(cfg.privateKey),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  // WebCrypto returns the raw r||s form that JWT ES256 wants.
  const sig = new Uint8Array(
    await crypto.subtle.sign(
      { name: "ECDSA", hash: "SHA-256" },
      key,
      new TextEncoder().encode(signingInput),
    ),
  );
  return `${signingInput}.${b64url(sig)}`;
}

/**
 * Trades the one-time authorization code from the app's Apple sheet for a refresh token, then revokes it. True when
 * Apple accepted the revoke. Never throws and never logs the code, the token or the secret.
 */
export async function revokeAppleAccess(
  deps: { fetch: typeof fetch; now?: () => Date },
  cfg: AppleConfig,
  authorizationCode: string,
): Promise<boolean> {
  try {
    const secret = await appleClientSecret(cfg, deps.now?.());
    const form = (o: Record<string, string>) => new URLSearchParams(o).toString();
    const headers = { "content-type": "application/x-www-form-urlencoded" };
    const tokenRes = await deps.fetch(TOKEN_URL, {
      method: "POST",
      headers,
      body: form({
        grant_type: "authorization_code",
        code: authorizationCode,
        client_id: cfg.clientId,
        client_secret: secret,
      }),
    });
    if (!tokenRes.ok) {
      console.error("apple_token_exchange_failed", tokenRes.status);
      return false;
    }
    const refresh = (await tokenRes.json() as { refresh_token?: unknown }).refresh_token;
    if (typeof refresh !== "string" || refresh === "") return false;
    const revokeRes = await deps.fetch(REVOKE_URL, {
      method: "POST",
      headers,
      body: form({
        token: refresh,
        token_type_hint: "refresh_token",
        client_id: cfg.clientId,
        client_secret: secret,
      }),
    });
    if (!revokeRes.ok) console.error("apple_revoke_failed", revokeRes.status);
    return revokeRes.ok;
  } catch {
    console.error("apple_revoke_failed", "error");
    return false;
  }
}

/** Reads the owner's Apple secrets; null when any is missing (revocation is then skipped, deletion still works). */
export function appleConfigFromEnv(get: (k: string) => string | undefined): AppleConfig | null {
  const teamId = get("APPLE_TEAM_ID");
  const keyId = get("APPLE_KEY_ID");
  const privateKey = get("APPLE_PRIVATE_KEY");
  if (!teamId || !keyId || !privateKey) return null;
  return {
    teamId,
    keyId,
    privateKey,
    clientId: get("APPLE_CLIENT_ID") || "com.cyberazeez.spendingtracker",
  };
}
