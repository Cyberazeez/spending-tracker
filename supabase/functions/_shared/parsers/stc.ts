import type { ParsedTxn, ParseResult } from "./types.ts";
import {
  cleanMerchant,
  isWalletMerchant,
  last4,
  lines,
  normalizeText,
  pickDate,
  toHalalas,
} from "./util.ts";
import { strip } from "./alinma.ts";

const P = "stc/v1";
const NUM = "([\\d,]+(?:\\.\\d+)?)(?![\\d,]|\\.\\d|[ \\t]\\d)";
/** SAR is pegged at 3.75 USD; used only when a USD purchase carries no SAR amount. */
const USD_SAR_X100 = 375;

export function parseStc(rawBody: string, receivedAt: Date): ParseResult {
  const body = normalizeText(rawBody);
  const ls = lines(body);
  const head = ls[0] ?? "";
  const one = (re: RegExp) => body.match(re)?.[1]?.trim();
  const at = pickDate(body, receivedAt);
  const tx = (t: ParsedTxn): ParseResult => ({ kind: "transaction", parser: P, txn: strip(t) });

  if (/رصيد غير كافي/.test(head)) return { kind: "ignored", parser: P, reason: "declined" };
  if (/المستفيد|رمز/.test(head)) {
    return { kind: "ignored", parser: P, reason: /رمز/.test(head) ? "otp" : "beneficiary" };
  }

  // Card purchase: "شراء Apple Pay / VISA / عملية انترنت" with عبر:*6190 بـ:SAR 50 من:barq في:...
  if (/^(شراء|عملية)/.test(head)) {
    const m = body.match(new RegExp(`بـ\\s*:?\\s*(SAR|USD)\\s*${NUM}`));
    const merchant = one(/^من\s*:?\s*(.+)$/m);
    if (!m || !merchant || !at) return { kind: "unparsed" };
    const usd = m[1] === "USD";
    const major = m[2];
    return tx({
      bank: "stc",
      type: isWalletMerchant(cleanMerchant(merchant)) ? "wallet_topup" : "purchase",
      direction: "out",
      amountHalalas: usd ? Math.round((toHalalas(major) * USD_SAR_X100) / 100) : toHalalas(major),
      origAmountMinor: usd ? toHalalas(major) : undefined,
      origCurrency: usd ? "USD" : undefined,
      estimated: usd ? true : undefined,
      merchant: cleanMerchant(merchant),
      cardLast4: last4(one(/عبر\s*:?\s*\*(\d{4})/)),
      accountLast4: "6190",
      occurredAt: at,
    });
  }

  // Money added to the STC wallet
  if (/^إضافة أموال لحسابك/.test(head)) {
    const amt = one(new RegExp(`بـ\\s*:?\\s*${NUM}\\s*ر\\.?\\s*س`));
    if (!amt || !at) return { kind: "unparsed" };
    return tx({
      bank: "stc",
      type: "wallet_topup",
      direction: "in",
      amountHalalas: toHalalas(amt),
      accountLast4: "6190",
      occurredAt: at,
    });
  }

  // Local transfer out
  if (/^حوالة داخلية/.test(head)) {
    const amt = one(new RegExp(`بـ\\s*:?\\s*${NUM}\\s*ر\\.?\\s*س`));
    if (!amt || !at) return { kind: "unparsed" };
    return tx({
      bank: "stc",
      type: "transfer_out",
      direction: "out",
      amountHalalas: toHalalas(amt),
      counterpartyName: one(/^إلى\s*:?\s*(.+)$/m),
      counterpartyLast4: last4(one(/حساب\s*:?\s*\*(\d{4})/)),
      accountLast4: "6190",
      occurredAt: at,
    });
  }
  return { kind: "unparsed" };
}
