import { isWalletMerchant } from "./parsers/util.ts";

// Reads the text of an Alinma credit card statement PDF (as produced by `pdftotext -layout`) into rows.
// Pure and I/O free. The statement carries dates but no times, and its own totals, which are used as a checksum.

export type RowKind =
  | "purchase"
  | "refund"
  | "fee"
  | "payment" // money paid into the card from an own account (internal)
  | "plan_move"
  | "plan_item"
  | "other";

export interface StatementRow {
  /** Date of the purchase, YYYY-MM-DD. */
  date: string;
  postingDate: string;
  /** 12-digit transaction number when the bank prints one. */
  txnNo: string | null;
  description: string;
  /** Merchant name as printed, with the city part removed. */
  merchant: string;
  foreignMinor: number;
  rate: number;
  /** Signed: purchases and fees are positive, payments and refunds negative. */
  amountHalalas: number;
  kind: RowKind;
}

export interface Summary {
  minimumDueHalalas: number;
  totalDueHalalas: number;
  feesHalalas: number;
  purchasesHalalas: number;
  previousBalanceHalalas: number;
  availableLimitHalalas: number;
  paymentsHalalas: number;
}

export interface ParsedStatement {
  statementDate: string;
  dueDate: string;
  cardLast4: string | null;
  summary: Summary | null;
  rows: StatementRow[];
  /** Do the row sums agree with the statement's own totals? */
  checksum: { ok: boolean; positives: number; negatives: number } | null;
}

const BIDI = /[‎‏‪-‮⁦-⁩؜]/g;

function money(s: string): number {
  const neg = s.trim().startsWith("-");
  const n = s.replace(/[-,\s]/g, "");
  if (!/^\d+\.\d\d$/.test(n)) throw new Error("bad money");
  const [w, f] = n.split(".");
  const v = parseInt(w, 10) * 100 + parseInt(f, 10);
  if (!Number.isSafeInteger(v)) throw new Error("bad money");
  return neg ? -v : v;
}

function isoDate(dmy: string): string {
  const [d, m, y] = dmy.split("/");
  return `${y}-${m}-${d}`;
}

/** "WALAA COOPERATIVE INSURAN~~RIY" -> "WALAA COOPERATIVE INSURAN". The bank glues the city after "~~". */
export function merchantOf(description: string): string {
  const name = description.split("~~")[0];
  return name.replace(/\s+/g, " ").trim();
}

const ROW = /^\s*(\d{2}\/\d{2}\/\d{4})\s+(\d{2}\/\d{2}\/\d{4})\s+(.*\S)\s*$/;
const TAIL = /^(.*?)\s+(-?[\d,]+\.\d\d)\s+(\d+\.\d{4})\s+(-?[\d,]+\.\d\d)\s+(-?[\d,]+\.\d\d)$/;

function classify(desc: string, txnNo: string | null, amount: number): RowKind {
  if (/^Account to Card Transfer/i.test(desc) && amount < 0) return "payment";
  if (/MOVED TO PAYMENT PLAN/i.test(desc)) return "plan_move";
  if (/INSTAL+MENT ITEM/i.test(desc)) return "plan_item";
  if (txnNo === null) return amount > 0 ? "fee" : "other";
  return amount > 0 ? "purchase" : amount < 0 ? "refund" : "other";
}

function numbersAfter(lines: string[], label: RegExp): number[] | null {
  const i = lines.findIndex((l) => label.test(l));
  if (i < 0) return null;
  for (let j = i + 1; j < Math.min(i + 6, lines.length); j++) {
    const nums = lines[j].match(/[\d,]+\.\d\d/g);
    if (nums && nums.length >= 2 && lines[j].replace(/[\d,.\s]/g, "") === "") {
      return nums.map(money);
    }
  }
  return null;
}

