import type { ParseResult } from "./types.ts";
import { last4, normalizeText, toHalalas } from "./util.ts";

const P = "stc900/v1";
const NUM = "([\\d,]+(?:\\.\\d+)?)(?![\\d,]|\\.\\d|[ \\t]\\d)";

/** STC telecom bill notices from sender `900`. Only the line's last 4 digits and the total are kept. */
export function parseStc900(rawBody: string): ParseResult {
  const body = normalizeText(rawBody);
  if (/رمز|\bOTP\b/i.test(body) && !/فاتورة جديدة/.test(body)) {
    return { kind: "ignored", parser: P, reason: "otp" };
  }
  const m = body.match(
    new RegExp(`فاتورة جديدة للرقم\\s*(\\d{6,})\\s*بمبلغ إجمالي\\s*${NUM}\\s*ريال`),
  );
  if (!m) return { kind: "unparsed" };
  const line = last4(m[1]);
  if (!line) return { kind: "unparsed" };
  return {
    kind: "notice",
    parser: P,
    notice: "bill_issued",
    lineLast4: line,
    totalHalalas: toHalalas(m[2]),
  };
}
