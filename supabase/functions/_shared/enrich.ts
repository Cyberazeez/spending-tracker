import { normalizeMerchant } from "./normalize.ts";
import { categorize, type CategoryIds, type Rule } from "./categorize.ts";
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
  card_last4: string | null;
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
  category_id?: string | null;
  category_source?: "rule" | null;
  rule_id?: string | null;
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
  // Paying the owner's own credit card from an account is a move between own money, never spending.
  const internal = t.type === "wallet_topup" || t.type === "card_payment" || !!t.internalHint ||
    ((t.type === "transfer_out" || t.type === "transfer_in") && counterpartyIsOwn(t, own));
  const base = {
    source: "sms" as const,
    bank: t.bank,
    account_last4: t.accountLast4 ?? null,
    card_last4: t.cardLast4 ?? null,
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

/** Fills in category_id / category_source / rule_id from the rules. Rows nothing matches stay uncategorised. */
export function applyCategories(rows: TxRow[], rules: Rule[], ids: CategoryIds): TxRow[] {
  return rows.map((r) => {
    const c = categorize(
      {
        type: r.type,
        merchantNorm: r.merchant_norm,
        cardLast4: r.card_last4,
        counterpartyLast4: r.counterparty_last4,
        isInternal: r.is_internal,
      },
      rules,
      ids,
    );
    return c
      ? {
        ...r,
        category_id: c.categoryId,
        category_source: "rule" as const,
        rule_id: c.ruleId ?? null,
      }
      : r;
  });
}

/** A stored transfer that might be the other bank's message of the same move. */
export interface TransferCandidate {
  id: string;
  isInternal: boolean;
  /** Its direction ("transfer_in" / "transfer_out"), its bank and the last 4 digits its SMS showed. */
  type: string;
  bank: string;
  accountLast4: string | null;
  counterpartyLast4: string | null;
}

/**
 * The other message of one transfer between the owner's own accounts: an out and an in of the same amount, close in
 * time (the lookup's window), that cannot be the same account: another bank, or the same bank with two different
 * account digits. When both SMS show digits they must not contradict each other (the money left account A for
 * account B, so the receiver's SMS must show B and name A); otherwise "I paid someone 500" and "someone paid me
 * 500" a minute apart would be read as one internal move.
 */
export function pairsWith(
  me: {
    type: string;
    bank: string;
    account_last4: string | null;
    counterparty_last4: string | null;
  },
  other: TransferCandidate,
): boolean {
  if (me.type === other.type) return false;
  const [out, inn] = me.type === "transfer_out"
    ? [
      { bank: me.bank, account: me.account_last4, other: me.counterparty_last4 },
      { bank: other.bank, account: other.accountLast4, other: other.counterpartyLast4 },
    ]
    : [
      { bank: other.bank, account: other.accountLast4, other: other.counterpartyLast4 },
      { bank: me.bank, account: me.account_last4, other: me.counterparty_last4 },
    ];
  if (out.bank === inn.bank && !(out.account && inn.account && out.account !== inn.account)) {
    return false; // the same bank needs two known, different accounts
  }
  if (out.other && inn.account && out.other !== inn.account) return false;
  if (inn.other && out.account && inn.other !== out.account) return false;
  return true;
}

/**
 * The two accounts of a paired move, for the owner's saved accounts: the sender's account at the sending bank and
 * the receiver's account at the receiving bank. The digits come from either SMS (each shows both sides when it can).
 * Only banks the app knows are saved (an AI-read message has no known bank), and a side without digits is skipped.
 */
export function accountsOfPair(
  me: {
    type: string;
    bank: string;
    account_last4: string | null;
    counterparty_last4: string | null;
  },
  other: TransferCandidate,
  knownBanks: readonly string[],
): OwnAccount[] {
  const meOut = me.type === "transfer_out";
  const outBank = meOut ? me.bank : other.bank;
  const inBank = meOut ? other.bank : me.bank;
  const outAccount = (meOut ? me.account_last4 : other.accountLast4) ??
    (meOut ? other.counterpartyLast4 : me.counterparty_last4);
  const inAccount = (meOut ? other.accountLast4 : me.account_last4) ??
    (meOut ? me.counterparty_last4 : other.counterpartyLast4);
  const out: OwnAccount[] = [];
  for (const [bank, last4] of [[outBank, outAccount], [inBank, inAccount]] as const) {
    if (last4 && /^\d{4}$/.test(last4) && knownBanks.includes(bank)) out.push({ bank, last4 });
  }
  return out;
}