export function parseStatementText(raw: string): ParsedStatement {
  const text = raw.replace(BIDI, "");
  const lines = text.split("\n").map((l) => l.replace(/[ \t]{2,}/g, "  "));
  const flat = lines.join("\n");
  const sd = flat.match(/Statement Date\s+(\d{2}\/\d{2}\/\d{4})/);
  const dd = flat.match(/Payment Due date\s+(\d{2}\/\d{2}\/\d{4})/);
  if (!sd || !dd) throw new Error("not an Alinma card statement");
  const card = flat.match(/\*{4,}(\d{4})\b/);

  const a = numbersAfter(lines, /Minimum Amount Due/);
  const b = numbersAfter(lines, /Total Fees and Charges/);
  const c = numbersAfter(lines, /Available Credit Limit/);
  const summary: Summary | null = a && b && c
    ? {
      minimumDueHalalas: a[0],
      totalDueHalalas: a[1],
      feesHalalas: b[0],
      purchasesHalalas: b[1],
      previousBalanceHalalas: b[2] ?? 0,
      availableLimitHalalas: c[0],
      paymentsHalalas: c[1],
    }
    : null;

  const rows: StatementRow[] = [];
  for (const line of lines) {
    const m = line.match(ROW);
    if (!m) continue;
    const t = m[3].match(TAIL);
    if (!t) continue;
    let desc = t[1].trim();
    const noMatch = desc.match(/^(\d{12})\s+(.*)$/);
    const txnNo = noMatch ? noMatch[1] : null;
    if (noMatch) desc = noMatch[2];
    const amount = money(t[5]);
    rows.push({
      date: isoDate(m[1]),
      postingDate: isoDate(m[2]),
      txnNo,
      description: desc,
      merchant: merchantOf(desc),
      foreignMinor: Math.abs(money(t[2])),
      rate: Number(t[3]),
      amountHalalas: amount,
      kind: classify(desc, txnNo, amount),
    });
  }

  let checksum: ParsedStatement["checksum"] = null;
  if (summary) {
    // The statement's totals leave out lines that belong to a payment plan, so the check does too.
    const planNos = new Set(
      rows.filter((r) => r.kind === "plan_move" || r.kind === "plan_item").map((r) => r.txnNo),
    );
    const counted = rows.filter((r) => !(r.txnNo && planNos.has(r.txnNo)));
    const positives = counted.filter((r) => r.amountHalalas > 0).reduce(
      (s, r) => s + r.amountHalalas,
      0,
    );
    const negatives = counted.filter((r) => r.amountHalalas < 0).reduce(
      (s, r) => s + r.amountHalalas,
      0,
    );
    checksum = {
      ok: positives === summary.purchasesHalalas && -negatives === summary.paymentsHalalas,
      positives,
      negatives,
    };
  }
  return {
    statementDate: isoDate(sd[1]),
    dueDate: isoDate(dd[1]),
    cardLast4: card ? card[1] : null,
    summary,
    rows,
    checksum,
  };
}

export interface ImportRow {
  /** Stable id so importing the same statement twice changes nothing. */
  ref: string;
  date: string;
  /** wallet_topup = money moved to a wallet (barq, D360): internal, not spending. */
  type: "purchase" | "refund" | "fee" | "wallet_topup";
  direction: "in" | "out";
  amountHalalas: number;
  merchant: string;
  card: string | null;
}

export interface Skipped {
  reason: "payment" | "payment_plan" | "other";
  row: StatementRow;
}

/**
 * Turns statement rows into spending history. Card payoffs are internal money and are skipped. A purchase the bank
 * moved to a payment plan appears as four lines that cancel out; the original purchase is kept once and the plumbing
 * (plan move, instalment items and their reversals) is dropped.
 */
export function toImportRows(st: ParsedStatement): { rows: ImportRow[]; skipped: Skipped[] } {
  const planNos = new Set(
    st.rows.filter((r) => r.kind === "plan_move" || r.kind === "plan_item").map((r) => r.txnNo),
  );
  const rows: ImportRow[] = [];
  const skipped: Skipped[] = [];
  const seen = new Map<string, number>();
  const refOf = (r: StatementRow): string => {
    const base = r.txnNo
      ? `alinma:${st.cardLast4 ?? "card"}:${r.txnNo}`
      : `alinma:${st.cardLast4 ?? "card"}:${r.date}:${r.merchant}:${r.amountHalalas}`;
    const n = (seen.get(base) ?? 0) + 1;
    seen.set(base, n);
    return `${base}:${n}`;
  };

  for (const r of st.rows) {
    if (r.kind === "payment") {
      skipped.push({ reason: "payment", row: r });
      continue;
    }
    if (r.txnNo && planNos.has(r.txnNo)) {
      const move = st.rows.find((x) => x.txnNo === r.txnNo && x.kind === "plan_move");
      const isOriginal = move !== undefined && r.kind === "purchase" &&
        r.amountHalalas === -move.amountHalalas;
      if (!isOriginal) {
        skipped.push({ reason: "payment_plan", row: r });
        continue;
      }
    }
    if (r.kind === "other" || r.kind === "plan_move" || r.kind === "plan_item") {
      skipped.push({ reason: "other", row: r });
      continue;
    }
    // The extra line after a foreign purchase (same transaction number, no foreign amount) is the VAT on its fee.
    const followsForeign = r.txnNo !== null && r.kind === "purchase" && r.foreignMinor === 0 &&
      st.rows.some((x) =>
        x !== r && x.txnNo === r.txnNo && x.foreignMinor > 0 && x.date === r.date
      );
    const type = r.kind === "refund"
      ? "refund"
      : r.kind === "fee" || followsForeign
      ? "fee"
      : isWalletMerchant(r.merchant)
      ? "wallet_topup"
      : "purchase";
    rows.push({
      ref: refOf(r),
      date: r.date,
      type,
      direction: type === "refund" ? "in" : "out",
      amountHalalas: Math.abs(r.amountHalalas),
      merchant: type === "fee" && followsForeign ? "Foreign transaction fee" : r.merchant,
      card: st.cardLast4,
    });
  }
  return { rows, skipped };
}
