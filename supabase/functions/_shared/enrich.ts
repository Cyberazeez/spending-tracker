import { normalizeMerchant } from "./normalize.ts";
import type { ParsedTxn } from "./parsers/index.ts";

export interface OwnAccount {
  bank: string;
  last4: string;
}

/** Row shape for public.transactions (user_id and raw_message_id are added by the writer). */
export interface TxRow {
  source: "sms";
  bank: string;
  account_last4: string | null;
  direction: "in" | "out";
  type: string;
  amount_halalas: number;
  orig_amount_minor: number | null;
  orig_currency: string | null;
  fx_rate: number | null;
  amount_estimated: boolean;
  merchant_raw: string | null;
  merchant_norm: string | null;
  counterparty_name: string | null;
  counterparty_last4: string | null;
  is_internal: boolean;
  excluded_from_spend: boolean;
  occurred_at: string;
}

/** True when the other side of a transfer is one of the owner's own accounts. */
export function counterpartyIsOwn(t: ParsedTxn, own: OwnAccount[]): boolean {
  if (!t.counterpartyLast4) return false;
  return own.some((a) => a.last4 === t.counterpartyLast4);
}

/**
 * One parsed SMS becomes one transaction, plus a separate `fee` transaction when the SMS reports a fee.
 * Internal moves (wallet top-ups, own-account transfers) are flagged and excluded from spend totals.
 * Balances are never part of a ParsedTxn, so they cannot reach the database.
 */
export function buildRows(t: ParsedTxn, own: OwnAccount[]): TxRow[] {
  const internal = t.type === "wallet_topup" || !!t.internalHint ||
    ((t.type === "transfer_out" || t.type === "transfer_in") && counterpartyIsOwn(t, own));
  const base = {
    source: "sms" as const,
    bank: t.bank,
    account_last4: t.accountLast4 ?? null,
    direction: t.direction,
    type: t.type,
    amount_halalas: t.amountHalalas,
    orig_amount_minor: t.origAmountMinor ?? null,
    orig_currency: t.origCurrency ?? null,
    fx_rate: t.fxRate ?? null,
    amount_estimated: !!t.estimated,
    merchant_raw: t.merchant ?? null,
    merchant_norm: t.merchant ? normalizeMerchant(t.merchant) : null,
    counterparty_name: t.counterpartyName ?? null,
    counterparty_last4: t.counterpartyLast4 ?? null,
    is_internal: internal,
    excluded_from_spend: internal,
    occurred_at: t.occurredAt,
  };
  const rows: TxRow[] = [base];
  if (t.feeHalalas && t.feeHalalas > 0) {
    rows.push({
      ...base,
      direction: "out",
      type: "fee",
      amount_halalas: t.feeHalalas,
      orig_amount_minor: null,
      orig_currency: null,
      fx_rate: null,
      amount_estimated: false,
      merchant_raw: "Transfer fee",
      merchant_norm: "transfer fee",
      counterparty_name: null,
      counterparty_last4: null,
      is_internal: false,
      excluded_from_spend: false,
    });
  }
  return rows;
}
