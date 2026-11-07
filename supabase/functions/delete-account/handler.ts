/**
 * Account deletion (Apple requires it for apps that let people create accounts). The signed-in user proves who they
 * are again with their password; the account is then marked for deletion (capture tokens revoked, sessions ended).
 * Signing in again within GRACE_DAYS cancels it; a daily database job deletes the auth user after that, and every
 * table row follows by `on delete cascade` (checked by the RLS test).
 */
export const DELETE_LIMIT_PER_DAY = 5;
export const GRACE_DAYS = 30;

export interface DeleteDeps {
  /** The user behind the request's JWT, or null. */
  getUser(
    authorization: string,
  ): Promise<{ id: string; email: string; providers?: string[] } | null>;
  /** True when the email and password sign in. */
  verifyPassword(email: string, password: string): Promise<boolean>;
  /** Marks the account for deletion in GRACE_DAYS; idempotent. */
  requestDeletion(userId: string): Promise<void>;
  /**
   * Fresh proof for accounts with no password: a new Apple identity token (and its raw nonce) that Supabase accepts.
   * Returns the user id it belongs to, or null.
   */
  verifyApple?(idToken: string, nonce: string): Promise<string | null>;
  /** Best-effort: revoke the person's Apple token (Apple's rule for account deletion). True when Apple accepted. */
  revokeApple?(authorizationCode: string): Promise<boolean>;
  /** Counts this try; returns how many today. */
  bumpRateLimit(userId: string): Promise<number>;
  /** Best-effort "your account will be deleted in 30 days" mail; a failure never blocks the deletion. */
  notifyDeletion?(email: string): Promise<void>;
}

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });
}

export async function handleDeleteAccount(req: Request, deps: DeleteDeps): Promise<Response> {
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });
  const auth = req.headers.get("authorization") ?? "";
  if (!auth.toLowerCase().startsWith("bearer ")) return json(401, { error: "unauthorized" });
  const user = await deps.getUser(auth);
  if (!user) return json(401, { error: "unauthorized" });

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "invalid_json" });
  }
  const providers = user.providers ?? ["email"];
  const b = (body ?? {}) as { password?: unknown; apple?: unknown };

  // Accounts that signed up with Apple have no password: they prove themselves with a fresh Apple sign-in instead.
  const apple = b.apple as
    | { id_token?: unknown; nonce?: unknown; authorization_code?: unknown }
    | undefined;
  let authorizationCode: string | undefined;
  if (apple !== undefined) {
    if (
      typeof apple !== "object" || apple === null || !providers.includes("apple") ||
      typeof apple.id_token !== "string" || apple.id_token === "" ||
      apple.id_token.length > 4000 || typeof apple.nonce !== "string" || apple.nonce === "" ||
      apple.nonce.length > 200 || !deps.verifyApple
    ) {
      return json(400, { error: "invalid_apple_proof" });
    }
    if (typeof apple.authorization_code === "string" && apple.authorization_code.length <= 2000) {
      authorizationCode = apple.authorization_code;
    }
    if (await deps.bumpRateLimit(user.id) > DELETE_LIMIT_PER_DAY) {
      return json(429, { error: "rate_limited" });
    }
    const who = await deps.verifyApple(apple.id_token, apple.nonce);
    if (who !== user.id) return json(403, { error: "wrong_apple_account" });
  } else {
    const password = b.password;
    if (typeof password !== "string" || password === "" || password.length > 200) {
      return json(400, { error: "password_required" });
    }
    if (!providers.includes("email")) return json(400, { error: "use_apple" });
    if (await deps.bumpRateLimit(user.id) > DELETE_LIMIT_PER_DAY) {
      return json(429, { error: "rate_limited" });
    }
    if (!(await deps.verifyPassword(user.email, password))) {
      return json(403, { error: "wrong_password" });
    }
  }
  await deps.requestDeletion(user.id);
  try {
    if (user.email) await deps.notifyDeletion?.(user.email);
  } catch {
    // The mail is a courtesy; the deletion is already recorded.
  }
  let revoked = false;
  if (authorizationCode && deps.revokeApple) {
    try {
      revoked = await deps.revokeApple(authorizationCode);
    } catch {
      // Revocation is best effort: the account is already marked for deletion.
    }
  }
  return json(200, { ok: true, grace_days: GRACE_DAYS, apple_revoked: revoked });
}
