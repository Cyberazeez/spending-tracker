/**
 * Google ID tokens for delete-account (2026-11-16): see id_token.ts. Supabase's nonce check is off for Google, so the
 * freshness check there is what makes an older token not count as "the owner just proved it is them".
 * Returns the Google account id (`sub`), or null.
 */
import { FRESH_SECONDS, type IdTokenDeps, verifyIdToken } from "./id_token.ts";

export { FRESH_SECONDS };
export const GOOGLE_CERTS_URL = "https://www.googleapis.com/oauth2/v3/certs";

/** Public identifiers of the Google Cloud project "Halala" (same as AppConfig in the app). */
export const GOOGLE_CLIENT_IDS = [
  "785025965315-u1hqm7s7dndse7t6u9hcn0av44igael7.apps.googleusercontent.com", // web (Supabase)
  "785025965315-e9dj46u9bk97322l99f3jdnbn7rq07gu.apps.googleusercontent.com", // iOS
];

export interface GoogleTokenDeps extends IdTokenDeps {
  clientIds?: string[];
}

export async function verifyGoogleIdToken(
  deps: GoogleTokenDeps,
  token: string,
): Promise<string | null> {
  const claims = await verifyIdToken(deps, {
    certsUrl: GOOGLE_CERTS_URL,
    issuers: ["accounts.google.com", "https://accounts.google.com"],
    audiences: deps.clientIds ?? GOOGLE_CLIENT_IDS,
  }, token);
  return claims?.sub ?? null;
}
