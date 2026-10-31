// Pure obligation logic: due dates, overdue status, creating instances from SMS notices and matching a payment
// to an open instance. No I/O, so it is fully unit tested. All dates are Riyadh calendar dates (UTC+3, no DST).
import { tokenPrefixMatch } from "./categorize.ts";

export interface DueRule {
  /** Day of month the payment is due. Clamped to the month length (31 -> 30 or 28). */
  day?: number;
  /** The period is the month the bill was issued; it is due in the following month. */
  next_month?: boolean;
  /** Due the day the salary lands; until it does, `fallback_day` is used. */
  after?: "salary";
  fallback_day?: number;
  /** Days after the due date before the instance counts as overdue. */
  grace?: number;
}

export interface ObMatch {
  /** Transaction types that may pay this obligation. Default: any outgoing spend-like type. */
  types?: string[];
  /** Strong hint: the transfer went to this account / card (last 4). */
  counterparty_last4?: string;
  card?: string;
  /** Weak hint: merchant words (normalised, whole-word prefix). Alone it only suggests... */
  merchant?: string[];
  /** ...unless this is set: merchant words plus an amount within tolerance are then enough to mark it paid. */
  auto_merchant?: boolean;
  /** Allowed difference from the expected amount, percent. Default 1. */
  tolerance_pct?: number;
  /** Several payments add up to the expected amount (the loan can be collected in parts). */
  accumulate?: boolean;
  /** Phone line (last 4) a bill notice is for. */
  line?: string;
}

export interface Ob {
  id: string;
  name: string;
  kind: "bill" | "fixed" | "loan" | "card_statement";
  expectedHalalas: number | null;
  dueRule: DueRule;
  match: ObMatch;
}

export type Status = "pending" | "paid" | "overdue" | "skipped";

export interface Inst {
  id: string;
  obligationId: string;
  periodStart: string;
  dueDate: string;
  expectedHalalas: number | null;
  actualHalalas: number | null;
  status: Status;
  transactionId: string | null;
  matchState: "auto" | "suggested" | "manual" | "none";
  createdAt: string;
}

export interface MatchTxn {
  id: string;
  type: string;
  direction: string;
  amountHalalas: number;
  counterpartyLast4: string | null;
  cardLast4: string | null;
  merchantNorm: string | null;
  occurredAt: string;
}

const RIYADH_MS = 3 * 3600 * 1000;
const DAY_MS = 24 * 3600 * 1000;

export function riyadhYmd(iso: string | Date): string {
  const d = new Date((typeof iso === "string" ? new Date(iso) : iso).getTime() + RIYADH_MS);
  return d.toISOString().slice(0, 10);
}

export function monthStartOf(iso: string | Date): string {
  return riyadhYmd(iso).slice(0, 8) + "01";
}

export function addDays(ymd: string, n: number): string {
  return new Date(Date.parse(ymd + "T00:00:00Z") + n * DAY_MS).toISOString().slice(0, 10);
}

function daysInMonth(y: number, m: number): number {
  return new Date(Date.UTC(y, m, 0)).getUTCDate();
}

