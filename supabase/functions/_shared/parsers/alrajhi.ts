import type { ParsedTxn, ParseResult } from "./types.ts";
import {
  cleanMerchant,
  isWalletMerchant,
  last4,
  lines,
  normalizeText,
  pickDate,
  riyadhToIso,
  toHalalas,
} from "./util.ts";
import { strip } from "./alinma.ts";

const P = "alrajhi/v1";
const NUM = "([\\d,]+(?:\\.\\d+)?)(?![\\d,]|\\.\\d|[ \\t]\\d)";

export function parseAlRajhi(rawBody: string, receivedAt: Date): ParseResult {
  const body = normalizeText(rawBody);
  const ls = lines(body);
  const head = ls[0] ?? "";
  const one = (re: RegExp) => body.match(re)?.[1]?.trim();
  const at = pickDate(body, receivedAt);
  const tx = (t: ParsedTxn): ParseResult => ({ kind: "transaction", parser: P, txn: strip(t) });

  if (/رمز التحقق|رمز التفعيل|رمز مؤقت/.test(body)) {
    return { kind: "ignored", parser: P, reason: "otp" };
  }
  if (/successfully (added|removed)/i.test(body) || /طلب (إضافة|اضافة)|بطاقة منتهية/.test(body)) {
    return { kind: "ignored", parser: P, reason: "wallet_event" };
  }
  if (/المستفيد/.test(head)) return { kind: "ignored", parser: P, reason: "beneficiary" };

  // Card purchase / ATM withdrawal: بطاقة:1271;مدى-ابل باي
  if (/^(شراء|سحب)/.test(head) && /بطاقة:/.test(body)) {
    const amt = one(new RegExp(`مبلغ\\s*:\\s*SAR\\s*${NUM}`));
    if (!amt || !at) return { kind: "unparsed" };
    const card = last4(one(/بطاقة\s*:\s*(\d{4})/));
    if (/^سحب/.test(head)) {
      return tx({
        bank: "alrajhi",
        type: "atm_withdrawal",
        direction: "out",
        amountHalalas: toHalalas(amt),
        merchant: one(/مكان السحب\s*:\s*(.+)$/m),
        cardLast4: card,
        accountLast4: "6331",
        occurredAt: at,
      });
    }
    const merchant = cleanMerchant(one(/لدى\s*:\s*(.+)$/m) ?? "");
    if (!merchant) return { kind: "unparsed" };
    return tx({
      bank: "alrajhi",
      type: isWalletMerchant(merchant) ? "wallet_topup" : "purchase",
      direction: "out",
      amountHalalas: toHalalas(amt),
      merchant,
      cardLast4: card,
      accountLast4: last4(one(/^من\s*:\s*(\d{4})$/m)),
      occurredAt: at,
    });
  }

  // Card purchase, layout seen from Nov 2026: "شراء PoS / عبر:NNNN;مدى-ابل باي / بـSAR 21 / لـMERCHANT / dd/MM/yy HH:mm"
  if (/^شراء/.test(head) && /^عبر\s*:/m.test(body)) {
    const amt = one(new RegExp(`^بـ\\s*SAR\\s*${NUM}`, "m"));
    const merchant = cleanMerchant(one(/^لـ\s*(.+)$/m) ?? "");
    const at = purchaseTime(body, receivedAt);
    if (!amt || !merchant || !at) return { kind: "unparsed" };
    return tx({
      bank: "alrajhi",
      type: isWalletMerchant(merchant) ? "wallet_topup" : "purchase",
      direction: "out",
      amountHalalas: toHalalas(amt),
      merchant,
      cardLast4: last4(one(/^عبر\s*:\s*(\d{4})/m)),
      occurredAt: at,
    });
  }

  if (/^حوالة/.test(head)) {
    const amt = one(new RegExp(`(?:مبلغ\\s*:\\s*SAR|بـ\\s*SR)\\s*${NUM}`));
    const fee = one(new RegExp(`(?:ال)?رسوم\\s*:\\s*(?:SAR|SR)\\s*${NUM}`));
    if (!amt || !at) return { kind: "unparsed" };
    const feeH = fee && toHalalas(fee) > 0 ? toHalalas(fee) : undefined;
    // Own-side and other-side account numbers appear in different layouts:
    //   "من 6331 / لـ6000;NAME"   "من:6331 ... الى:NAME"   "الى:6331 ... من:NAME / من:0102"
    const fromNum = last4(one(/^من\s*:?\s*(\d{4})$/m));
    const toNum = last4(one(/^(?:الى|إلى)\s*:?\s*(\d{4})$/m) ?? one(/^لـ\s*(\d{4})/m));
    const fromAfter = last4(one(/^من\s*:?\s*(\d{4})\b/m));
    const incoming = /واردة/.test(head) || (!!toNum && !fromNum && !/^لـ/m.test(body));
    if (incoming) {
      return tx({
        bank: "alrajhi",
        type: "transfer_in",
        direction: "in",
        amountHalalas: toHalalas(amt),
        accountLast4: toNum ?? last4(one(/^لـ\s*(\d{4})/m)),
        counterpartyLast4: last4(one(/^من\s*:?\s*(\d{4})/m)) ?? fromAfter,
        counterpartyName: one(/^من\s*:?\s*(?!\d)(.+)$/m) ?? one(/^من\s*\d{4};(.+)$/m),
        occurredAt: at,
      });
    }
    return tx({
      bank: "alrajhi",
      type: "transfer_out",
      direction: "out",
      amountHalalas: toHalalas(amt),
      feeHalalas: feeH,
      accountLast4: fromNum ?? last4(one(/^من\s*(\d{4})/m)),
      counterpartyLast4: last4(one(/^لـ\s*(\d{4})/m)) ??
        last4(one(/^(?:الى|إلى)\s*:?\s*\S.*?(\d{4})$/m)),
      counterpartyName: one(/^لـ\s*\d{4};(.+)$/m) ?? one(/^(?:الى|إلى)\s*:?\s*(?!\d)(.+)$/m),
      occurredAt: at,
    });
  }
  return { kind: "unparsed" };
}

/**
 * When a card purchase happened. In the "شراء PoS" layout the date printed in the SMS has been a day after the real
 * one (every sample so far, while the clock time matched the arrival to the minute), so a purchase is never placed
 * after the SMS arrived: if the printed date is later, keep its clock time on the arrival's Riyadh day, or the day
 * before when that time is still ahead of the arrival.
 */
function purchaseTime(body: string, receivedAt: Date): string | null {
  const printed = pickDate(body, receivedAt);
  const grace = 10 * 60 * 1000;
  if (printed && new Date(printed).getTime() <= receivedAt.getTime() + grace) return printed;
  const clock = body.match(/(\d{1,2}):(\d{2})(?!\d)/);
  if (!clock) return printed;
  const local = new Date(receivedAt.getTime() + 3 * 3600 * 1000); // Riyadh is UTC+3, no daylight saving
  const at = (dayOffset: number) =>
    riyadhToIso(
      local.getUTCFullYear(),
      local.getUTCMonth() + 1,
      local.getUTCDate() + dayOffset,
      +clock[1],
      +clock[2],
    );
  const today = at(0);
  return new Date(today).getTime() <= receivedAt.getTime() + grace ? today : at(-1);
}
