/**
 * Apple identity tokens for delete-account (2026-11-16): see id_token.ts. On top of those checks the token must carry
 * the nonce of this very sign-in: the app sends Apple the SHA-256 (hex) of a one-time random string and sends us the
 * string itself, so a token from any earlier sign-in does not match.
 * Returns the Apple account id (`sub`), or null.
 */
import { type IdTokenDeps, verifyIdToken } from "./id_token.ts";
import { sha256Hex } from "./token.ts";

export const APPLE_CERTS_URL = "https://appleid.apple.com/auth/keys";
export const APPLE_ISSUER = "https://appleid.apple.com";

export async function verifyAppleIdToken(
  deps: IdTokenDeps,
  token: string,
  rawNonce: string,
  /** Our own Apple client IDs: native Sign in with Apple issues the token to the app's bundle ID. */
  clientIds: string[],
): Promise<string | null> {
  if (rawNonce === "") return null;
  const claims = await verifyIdToken(deps, {
    certsUrl: APPLE_CERTS_URL,
    issuers: [APPLE_ISSUER],
    audiences: clientIds,
  }, token);
  if (!claims) return null;
  if (typeof claims.nonce !== "string" || claims.nonce !== await sha256Hex(rawNonce)) return null;
  return claims.sub;
}