/** The date a rule falls on for the period starting `periodStart` (YYYY-MM-01). */
export function dueDateFor(rule: DueRule, periodStart: string): string {
  let y = Number(periodStart.slice(0, 4));
  let m = Number(periodStart.slice(5, 7));
  if (rule.next_month) {
    m += 1;
    if (m > 12) {
      m = 1;
      y += 1;
    }
  }
  const wanted = rule.day ?? rule.fallback_day ?? 28;
  const d = Math.min(Math.max(wanted, 1), daysInMonth(y, m));
  return `${y}-${String(m).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
}

/** "Pay when the salary is in": the due date becomes the day the salary landed. */
export function dueDateAfterSalary(
  rule: DueRule,
  salaryOccurredAt: string,
  current: string,
): string {
  return rule.after === "salary" ? riyadhYmd(salaryOccurredAt) : current;
}

/** What to show: a pending instance becomes overdue once today is past the due date plus grace. */
export function effectiveStatus(
  inst: Pick<Inst, "status" | "dueDate">,
  rule: DueRule,
  today: string,
): Status {
  if (inst.status !== "pending" && inst.status !== "overdue") return inst.status;
  return today > addDays(inst.dueDate, rule.grace ?? 0) ? "overdue" : "pending";
}

export function obligationForBill(obs: Ob[], lineLast4: string): Ob | undefined {
  return obs.find((o) => o.kind === "bill" && o.match.line === lineLast4);
}

export function obligationForStatement(obs: Ob[], cardLast4: string | undefined): Ob | undefined {
  return obs.find((o) => o.kind === "card_statement" && (!cardLast4 || o.match.card === cardLast4));
}

export interface NewInstance {
  periodStart: string;
  dueDate: string;
  expectedHalalas: number;
}

/** A bill-issued SMS: the period is the month it was issued, the amount is the bill total. */
export function instanceFromBill(
  ob: Ob,
  totalHalalas: number,
  receivedAt: string | Date,
): NewInstance {
  const periodStart = monthStartOf(receivedAt);
  return {
    periodStart,
    dueDate: dueDateFor(ob.dueRule, periodStart),
    expectedHalalas: totalHalalas,
  };
}

/** A card statement SMS: due date and total come from the SMS (the minimum payment is not an obligation). */
export function instanceFromStatement(
  totalDueHalalas: number,
  dueDate: string,
  receivedAt: string | Date,
): NewInstance {
  return { periodStart: monthStartOf(receivedAt), dueDate, expectedHalalas: totalDueHalalas };
}

export interface MatchResult {
  instanceId: string;
  state: "auto" | "suggested";
  status: "paid" | "pending";
  actualHalalas: number;
  transactionId: string;
}

const PAYING_TYPES = [
  "purchase",
  "transfer_out",
  "wallet_topup",
  "bill_payment",
  "card_payment",
  "loan_installment",
];
/** One riyal of slack so a loan counts as collected despite rounding. */
const COVER_SLACK = 100;

/** Finds the open instance this outgoing payment most likely settles, or null. Never guesses on amount alone. */
export function matchTransaction(txn: MatchTxn, instances: Inst[], obs: Ob[]): MatchResult | null {
  if (txn.direction !== "out") return null;
  const byId = new Map(obs.map((o) => [o.id, o]));
  let best: { score: number; diff: number; due: string; res: MatchResult } | null = null;

  for (const inst of instances) {
    if (inst.status !== "pending" && inst.status !== "overdue") continue;
    const ob = byId.get(inst.obligationId);
    if (!ob || inst.expectedHalalas == null) continue;
    const m = ob.match;
    if (!(m.types ?? PAYING_TYPES).includes(txn.type)) continue;
    if (Date.parse(txn.occurredAt) < Date.parse(inst.createdAt) - DAY_MS) continue;

    const acc = !!m.accumulate;
    // A payment already linked blocks the instance, except a mere suggestion, which a strong match may replace.
    if (!acc && inst.transactionId && inst.matchState !== "suggested") continue;
    if (acc && inst.transactionId === txn.id) continue; // the same deduction is never counted twice
    const strong = acc ||
      (!!m.counterparty_last4 && txn.counterpartyLast4 === m.counterparty_last4) ||
      (!!m.card && txn.cardLast4 === m.card);
    const weak = !!txn.merchantNorm &&
      (m.merchant ?? []).some((w) => tokenPrefixMatch(w, txn.merchantNorm!));
    if (!strong && !weak) continue;
    // Sure enough to mark paid: a strong hint, or merchant words on an obligation that opts in (amount is checked below).
    const sure = strong || (weak && !!m.auto_merchant);
    if (!sure && inst.matchState === "suggested") continue; // a weak guess never replaces another guess

    const expected = inst.expectedHalalas;
    let res: MatchResult;
    let diff: number;
    if (acc) {
      const total = (inst.actualHalalas ?? 0) + txn.amountHalalas;
      if (total > expected + Math.ceil(expected / 100)) continue;
      diff = Math.abs(expected - total);
      res = {
        instanceId: inst.id,
        state: "auto",
        status: total >= expected - COVER_SLACK ? "paid" : "pending",
        actualHalalas: total,
        transactionId: txn.id,
      };
    } else {
      diff = Math.abs(txn.amountHalalas - expected);
      if (diff > Math.ceil(expected * (m.tolerance_pct ?? 1) / 100)) continue;
      res = {
        instanceId: inst.id,
        state: sure ? "auto" : "suggested",
        status: sure ? "paid" : "pending",
        actualHalalas: txn.amountHalalas,
        transactionId: txn.id,
      };
    }
    const score = strong ? 3 : sure ? 2 : 1;
    if (
      !best || score > best.score || (score === best.score && (diff < best.diff ||
        (diff === best.diff && inst.dueDate < best.due)))
    ) best = { score, diff, due: inst.dueDate, res };
  }
  return best?.res ?? null;
}
