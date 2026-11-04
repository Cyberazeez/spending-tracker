import { type AiDeps, categorizeMerchants, maskMerchant } from "../_shared/ai.ts";
import type { CategoryIds } from "../_shared/categorize.ts";

export interface UncategorizedMerchant {
  merchantNorm: string;
}

export interface BatchDeps {
  ai: AiDeps;
  categoryIds: CategoryIds;
  /** Distinct normalised merchants of uncategorised, non-internal spend. */
  uncategorizedMerchants(): Promise<string[]>;
  /** Saves "auto, unconfirmed" rules and categorises the matching past transactions. Returns how many were updated. */
  saveGuesses(guesses: { merchantNorm: string; categoryId: string }[]): Promise<number>;
}

export type BatchResult =
  | { ok: true; guessed: number; updated: number; costHalalas: number }
  | { ok: false; reason: string };

const letterCount = (s: string) => (s.match(/\p{L}/gu) ?? []).length;

/**
 * Only the masked name (no digit runs, emails, links) is ever sent, so a merchant like "KFIA 1831" or
 * "NMC7751" (terminal numbers in the name) goes as "kfia" / "nmc" and the answer is saved as a rule on its own full
 * name. Masked names with fewer than 3 letters carry nothing to guess from and are not sent. Merchants that share a
 * masked name share the guess.
 */
export async function runBatch(deps: BatchDeps): Promise<BatchResult> {
  const groups = new Map<string, string[]>();
  for (const m of await deps.uncategorizedMerchants()) {
    const masked = maskMerchant(m);
    if (letterCount(masked) < 3) continue;
    const list = groups.get(masked);
    if (list) list.push(m);
    else groups.set(masked, [m]);
  }
  if (!groups.size) return { ok: true, guessed: 0, updated: 0, costHalalas: 0 };
  const names = Object.keys(deps.categoryIds).filter((n) =>
    n !== "Income" && n !== "Transfers" && n !== "Fees"
  );
  const r = await categorizeMerchants(deps.ai, [...groups.keys()], names);
  if (!r.ok) return { ok: false, reason: r.reason };
  const guesses: { merchantNorm: string; categoryId: string }[] = [];
  for (const [masked, originals] of groups) {
    const categoryId = deps.categoryIds[r.categories[masked]];
    if (!categoryId) continue;
    for (const merchantNorm of originals) guesses.push({ merchantNorm, categoryId });
  }
  const updated = guesses.length ? await deps.saveGuesses(guesses) : 0;
  return { ok: true, guessed: guesses.length, updated, costHalalas: r.costHalalas };
}
