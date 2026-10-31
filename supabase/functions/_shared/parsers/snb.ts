import type { ParsedTxn, ParseResult } from "./types.ts";
import { isWalletMerchant, last4, lines, normalizeText, pickDate, toHalalas } from "./util.ts";
import { strip } from "./alinma.ts";

const P = "snb/v1";
const NUM = "([\\d,]+(?:\\.\\d+)?)(?![\\d,]|\\.\\d|[ \\t]\\d)";

export function parseSnb(rawBody: string, receivedAt: Date): ParseResult {
  const body = normalizeText(rawBody);
  const ls = lines(body);
  const head = ls[0] ?? "";
  const one = (re: RegExp) => body.match(re)?.[1]?.trim();
  const at = pickDate(body, receivedAt);
  const amount = one(new RegExp(`(?:مبلغ|بـ)\\s*:?\\s*SAR\\s*${NUM}`));
  const fee = one(new RegExp(`رسوم\\s*:?\\s*SAR\\s*${NUM}`));
  const tx = (t: ParsedTxn): ParseResult => ({ kind: "transaction", parser: P, txn: strip(t) });
  const feeH = fee && toHalalas(fee) > 0 ? toHalalas(fee) : undefined;

  if (/رصيد غير كافي/.test(head)) return { kind: "ignored", parser: P, reason: "declined" };
  if (/تغيير الحد اليومي|تم تغيير/.test(body)) {
    return { kind: "ignored", parser: P, reason: "notice" };
  }

  // Card purchase: شراء انترنت / شراء POS-
  if (/^شراء/.test(head)) {
    // lines: "من *0103" (account), "من barq" (merchant), "مدى-ابل *3301" (card)
    const merchant = ls.map((l) => l.match(/^من\s+(?!\*)(.+)$/)?.[1]).find(Boolean);
    const account = last4(ls.map((l) => l.match(/^من\s*\*(\d{4})$/)?.[1]).find(Boolean));
    const card = last4(
      ls.map((l) => l.match(/^(?:مدى|.*ماستر|.*فيزا)[^*]*\*(\d{4})$/)?.[1]).find(Boolean),
    );
    if (!amount || !merchant || !at) return { kind: "unparsed" };
    return tx({
      bank: "snb",
      type: isWalletMerchant(merchant) ? "wallet_topup" : "purchase",
      direction: "out",
      amountHalalas: toHalalas(amount),
      merchant: merchant.trim(),
      accountLast4: account,
      cardLast4: card,
      occurredAt: at,
    });
  }

  // Between the owner's own accounts
  if (/^حوالة بين حساباتك/.test(head)) {
    if (!amount || !at) return { kind: "unparsed" };
    return tx({
      bank: "snb",
      type: "transfer_out",
      direction: "out",
      amountHalalas: toHalalas(amount),
      accountLast4: last4(one(/^من\s*\*(\d{4})/m)),
      counterpartyLast4: last4(one(/^إلى\s*\*(\d{4})/m)),
      internalHint: true,
      occurredAt: at,
    });
  }

  if (/^حوالة (صادرة|واردة)/.test(head) || /^حوالة (داخلية )?واردة/.test(head)) {
    const incoming = /واردة/.test(head);
    if (!amount || !at) return { kind: "unparsed" };
    if (incoming) {
      return tx({
        bank: "snb",
        type: "transfer_in",
        direction: "in",
        amountHalalas: toHalalas(amount),
        counterpartyName: one(/^مرسل\s*:?\s*(.+)$/m),
        counterpartyLast4: last4(one(/^من\s*:?\s*\*(\d{4})/m)),
        accountLast4: last4(one(/^إلى\s*:?\s*\*(\d{4})/m)),
        occurredAt: at,
      });
    }
    // outgoing: "من *0102" is the source; destination account is "إلى *6000" or "آيبان *6000"
    const name = one(/^(?:مستفيد|إلى)\s*:?\s*(?!\*)(.+)$/m);
    return tx({
      bank: "snb",
      type: "transfer_out",
      direction: "out",
      amountHalalas: toHalalas(amount),
      feeHalalas: feeH,
      counterpartyName: name,
      counterpartyLast4: last4(one(/^(?:إلى|آيبان)\s*:?\s*\*(\d{4})/m)),
      accountLast4: last4(one(/^من\s*:?\s*\*(\d{4})/m)),
      occurredAt: at,
    });
  }
  return { kind: "unparsed" };
}
