// Replays every real redacted fixture through the validator as if the model had read it perfectly. It proves the
// validator accepts what real Saudi bank SMS look like (Arabic digits, merchant text, dates) so only genuinely
// wrong readings are rejected. The live accuracy of the model itself is measured by scripts/eval_ai_parse.ts.
import assert from "node:assert/strict";
import { eligibleForAi, validateExtraction } from "./ai_parse.ts";

interface Fixture {
  sender: string;
  receivedAt: string;
  body: string;
  expected: {
    kind: string;
    type?: string;
    direction?: string;
    amountHalalas?: number;
    merchant?: string;
    cardLast4?: string;
    occurredAt?: string;
    origCurrency?: string;
  };
}

const ROOT = new URL("../../tests/fixtures/", import.meta.url);
const KINDS_OK = new Set([
  "purchase",
  "refund",
  "atm_withdrawal",
  "salary",
  "card_payment",
  "loan_installment",
  "bill_payment",
  "fee",
]);

Deno.test("every real transaction fixture that may go to the model validates when read correctly", () => {
  let checked = 0;
  for (const dir of Deno.readDirSync(ROOT)) {
    if (!dir.isDirectory || dir.name === "statement") continue;
    for (const f of Deno.readDirSync(new URL(`${dir.name}/`, ROOT))) {
      if (!f.name.endsWith(".json")) continue;
      const fx = JSON.parse(
        Deno.readTextFileSync(new URL(`${dir.name}/${f.name}`, ROOT)),
      ) as Fixture;
      const e = fx.expected;
      if (e.kind !== "transaction" || !e.type || !KINDS_OK.has(e.type)) continue;
      if (!eligibleForAi(fx.body).ok) continue; // transfers stay out by design
      if (e.origCurrency) {
        // Foreign-currency purchases need an exchange rate the SMS does not carry: phase 1 sends them to Needs review.
        const r = validateExtraction(
          { kind: e.type, amount: "0.58", currency: e.origCurrency, confidence: 0.95 },
          fx.body,
          new Date(fx.receivedAt),
        );
        assert.equal(r.kind, "rejected", `${dir.name}/${f.name}`);
        continue;
      }
      const perfect = {
        kind: e.type,
        amount: ((e.amountHalalas ?? 0) / 100).toFixed(2),
        currency: "SAR",
        merchant: null, // merchant is checked separately below
        occurred_at: null,
        card_last4: e.cardLast4 ?? null,
        confidence: 0.95,
      };
      const r = validateExtraction(perfect, fx.body, new Date(fx.receivedAt));
      assert.equal(r.kind, "transaction", `${dir.name}/${f.name}: ${JSON.stringify(r)}`);
      if (r.kind === "transaction") {
        assert.equal(r.txn.amountHalalas, e.amountHalalas, `${dir.name}/${f.name}`);
        if (e.direction) assert.equal(r.txn.direction, e.direction, `${dir.name}/${f.name}`);
      }
      checked++;
    }
  }
  assert.ok(checked >= 15, `only ${checked} fixtures replayed`);
});

Deno.test("merchants the parsers extracted are found in the original SMS text", () => {
  let checked = 0;
  for (const dir of Deno.readDirSync(ROOT)) {
    if (!dir.isDirectory || dir.name === "statement") continue;
    for (const f of Deno.readDirSync(new URL(`${dir.name}/`, ROOT))) {
      if (!f.name.endsWith(".json")) continue;
      const fx = JSON.parse(
        Deno.readTextFileSync(new URL(`${dir.name}/${f.name}`, ROOT)),
      ) as Fixture;
      const e = fx.expected;
      if (e.kind !== "transaction" || e.type !== "purchase" || !e.merchant || e.origCurrency) {
        continue;
      }
      const r = validateExtraction(
        {
          kind: "purchase",
          amount: ((e.amountHalalas ?? 0) / 100).toFixed(2),
          currency: "SAR",
          merchant: e.merchant,
          confidence: 0.95,
        },
        fx.body,
        new Date(fx.receivedAt),
      );
      assert.equal(r.kind, "transaction", `${dir.name}/${f.name}: ${JSON.stringify(r)}`);
      checked++;
    }
  }
  assert.ok(checked >= 10, `only ${checked} merchants checked`);
});
