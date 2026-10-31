import { normalizeMerchant } from "./normalize.ts";

export interface Rule {
  id?: string;
  /** Normalised merchant text, or "acct:1234" / "card:1234". */
  pattern: string;
  matchType: "exact" | "contains" | "prefix";
  categoryId: string;
  status: "confirmed" | "auto_unconfirmed";
  source: "user" | "ai" | "seed";
}

export interface CatInput {
  type: string;
  merchantNorm?: string | null;
  cardLast4?: string | null;
  counterpartyLast4?: string | null;
  isInternal: boolean;
}

export interface CatResult {
  categoryId: string;
  ruleId?: string;
  source: "rule";
  reason: string;
}

/** Category name -> id for this user. */
export type CategoryIds = Record<string, string>;

/** Money movements whose category follows from what they are, not from who was paid. */
const BY_TYPE: Record<string, string> = {
  fee: "Fees",
  salary: "Income",
  wallet_topup: "Transfers",
  loan_installment: "Loans",
  atm_withdrawal: "Other",
};

/**
 * "contains" means whole-word prefix match: every word of the pattern must be the start of the next word of
 * the merchant, in order. "mcdonalds" matches "mcdonalds1", "uber" matches "uber one", but "bolt" does not
 * match "carbolton" (no match inside a word).
 */
export function tokenPrefixMatch(pattern: string, merchant: string): boolean {
  const p = pattern.split(" ").filter(Boolean);
  const m = merchant.split(" ").filter(Boolean);
  if (!p.length) return false;
  for (let start = 0; start + p.length <= m.length; start++) {
    if (p.every((tok, i) => m[start + i].startsWith(tok))) return true;
  }
  return false;
}

function ruleMatches(r: Rule, input: CatInput): boolean {
  if (!r.pattern.trim()) return false;
  if (r.pattern.startsWith("acct:")) {
    return !!input.counterpartyLast4 && r.pattern === `acct:${input.counterpartyLast4}`;
  }
  if (r.pattern.startsWith("card:")) {
    return !!input.cardLast4 && r.pattern === `card:${input.cardLast4}`;
  }
  const m = input.merchantNorm;
  if (!m) return false;
  if (r.matchType === "exact") return m === r.pattern;
  if (r.matchType === "prefix") return m.startsWith(r.pattern);
  return tokenPrefixMatch(r.pattern, m);
}

/** Higher wins: the owner's own rules, then confirmed rules, then exact over prefix over contains, then longer patterns. */
function rank(r: Rule): number[] {
  const kind = r.pattern.startsWith("acct:") || r.pattern.startsWith("card:") ? 2 : 1;
  return [
    r.source === "user" ? 2 : r.status === "confirmed" ? 1 : 0,
    kind,
    r.matchType === "exact" ? 2 : r.matchType === "prefix" ? 1 : 0,
    r.pattern.length,
  ];
}

function better(a: Rule, b: Rule): boolean {
  const ra = rank(a);
  const rb = rank(b);
  for (let i = 0; i < ra.length; i++) if (ra[i] !== rb[i]) return ra[i] > rb[i];
  return false;
}

/** Null means "no rule applies": the transaction stays uncategorised and shows up for review. */
export function categorize(input: CatInput, rules: Rule[], ids: CategoryIds): CatResult | null {
  if (input.isInternal) return result(ids, "Transfers", "internal");
  const byType = BY_TYPE[input.type];
  if (byType) return result(ids, byType, `type:${input.type}`);
  let best: Rule | undefined;
  for (const r of rules) {
    if (ruleMatches(r, input) && (!best || better(r, best))) best = r;
  }
  if (best) {
    return {
      categoryId: best.categoryId,
      ruleId: best.id,
      source: "rule",
      reason: `rule:${best.pattern}`,
    };
  }
  if (input.type === "transfer_in") return result(ids, "Transfers", "type:transfer_in");
  return null;
}

function result(ids: CategoryIds, name: string, reason: string): CatResult | null {
  const id = ids[name];
  return id ? { categoryId: id, source: "rule", reason } : null;
}

/** Key used for a user-made rule: the normalised merchant, matched exactly. */
export function ruleKeyForMerchant(merchant: string): string {
  return normalizeMerchant(merchant);
}
