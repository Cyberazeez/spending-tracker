/**
 * Sends the "account active again" mail. The app calls it right after a sign-in that cancelled a pending deletion.
 * The recipient is always the caller's own address from their JWT (never from the request body), only the one kind
 * below can be asked for, and it is rate limited, so it cannot be used to mail anyone else or to spam.
 */
import type { AccountEmailKind } from "../_shared/account_email.ts";

export const EMAIL_LIMIT_PER_DAY = 3;
const ALLOWED: AccountEmailKind[] = ["reactivated"];

export interface EmailDeps {
  getUser(authorization: string): Promise<{ id: string; email: string } | null>;
  bumpRateLimit(userId: string): Promise<number>;
  send(to: string, kind: AccountEmailKind): Promise<boolean>;
}

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });
}

export async function handleSendAccountEmail(req: Request, deps: EmailDeps): Promise<Response> {
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
  const kind = (body as { kind?: unknown } | null)?.kind;
  if (typeof kind !== "string" || !ALLOWED.includes(kind as AccountEmailKind)) {
    return json(400, { error: "invalid_kind" });
  }
  if (await deps.bumpRateLimit(user.id) > EMAIL_LIMIT_PER_DAY) {
    return json(429, { error: "rate_limited" });
  }
  const sent = await deps.send(user.email, kind as AccountEmailKind);
  return json(200, { ok: sent });
}
