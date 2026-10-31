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

/** The Claude answer is keyed by the masked merchant; only merchants whose masked form equals the stored key are applied. */
export async function runBatch(deps: BatchDeps): Promise<BatchResult> {
  const merchants = await deps.uncategorizedMerchants();
  if (!merchants.length) return { ok: true, guessed: 0, updated: 0, costHalalas: 0 };
  const names = Object.keys(deps.categoryIds).filter((n) =>
    n !== "Income" && n !== "Transfers" && n !== "Fees"
  );
  const r = await categorizeMerchants(deps.ai, merchants, names);
  if (!r.ok) return { ok: false, reason: r.reason };
  const guesses = merchants
    .map((m) => ({ merchantNorm: m, name: r.categories[maskMerchant(m)] }))
    // A merchant whose name was altered by masking is not safe to turn into a rule.
    .filter((g) => g.name && maskMerchant(g.merchantNorm) === g.merchantNorm)
    .map((g) => ({ merchantNorm: g.merchantNorm, categoryId: deps.categoryIds[g.name] }))
    .filter((g) => g.categoryId);
  const updated = guesses.length ? await deps.saveGuesses(guesses) : 0;
  return { ok: true, guessed: guesses.length, updated, costHalalas: r.costHalalas };
}
