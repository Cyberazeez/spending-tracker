import type { ParseResult } from "./types.ts";
import { last4, normalizeText, toHalalas } from "./util.ts";

const P = "se/v1";
const NUM = "([\\d,]+(?:\\.\\d+)?)(?![\\d,]|\\.\\d|[ \\t]\\d)";

/**
 * Saudi Electricity bill notices (owner sample 2026-11-20). Only the account's last 4 digits and the total are kept;
 * the message has no due date, so the bill's own due rule sets it.
 */
export function parseSe(rawBody: string): ParseResult {
  const body = normalizeText(rawBody);
  const m = body.match(new RegExp(`صدرت فاتورة حسابك\\s*(\\d{6,})\\s*بمبلغ\\s*${NUM}\\s*ريال`));
  if (!m) return { kind: "unparsed" };
  const acct = last4(m[1]);
  if (!acct) return { kind: "unparsed" };
  return {
    kind: "notice",
    parser: P,
    notice: "bill_issued",
    biller: "se",
    lineLast4: acct,
    totalHalalas: toHalalas(m[2]),
  };
}
