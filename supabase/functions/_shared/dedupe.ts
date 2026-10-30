import { sha256Hex } from "./token.ts";

const BUCKET_MS = 2 * 60 * 1000;

export function normalizeBody(body: string): string {
  return body.replace(/\s+/g, " ").trim();
}

/** Same sender + same text within the same 2-minute bucket is one message (Shortcuts can retry). */
export function dedupeKey(sender: string, body: string, receivedAt: Date): Promise<string> {
  const bucket = Math.floor(receivedAt.getTime() / BUCKET_MS);
  return sha256Hex(`${sender.trim().toLowerCase()}|${normalizeBody(body)}|${bucket}`);
}
