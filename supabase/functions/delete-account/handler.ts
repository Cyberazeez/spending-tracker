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
  getUser(authorization: string): Promise<{ id: string; email: string } | null>;
  /** True when the email and password sign in. */
  verifyPassword(email: string, password: string): Promise<boolean>;
  /** Marks the account for deletion in GRACE_DAYS; idempotent. */
  requestDeletion(userId: string): Promise<void>;
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
  const password = (body as { password?: unknown } | null)?.password;
  if (typeof password !== "string" || password === "" || password.length > 200) {
    return json(400, { error: "password_required" });
  }

  if (await deps.bumpRateLimit(user.id) > DELETE_LIMIT_PER_DAY) {
    return json(429, { error: "rate_limited" });
  }
  if (!(await deps.verifyPassword(user.email, password))) {
    return json(403, { error: "wrong_password" });
  }
  await deps.requestDeletion(user.id);
  try {
    await deps.notifyDeletion?.(user.email);
  } catch {
    // The mail is a courtesy; the deletion is already recorded.
  }
  return json(200, { ok: true, grace_days: GRACE_DAYS });
}
