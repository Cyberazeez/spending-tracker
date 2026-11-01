import { type AiDeps, costHalalas, MODEL } from "./ai.ts";

export interface CategoryAgg {
  name: string;
  spentHalalas: number;
  avg3Halalas: number;
  budgetHalalas: number | null;
}

/** Everything the model ever sees: numbers and the owner's own category names. No merchants, no text from SMS. */
export interface Aggregates {
  month: string; // YYYY-MM
  spendHalalas: number;
  lastMonthToDateHalalas: number;
  savingsRatePct: number | null;
  salaryAboveBase: boolean;
  subscriptionsMonthlyHalalas: number;
  categories: CategoryAgg[];
}

const MAX_AMOUNT = 100_000_000_00; // 100 million SAR in halalas
const MAX_CATEGORIES = 25;

function amount(v: unknown): number | null {
  return typeof v === "number" && Number.isSafeInteger(v) && v >= 0 && v <= MAX_AMOUNT ? v : null;
}

/**
 * Rebuilds the aggregates from scratch, keeping only whitelisted numeric fields and category names that exist
 * in the caller's own category list. Anything else (extra fields, free text, odd numbers) is dropped or rejects it.
 */
export function sanitizeAggregates(input: unknown, allowedCategories: string[]): Aggregates | null {
  if (typeof input !== "object" || input === null) return null;
  const r = input as Record<string, unknown>;
  if (typeof r.month !== "string" || !/^\d{4}-(0[1-9]|1[0-2])$/.test(r.month)) return null;
  const spend = amount(r.spendHalalas);
  const last = amount(r.lastMonthToDateHalalas);
  const subs = amount(r.subscriptionsMonthlyHalalas);
  if (spend === null || last === null || subs === null) return null;
  let savings: number | null = null;
  if (r.savingsRatePct !== null && r.savingsRatePct !== undefined) {
    if (
      typeof r.savingsRatePct !== "number" || !Number.isFinite(r.savingsRatePct) ||
      r.savingsRatePct < -1000 || r.savingsRatePct > 100
    ) return null;
    savings = Math.round(r.savingsRatePct);
  }
  if (!Array.isArray(r.categories) || r.categories.length > MAX_CATEGORIES) return null;
  const allowed = new Set(allowedCategories);
  const categories: CategoryAgg[] = [];
  for (const c of r.categories) {
    if (typeof c !== "object" || c === null) return null;
    const x = c as Record<string, unknown>;
    if (typeof x.name !== "string" || !allowed.has(x.name)) return null;
    const spent = amount(x.spentHalalas);
    const avg = amount(x.avg3Halalas);
    const budget = x.budgetHalalas === null || x.budgetHalalas === undefined
      ? null
      : amount(x.budgetHalalas);
    if (spent === null || avg === null || (x.budgetHalalas != null && budget === null)) return null;
    categories.push({ name: x.name, spentHalalas: spent, avg3Halalas: avg, budgetHalalas: budget });
  }
  return {
    month: r.month,
    spendHalalas: spend,
    lastMonthToDateHalalas: last,
    savingsRatePct: savings,
    salaryAboveBase: r.salaryAboveBase === true,
    subscriptionsMonthlyHalalas: subs,
    categories,
  };
}

/** Category names are the owner's own text: still neutralised (no newlines, no long digit runs, no emails/URLs, short). */
export function safeName(n: string): string {
  const noControl = Array.from(n, (ch) => {
    const c = ch.charCodeAt(0);
    return c < 32 || c === 127 || c === 0x2028 || c === 0x2029 ? " " : ch;
  }).join("");
  return noControl
    .replace(/\S+@\S+/g, " ")
    .replace(/https?:\/\/\S+/gi, " ")
    .replace(/\d{4,}/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 40);
}

export interface Tip {
  text: string;
}

export type TipsOutcome =
  | { ok: true; tips: Tip[]; costHalalas: number }
  | { ok: false; reason: "disabled" | "no_key" | "cap_reached" | "failed" };

const sar = (h: number) => (h / 100).toFixed(2);

export function buildPrompt(a: Aggregates, language: "en" | "ar"): string {
  const lines = a.categories.map((c) =>
    `- ${safeName(c.name)}: spent ${sar(c.spentHalalas)} SAR, 3-month average ${
      sar(c.avg3Halalas)
    } SAR` +
    (c.budgetHalalas === null ? "" : `, budget ${sar(c.budgetHalalas)} SAR`)
  );
  return [
    "You are a careful personal-finance assistant. Give at most 5 short, specific savings tips for this month.",
    "Every tip must quote the SAR figures it is based on (use only the numbers below). No generic advice.",
    `Write in ${
      language === "ar" ? "Arabic" : "English"
    }. Reply with only a JSON array of strings.`,
    `Month: ${a.month}`,
    `Spent so far: ${sar(a.spendHalalas)} SAR (same day last month: ${
      sar(a.lastMonthToDateHalalas)
    } SAR)`,
    `Savings rate: ${a.savingsRatePct === null ? "unknown" : a.savingsRatePct + "%"}`,
    `Subscriptions per month: ${sar(a.subscriptionsMonthlyHalalas)} SAR`,
    "Categories:",
    ...lines,
  ].join("\n");
}

/** Asks Claude for tips on aggregates only. Fails closed; a tip without a number is dropped. */
export async function generateTips(
  deps: AiDeps,
  a: Aggregates,
  language: "en" | "ar",
): Promise<TipsOutcome> {
  if (!deps.aiEnabled) return { ok: false, reason: "disabled" };
  if (!deps.apiKey) return { ok: false, reason: "no_key" };
  try {
    if ((await deps.spentHalalas()) >= deps.capHalalas) return { ok: false, reason: "cap_reached" };
    const res = await deps.fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": deps.apiKey,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 800,
        messages: [{ role: "user", content: buildPrompt(a, language) }],
      }),
    });
    if (!res.ok) return { ok: false, reason: "failed" };
    const data = await res.json();
    const text: string = (data?.content ?? []).map((b: { text?: string }) => b.text ?? "").join("");
    const inTok = Number(data?.usage?.input_tokens ?? 0);
    const outTok = Number(data?.usage?.output_tokens ?? 0);
    const cost = costHalalas(inTok, outTok);
    await deps.recordUsage({ inputTokens: inTok, outputTokens: outTok, costHalalas: cost });
    const json = text.match(/\[[\s\S]*\]/)?.[0];
    if (!json) return { ok: false, reason: "failed" };
    const raw = JSON.parse(json) as unknown[];
    const tips = raw
      .filter((t): t is string => typeof t === "string" && t.length <= 300 && /\d/.test(t))
      .slice(0, 5)
      .map((t) => ({ text: t.trim() }));
    return { ok: true, tips, costHalalas: cost };
  } catch {
    return { ok: false, reason: "failed" };
  }
}
