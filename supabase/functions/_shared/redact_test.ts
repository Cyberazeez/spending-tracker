import assert from "node:assert/strict";
import { stripBalances } from "./redact.ts";

Deno.test("balance lines are removed in every bank's wording", () => {
  assert.equal(
    stripBalances("شراء POS\nبـ SAR 19.00\nفي 06:44 29-10-26\nالرصيد 1,302.52"),
    "شراء POS\nبـ SAR 19.00\nفي 06:44 29-10-26",
  );
  assert.equal(stripBalances("شراء\nرصيد 1,419.02\nx"), "شراء\nx");
  assert.equal(stripBalances("Online Purchase\nBalance 621.89\nAt X"), "Online Purchase\nAt X");
  assert.equal(stripBalances("POS Purchase\nBalance: 494.07\nAt: X"), "POS Purchase\nAt: X");
  assert.equal(stripBalances("Intl\nWallet balance: 65.49\nAt: X"), "Intl\nAt: X");
  assert.equal(
    stripBalances("Local\nAmount: SAR 1\nAvailable Balance: SAR 357.11"),
    "Local\nAmount: SAR 1",
  );
  assert.equal(stripBalances("رصيد SAR 5,563.53"), "");
});

Deno.test("messages without a balance are untouched, including 'insufficient balance'", () => {
  const m = "رصيد غير كافي\n2.22 ر.س\nAWS EMEA\n06/02/26 07:01";
  assert.equal(stripBalances(m), m);
  assert.equal(stripBalances("Money Added\namount: 1.0 SAR"), "Money Added\namount: 1.0 SAR");
});
