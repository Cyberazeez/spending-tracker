import type { ParsedTxn, ParseResult } from "./types.ts";
import { isWalletMerchant, last4, normalizeText, pickDate, toHalalas } from "./util.ts";
import { strip } from "./alinma.ts";

const P = "d360/v1";
const NUM = "([\\d,]+(?:\\.\\d+)?)";

export function parseD360(rawBody: string, receivedAt: Date): ParseResult {
  const body = normalizeText(rawBody);
  const head = body.split("\n")[0].trim();
  const one = (re: RegExp) => body.match(re)?.[1]?.trim();
  const at = pickDate(body, receivedAt);
  const tx = (t: ParsedTxn): ParseResult => ({ kind: "transaction", parser: P, txn: strip(t) });

  if (/^OTP\b/i.test(head)) return { kind: "ignored", parser: P, reason: "otp" };
  if (/^Transaction Declined/i.test(head)) {
    return { kind: "ignored", parser: P, reason: "declined" };
  }
  if (
    /digital wallet|activate your bank card|new device|^Dear Customer/i.test(body) &&
    !/^Amount/m.test(body)
  ) {
    return {
      kind: "ignored",
      parser: P,
      reason: /digital wallet|activate/i.test(body) ? "wallet_event" : "notice",
    };
  }

  const amount = one(new RegExp(`^Amount:?\\s*SAR\\s*${NUM}`, "m"));
  const card = last4(one(/^Card:?\s*\*+(\d{4})/m));

  if (/^Refund:/i.test(head)) {
    if (!amount || !at) return { kind: "unparsed" };
    return tx({
      bank: "d360",
      type: "refund",
      direction: "in",
      amountHalalas: toHalalas(amount),
      merchant: one(/^At:?\s*(.+)$/m),
      cardLast4: card,
      occurredAt: at,
    });
  }

  if (
    /^(Local POS Purchase|Local Online Purchase|Purchase|Online Purchase|International (POS|Online) Purchase)/i
      .test(head)
  ) {
    const merchant = one(/^At:?\s*(.+)$/m);
    if (!amount || !merchant || !at) return { kind: "unparsed" };
    return tx({
      bank: "d360",
      type: isWalletMerchant(merchant) ? "wallet_topup" : "purchase",
      direction: "out",
      amountHalalas: toHalalas(amount),
      merchant,
      cardLast4: card,
      accountLast4: last4(one(/^Account number:?\s*\*+(\d{4})/m)),
      occurredAt: at,
    });
  }

  if (/^Account Funding via Apple Pay/i.test(head)) {
    if (!amount || !at) return { kind: "unparsed" };
    return tx({
      bank: "d360",
      type: "wallet_topup",
      direction: "in",
      amountHalalas: toHalalas(amount),
      cardLast4: card,
      accountLast4: last4(one(/^To:?\s*\*+(\d{4})/m)),
      occurredAt: at,
    });
  }
  return { kind: "unparsed" };
}
