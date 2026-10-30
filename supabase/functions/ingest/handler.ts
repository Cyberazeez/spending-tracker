import { dedupeKey } from "../_shared/dedupe.ts";
import { isOtpLike, REDACTED_BODY } from "../_shared/otp.ts";
import { parseIngestPayload } from "../_shared/request.ts";
import { isWellFormedToken, sha256Hex } from "../_shared/token.ts";

export const RATE_LIMIT_PER_MINUTE = 60;

export interface RawMessageRow {
  user_id: string;
  sender: string;
  body: string;
  received_at: string;
  dedupe_hash: string;
  parse_status: "needs_review" | "ignored";
  ignore_reason: string | null;
}

export interface IngestDeps {
  /** Returns the active (not revoked) token's owner, or null. */
  findToken(hash: string): Promise<{ id: string; userId: string } | null>;
  bumpRateLimit(userId: string): Promise<number>;
  /** Returns the new id, or null when the dedupe hash already exists. */
  insertRaw(row: RawMessageRow): Promise<string | null>;
  touchToken(tokenId: string): Promise<void>;
}

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });
}

/**
 * Milestone 1 stub: authenticates, rate-limits, dedupes and stores the raw message.
 * Parsing arrives in milestone 2, so everything non-OTP lands as needs_review.
 * Never logs or echoes the message body.
 */
export async function handleIngest(req: Request, deps: IngestDeps): Promise<Response> {
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  const token = req.headers.get("x-ingest-token");
  if (!isWellFormedToken(token)) return json(401, { error: "unauthorized" });
  const found = await deps.findToken(await sha256Hex(token));
  if (!found) return json(401, { error: "unauthorized" });

  if ((await deps.bumpRateLimit(found.userId)) > RATE_LIMIT_PER_MINUTE) {
    return json(429, { error: "rate_limited" });
  }

  let payload: unknown;
  try {
    payload = await req.json();
  } catch {
    return json(400, { error: "invalid_json" });
  }
  const parsed = parseIngestPayload(payload);
  if (!parsed.ok) return json(400, { error: parsed.error });
  const { sender, body, receivedAt } = parsed.value;

  const otp = isOtpLike(body);
  const id = await deps.insertRaw({
    user_id: found.userId,
    sender,
    body: otp ? REDACTED_BODY : body,
    received_at: receivedAt.toISOString(),
    dedupe_hash: await dedupeKey(sender, body, receivedAt),
    parse_status: otp ? "ignored" : "needs_review",
    ignore_reason: otp ? "otp" : null,
  });
  await deps.touchToken(found.id);

  return json(200, { ok: true, duplicate: id === null });
}
