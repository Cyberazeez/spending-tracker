export type TxType =
  | "purchase"
  | "refund"
  | "atm_withdrawal"
  | "transfer_out"
  | "transfer_in"
  | "salary"
  | "bill_payment"
  | "card_payment"
  | "wallet_topup"
  | "loan_installment"
  | "fee";

export type Bank = "alrajhi" | "snb" | "alinma" | "barq" | "d360" | "stc";

export interface ParsedTxn {
  bank: Bank;
  type: TxType;
  direction: "in" | "out";
  /** SAR amount in halalas. For a foreign amount with no SAR figure this is an estimate (see `estimated`). */
  amountHalalas: number;
  /** Fee charged with the transaction (becomes its own `fee` transaction), halalas. */
  feeHalalas?: number;
  merchant?: string;
  /** Own account the money moved on (last 4). */
  accountLast4?: string;
  /** Card used (last 4), when different from the account. */
  cardLast4?: string;
  counterpartyName?: string;
  counterpartyLast4?: string;
  origAmountMinor?: number;
  origCurrency?: string;
  fxRate?: number;
  estimated?: boolean;
  /** The bank said the transfer is between the owner's own accounts. */
  internalHint?: boolean;
  occurredAt: string;
}

export type ParseResult =
  | { kind: "transaction"; parser: string; txn: ParsedTxn }
  | {
    kind: "notice";
    parser: string;
    notice: "card_statement";
    cardLast4?: string;
    totalDueHalalas: number;
    minimumDueHalalas: number;
    dueDate: string;
  }
  | {
    kind: "notice";
    parser: string;
    notice: "bill_issued";
    /** Last 4 digits of the phone line the bill is for. */
    lineLast4: string;
    totalHalalas: number;
  }
  | { kind: "ignored"; parser: string; reason: string }
  | { kind: "unparsed" };
