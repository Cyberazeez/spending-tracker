export interface IngestPayload {
  sender: string;
  body: string;
  receivedAt: Date;
}

export const MAX_SENDER = 64;
export const MAX_BODY = 4000;
/** Reject timestamps this far in the future (phone clock skew allowance). */
const MAX_FUTURE_MS = 10 * 60 * 1000;

export function parseIngestPayload(
  raw: unknown,
  now: Date = new Date(),
): { ok: true; value: IngestPayload } | { ok: false; error: string } {
  if (typeof raw !== "object" || raw === null) return { ok: false, error: "invalid_json" };
  const r = raw as Record<string, unknown>;
  if (typeof r.sender !== "string" || r.sender.trim() === "" || r.sender.length > MAX_SENDER) {
    return { ok: false, error: "invalid_sender" };
  }
  if (typeof r.body !== "string" || r.body.trim() === "" || r.body.length > MAX_BODY) {
    return { ok: false, error: "invalid_body" };
  }
  let receivedAt = now;
  if (r.received_at !== undefined && r.received_at !== null && r.received_at !== "") {
    const d = new Date(String(r.received_at));
    if (Number.isNaN(d.getTime())) return { ok: false, error: "invalid_received_at" };
    receivedAt = d.getTime() - now.getTime() > MAX_FUTURE_MS ? now : d;
  }
  return { ok: true, value: { sender: r.sender.trim(), body: r.body, receivedAt } };
}
