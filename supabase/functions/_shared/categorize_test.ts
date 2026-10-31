import assert from "node:assert/strict";
import {
  categorize,
  type CategoryIds,
  type CatInput,
  type Rule,
  tokenPrefixMatch,
} from "./categorize.ts";

const IDS: CategoryIds = {
  Dining: "c-dining",
  Groceries: "c-groc",
  Fuel: "c-fuel",
  Transfers: "c-transfers",
  Fees: "c-fees",
  Income: "c-income",
  Loans: "c-loans",
  Other: "c-other",
  Horse: "c-horse",
  "House Card": "c-house",
  Subscriptions: "c-subs",
  Shopping: "c-shop",
  Transport: "c-trans",
};
const seed = (
  pattern: string,
  categoryId: string,
  matchType: Rule["matchType"] = "contains",
): Rule => ({
  id: `seed-${pattern}`,
  pattern,
  matchType,
  categoryId,
  status: "confirmed",
  source: "seed",
});
const RULES: Rule[] = [
  seed("hungerstation", "c-dining"),
  seed("mcdonalds", "c-dining"),
  seed("uber", "c-trans"),
  seed("apple com bill", "c-subs"),
  seed("extra", "c-shop"),
  seed("bolt", "c-trans"),
  seed("acct:7892", "c-horse", "exact"),
  seed("card:8920", "c-house", "exact"),
];
const tx = (o: Partial<CatInput>): CatInput => ({ type: "purchase", isInternal: false, ...o });

Deno.test("word-prefix matching: whole words only, in order", () => {
  assert.ok(tokenPrefixMatch("mcdonalds", "mcdonalds1"));
  assert.ok(tokenPrefixMatch("uber", "uber one membership"));
  assert.ok(tokenPrefixMatch("apple com bill", "apple com bill"));
  assert.ok(tokenPrefixMatch("go greek", "go greek c"));
  assert.ok(!tokenPrefixMatch("bolt", "carbolton"));
  assert.ok(!tokenPrefixMatch("go greek", "greek go"));
  assert.ok(!tokenPrefixMatch("", "anything"));
});

Deno.test("a seeded merchant gets its category and remembers the rule", () => {
  const r = categorize(tx({ merchantNorm: "hungerstation llc" }), RULES, IDS);
  assert.equal(r?.categoryId, "c-dining");
  assert.equal(r?.ruleId, "seed-hungerstation");
});

Deno.test("unknown merchants stay uncategorised", () => {
  assert.equal(categorize(tx({ merchantNorm: "modawar mi" }), RULES, IDS), null);
  assert.equal(categorize(tx({ merchantNorm: null }), RULES, IDS), null);
});

Deno.test("type decides money movements, regardless of any merchant rule", () => {
  assert.equal(
    categorize(tx({ type: "fee", merchantNorm: "uber" }), RULES, IDS)?.categoryId,
    "c-fees",
  );
  assert.equal(categorize(tx({ type: "salary" }), RULES, IDS)?.categoryId, "c-income");
  assert.equal(categorize(tx({ type: "loan_installment" }), RULES, IDS)?.categoryId, "c-loans");
  assert.equal(categorize(tx({ type: "atm_withdrawal" }), RULES, IDS)?.categoryId, "c-other");
  assert.equal(
    categorize(tx({ type: "wallet_topup", merchantNorm: "barq" }), RULES, IDS)?.categoryId,
    "c-transfers",
  );
  assert.equal(
    categorize(tx({ isInternal: true, type: "transfer_out" }), RULES, IDS)?.categoryId,
    "c-transfers",
  );
  assert.equal(categorize(tx({ type: "transfer_in" }), RULES, IDS)?.categoryId, "c-transfers");
});

Deno.test("the horse payee account and the House Card are recognised", () => {
  assert.equal(
    categorize(tx({ type: "transfer_out", counterpartyLast4: "7892" }), RULES, IDS)?.categoryId,
    "c-horse",
  );
  assert.equal(
    categorize(tx({ merchantNorm: "hungerstation llc", cardLast4: "8920" }), RULES, IDS)
      ?.categoryId,
    "c-house",
  );
  assert.equal(
    categorize(tx({ merchantNorm: "hungerstation llc", cardLast4: "8119" }), RULES, IDS)
      ?.categoryId,
    "c-dining",
  );
});

Deno.test("an unknown transfer out to someone else stays uncategorised", () => {
  assert.equal(
    categorize(tx({ type: "transfer_out", counterpartyLast4: "1111" }), RULES, IDS),
    null,
  );
});

Deno.test("precedence: owner's rule beats seed, confirmed beats AI guess, exact beats contains, longer beats shorter", () => {
  const owner: Rule = {
    id: "u",
    pattern: "hungerstation llc",
    matchType: "exact",
    categoryId: "c-groc",
    status: "confirmed",
    source: "user",
  };
  assert.equal(
    categorize(tx({ merchantNorm: "hungerstation llc" }), [...RULES, owner], IDS)?.categoryId,
    "c-groc",
  );
  assert.equal(
    categorize(tx({ merchantNorm: "hungerstation llc" }), [owner, ...RULES], IDS)?.categoryId,
    "c-groc",
  );

  const ai: Rule = {
    id: "a",
    pattern: "extra ks1",
    matchType: "exact",
    categoryId: "c-fuel",
    status: "auto_unconfirmed",
    source: "ai",
  };
  assert.equal(
    categorize(tx({ merchantNorm: "extra ks1" }), [ai, ...RULES], IDS)?.categoryId,
    "c-shop",
    "seed (confirmed) beats an AI guess",
  );

  const long = seed("apple com bill", "c-subs");
  const short = seed("apple", "c-shop");
  assert.equal(
    categorize(tx({ merchantNorm: "apple com bill" }), [short, long], IDS)?.categoryId,
    "c-subs",
  );
});

Deno.test("if the category is missing for this user the transaction is left uncategorised, not mislabelled", () => {
  assert.equal(categorize(tx({ type: "fee" }), RULES, {}), null);
});
