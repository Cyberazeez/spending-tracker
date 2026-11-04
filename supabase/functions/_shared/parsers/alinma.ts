import type { ParsedTxn, ParseResult } from "./types.ts";
import {
  cleanMerchant,
  isWalletMerchant,
  last4,
  lines,
  normalizeText,
  pickDate,
  toHalalas,
  toMinor,
} from "./util.ts";

const NUM = "([\\d,]+(?:\\.\\d+)?)(?![\\d,]|\\.\\d|[ \\t]\\d)";
const P = "alinma/v1";

export function parseAlinma(rawBody: string, receivedAt: Date): ParseResult {
  const body = normalizeText(rawBody);
  const one = (re: RegExp) => body.match(re)?.[1];
  const when = () => pickDate(body, receivedAt);

  if (/رمز\s*(ال)?تفعيل|\bOTP\b/i.test(body)) return { kind: "ignored", parser: P, reason: "otp" };
  if (/القسط الشهري للعقد/.test(body)) {
    return { kind: "ignored", parser: P, reason: "loan_due_notice" };
  }

  // Salary deposit
  if (/تم إيداع الراتب/.test(body)) {
    const amt = one(new RegExp(`مبلغ\\s*SAR\\s*${NUM}`));
    const at = when();
    if (!amt || !at) return { kind: "unparsed" };
    return tx({
      bank: "alinma",
      type: "salary",
      direction: "in",
      amountHalalas: toHalalas(amt),
      accountLast4: last4(one(/حساب\s*\*+(\d{4})/)),
      occurredAt: at,
    });
  }

  // Loan instalment deduction (one month can arrive in several deductions)
  if (/خصم قسط تمويل/.test(body)) {
    const amt = one(new RegExp(`المبلغ\\s*:\\s*SAR\\s*${NUM}`));
    const at = when();
    if (!amt || !at) return { kind: "unparsed" };
    return tx({
      bank: "alinma",
      type: "loan_installment",
      direction: "out",
      amountHalalas: toHalalas(amt),
      merchant: "Murabahah Commodity RBG",
      accountLast4: last4(one(/حساب\s*:\s*\*+(\d{4})/)),
      occurredAt: at,
    });
  }

  // Credit-card statement notice (not a transaction)
  if (/إصدار كشف حساب/.test(body)) {
    const total = one(new RegExp(`إجمالي المبلغ المستحق\\s*:\\s*SAR\\s*${NUM}`));
    const min = one(new RegExp(`الحد الأدنى للسداد\\s*:\\s*SAR\\s*${NUM}`));
    // The date came as dd-MM-yyyy in October and as yyyy-MM-dd in November: take either.
    const dmy = body.match(/تاريخ الاستحقاق\s*:\s*(\d{2})-(\d{2})-(\d{4})/);
    const ymd = body.match(/تاريخ الاستحقاق\s*:\s*(\d{4})-(\d{2})-(\d{2})/);
    const dueDate = dmy
      ? `${dmy[3]}-${dmy[2]}-${dmy[1]}`
      : ymd
      ? `${ymd[1]}-${ymd[2]}-${ymd[3]}`
      : null;
    if (!total || !min || !dueDate) return { kind: "unparsed" };
    return {
      kind: "notice",
      parser: P,
      notice: "card_statement",
      cardLast4: last4(one(/\*+(\d{4})/)),
      totalDueHalalas: toHalalas(total),
      minimumDueHalalas: toHalalas(min),
      dueDate,
    };
  }

  // Credit-card payment confirmation: money from the account to the owner's own card (not spending)
  if (/تم سداد البطاقة الائتمانية/.test(body)) {
    const amt = one(new RegExp(`مبلغ\\s*${NUM}\\s*SAR`)) ??
      one(new RegExp(`مبلغ\\s*SAR\\s*${NUM}`));
    const at = when();
    if (!amt || !at) return { kind: "unparsed" };
    return tx({
      bank: "alinma",
      type: "card_payment",
      direction: "out",
      amountHalalas: toHalalas(amt),
      cardLast4: last4(one(/البطاقة الائتمانية\s*\*+(\d{4})/)),
      accountLast4: last4(one(/حساب\s*\*+(\d{4})/)),
      internalHint: true,
      occurredAt: at,
    });
  }

  // International purchase: "USD 10.46 - apple pay" + FX + amount due in SAR
  if (/شراء دولي/.test(body)) {
    const orig = body.match(/([A-Z]{3})\s*([\d,]+(?:\.\d+)?)\s*-/);
    const due = one(new RegExp(`المبلغ المستحق\\s*:?\\s*SAR\\s*${NUM}`));
    const fx = one(/سعر صرف\s*:?\s*([\d.]+)/);
    const fee = one(new RegExp(`رسوم\\s*:?\\s*SAR\\s*${NUM}`));
    const merchant = body.match(/من\s+(.+?)\s*-/)?.[1];
    const at = when();
    if (!orig || !due || !at) return { kind: "unparsed" };
    return tx({
      bank: "alinma",
      type: "purchase",
      direction: "out",
      amountHalalas: toHalalas(due),
      feeHalalas: fee && toHalalas(fee) > 0 ? toHalalas(fee) : undefined,
      origAmountMinor: toMinor(orig[2]),
      origCurrency: orig[1],
      fxRate: fx ? Number(fx) : undefined,
      merchant: merchant?.trim(),
      cardLast4: last4(one(/بطاقة ائتمانية\s*\*+(\d{4})/)),
      accountLast4: last4(one(/حساب\s*\*+(\d{4})/)),
      occurredAt: at,
    });
  }

  // Card purchase (POS / Apple Pay / online)
  if (/^\s*(?:POS-)?(?:ApplePay\s+)?.*شراء|شراء/.test(lines(body)[0] ?? "")) {
    // "بـ SAR 79.00" and the newer "بـ 10 SAR"
    const amt = one(new RegExp(`بـ\\s*SAR\\s*${NUM}`)) ?? one(new RegExp(`بـ\\s*${NUM}\\s*SAR`));
    const merchantLine = lines(body).find((l) => l.startsWith("لدى"));
    const at = when();
    if (!amt || !merchantLine || !at) return { kind: "unparsed" };
    const merchant = cleanMerchant(merchantLine.replace(/^لدى\s*/, ""));
    return tx({
      bank: "alinma",
      type: isWalletMerchant(merchant) ? "wallet_topup" : "purchase",
      direction: "out",
      amountHalalas: toHalalas(amt),
      merchant,
      cardLast4: last4(one(/بطاقة ائتمانية\s*\*+(\d{4})/)),
      occurredAt: at,
    });
  }

  // Outgoing / incoming local transfer
  if (/حوالة (صادرة|واردة) محلية/.test(body)) {
    const incoming = /واردة/.test(body);
    const amt = one(new RegExp(`مبلغ\\s*(?:SAR\\s*)?${NUM}`));
    const fee = one(new RegExp(`رسوم\\s*:?\\s*SAR\\s*${NUM}`));
    const at = when();
    if (!amt || !at) return { kind: "unparsed" };
    const name = incoming ? body.match(/من\s+(.+)/)?.[1] : body.match(/لـ\s*(.+)/)?.[1];
    return tx({
      bank: "alinma",
      type: incoming ? "transfer_in" : "transfer_out",
      direction: incoming ? "in" : "out",
      amountHalalas: toHalalas(amt),
      feeHalalas: fee && toHalalas(fee) > 0 ? toHalalas(fee) : undefined,
      counterpartyName: name?.trim(),
      counterpartyLast4: incoming ? undefined : last4(one(/لحساب\s*\*?(\d{4})/)),
      accountLast4: incoming ? last4(one(/حساب\s*\*(\d{4})/)) : "6000",
      occurredAt: at,
    });
  }
  return { kind: "unparsed" };
}

function tx(txn: ParsedTxn): ParseResult {
  return { kind: "transaction", parser: P, txn: strip(txn) };
}

export function strip<T extends object>(o: T): T {
  return Object.fromEntries(Object.entries(o).filter(([, v]) => v !== undefined)) as T;
}
