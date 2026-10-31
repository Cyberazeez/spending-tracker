import type { ParsedTxn, ParseResult } from "./types.ts";
import {
  dateOnlyIso,
  isWalletMerchant,
  last4,
  normalizeText,
  pickDate,
  toHalalas,
  toMinor,
} from "./util.ts";
import { strip } from "./alinma.ts";

const P = "barq/v1";
const NUM = "([\\d,]+(?:\\.\\d+)?)(?![\\d,]|\\.\\d|[ \\t]\\d)";

export function parseBarq(rawBody: string, receivedAt: Date): ParseResult {
  const body = normalizeText(rawBody);
  const head = body.split("\n")[0].trim();
  const one = (re: RegExp) => body.match(re)?.[1]?.trim();
  const at = pickDate(body, receivedAt);
  const tx = (t: ParsedTxn): ParseResult => ({ kind: "transaction", parser: P, txn: strip(t) });

  if (/^POS (International )?Purchase|^Online Purchase/i.test(head)) {
    const merchant = one(/^At:?\s*(.+)$/m);
    const card = last4(one(/(?:Visa\s*)?card:?\s*\*+(\d{4})/i));
    const acct = last4(one(/A\/C\s*\*+(\d{4})/));
    // "Amount: 19.1 BHD (190.23 SAR) FX 9.9597" | "Amount: 55.42 SAR FX 1.0000" | "Amount 3.99 SAR"
    const fx = body.match(
      new RegExp(`Amount:?\\s*${NUM}\\s*([A-Z]{3})\\s*\\(${NUM}\\s*SAR\\)\\s*FX\\s*([\\d.]+)`),
    );
    const plain = body.match(new RegExp(`Amount:?\\s*${NUM}\\s*SAR`));
    if (!at || !merchant || (!fx && !plain)) return { kind: "unparsed" };
    const sar = fx ? fx[3] : plain![1];
    return tx({
      bank: "barq",
      type: isWalletMerchant(merchant) ? "wallet_topup" : "purchase",
      direction: "out",
      amountHalalas: toHalalas(sar),
      merchant,
      cardLast4: card,
      accountLast4: acct,
      origAmountMinor: fx ? toMinor(fx[1]) : undefined,
      origCurrency: fx ? fx[2] : undefined,
      fxRate: fx ? Number(fx[4]) : undefined,
      occurredAt: at,
    });
  }

  if (/^Refund\b/i.test(head)) {
    const amt = one(new RegExp(`Amount:?\\s*${NUM}\\s*SAR`));
    const on = body.match(/On:?\s*(\d{4})-(\d{2})-(\d{2})/);
    if (!amt || !on) return { kind: "unparsed" };
    return tx({
      bank: "barq",
      type: "refund",
      direction: "in",
      amountHalalas: toHalalas(amt),
      merchant: one(/^At:?\s*(.+)$/m),
      cardLast4: last4(one(/card:?\s*\*+(\d{4})/i)),
      occurredAt: dateOnlyIso(+on[1], +on[2], +on[3], receivedAt),
    });
  }

  if (/^(Credit|Debit) Transfer Internal/i.test(head)) {
    const credit = /^Credit/i.test(head);
    const amt = one(new RegExp(`Amount:?\\s*${NUM}\\s*SAR`));
    if (!amt || !at) return { kind: "unparsed" };
    return tx({
      bank: "barq",
      type: credit ? "transfer_in" : "transfer_out",
      direction: credit ? "in" : "out",
      amountHalalas: toHalalas(amt),
      counterpartyName: one(credit ? /^From:?\s*(.+)$/m : /^To:?\s*(.+)$/m),
      counterpartyLast4: last4(
        one(credit ? /Sender A\/C:?\s*\*+(\d{4})/ : /To A\/C:?\s*\*+(\d{4})/),
      ),
      occurredAt: at,
    });
  }

  if (/^Money Added to your Barq wallet/i.test(head)) {
    const amt = one(new RegExp(`amount:?\\s*${NUM}\\s*SAR`));
    if (!amt || !at) return { kind: "unparsed" };
    return tx({
      bank: "barq",
      type: "wallet_topup",
      direction: "in",
      amountHalalas: toHalalas(amt),
      cardLast4: last4(one(/card number:?\s*\*+(\d{4})/i)),
      accountLast4: "1345",
      occurredAt: at,
    });
  }

  if (/^Rejected transaction/i.test(head)) {
    return { kind: "ignored", parser: P, reason: "declined" };
  }
  return { kind: "unparsed" };
}
