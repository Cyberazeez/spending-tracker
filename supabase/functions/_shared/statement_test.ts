import assert from "node:assert/strict";
import { merchantOf, parseStatementText, toImportRows } from "./statement.ts";

const DIR = new URL("../../tests/fixtures/statement/", import.meta.url);
const load = (n: string) => parseStatementText(Deno.readTextFileSync(new URL(`${n}.txt`, DIR)));

Deno.test("every statement fixture adds up to the bank's own totals", () => {
  let n = 0;
  for (const e of Deno.readDirSync(DIR)) {
    if (!e.name.endsWith(".txt")) continue;
    n++;
    const st = load(e.name.replace(".txt", ""));
    assert.ok(st.summary, `${e.name} has a summary`);
    assert.equal(st.checksum?.ok, true, `${e.name}: ${JSON.stringify(st.checksum)}`);
    assert.equal(st.cardLast4, "8119");
  }
  assert.ok(n >= 4);
});

Deno.test("merchant names: the city glued after ~~ is cut off", () => {
  assert.equal(merchantOf("WALAA COOPERATIVE INSURAN~~RIY"), "WALAA COOPERATIVE INSURAN");
  assert.equal(merchantOf("SAUDI AIRLINES  Riy~~adh"), "SAUDI AIRLINES Riy");
  assert.equal(merchantOf("OLDEN~~DHAHRAN~00000  68"), "OLDEN");
  assert.equal(merchantOf("CARD ACTIVATION FEE"), "CARD ACTIVATION FEE");
});

Deno.test("fees: the activation fee and its VAT import as fee rows", () => {
  const st = load("alinma_card_fees_and_purchases");
  assert.equal(st.statementDate, "2026-06-01");
  assert.equal(st.dueDate, "2026-06-25");
  const { rows } = toImportRows(st);
  const fees = rows.filter((r) => r.type === "fee");
  assert.deepEqual(fees.map((f) => [f.merchant, f.amountHalalas]), [
    ["CARD ACTIVATION FEE", 90000],
    ["VAT on Fees", 13500],
  ]);
  const walaa = rows.find((r) => r.merchant.startsWith("WALAA"))!;
  assert.equal(walaa.amountHalalas, 92066);
  assert.equal(walaa.date, "2026-05-19"); // the purchase date, not the posting date
  assert.equal(walaa.direction, "out");
});

Deno.test("payments into the card are internal and are not imported", () => {
  const st = load("alinma_card_foreign_and_payment");
  const { rows, skipped } = toImportRows(st);
  assert.equal(skipped.filter((s) => s.reason === "payment").length, 1);
  assert.ok(!rows.some((r) => /Account to Card/i.test(r.merchant)));
  assert.ok(rows.every((r) => r.direction === "out" && r.type !== "refund"));
});

Deno.test("a foreign purchase's extra VAT line becomes a fee, not a second purchase", () => {
  const { rows } = toImportRows(load("alinma_card_foreign_and_payment"));
  const crumbles = rows.filter((r) => /CRUMBLES|Foreign transaction fee/.test(r.merchant));
  assert.deepEqual(crumbles.map((r) => [r.type, r.amountHalalas]), [["purchase", 19339], [
    "fee",
    57,
  ]]);
});

Deno.test("refunds come in as incoming refund rows", () => {
  const { rows } = toImportRows(load("alinma_card_refunds"));
  const refunds = rows.filter((r) => r.type === "refund");
  assert.deepEqual(refunds.map((r) => [r.merchant, r.amountHalalas, r.direction]).sort(), [
    ["Ninja Food company", 6210, "in"],
    ["Noon Riy", 1390, "in"],
  ]);
});

Deno.test("a purchase moved to a payment plan is kept once at its full price", () => {
  const st = load("alinma_card_payment_plan");
  assert.equal(st.checksum?.ok, true);
  const { rows, skipped } = toImportRows(st);
  const autopia = rows.filter((r) => /AUTOPIA/.test(r.merchant));
  assert.deepEqual(autopia.map((r) => [r.type, r.amountHalalas, r.date]), [[
    "purchase",
    992100,
    "2026-09-27",
  ]]);
  assert.equal(skipped.filter((s) => s.reason === "payment_plan").length, 3);
  assert.equal(rows.length, 3); // Autopia, Cravia, MOI Bill
});

Deno.test("import refs are unique, stable and do not depend on row order within a day", () => {
  const st = load("alinma_card_fees_and_purchases");
  const a = toImportRows(st).rows.map((r) => r.ref);
  assert.equal(new Set(a).size, a.length);
  assert.deepEqual(toImportRows(load("alinma_card_fees_and_purchases")).rows.map((r) => r.ref), a);
  assert.ok(a.every((r) => r.startsWith("alinma:8119:")));
});

Deno.test("text that is not an Alinma card statement is rejected", () => {
  assert.throws(() => parseStatementText("hello world\n12/05/2026 something"));
});

Deno.test("a bad amount never becomes a row", () => {
  const st = parseStatementText(
    "Payment Due date   25/06/2026   Statement Date   01/06/2026\n  17/05/2026  17/05/2026  600000000001  SHOP~~RIY  0.00  1.0000  0.00  12.5x\n",
  );
  assert.equal(st.rows.length, 0);
});

Deno.test("top-ups to barq / D360 wallets are internal, not spending", () => {
  const st = parseStatementText(
    [
      "Payment Due date   25/06/2026   Statement Date   01/06/2026",
      "  18/05/2026  20/05/2026  601946423301  barq~~Riyadh  0.00  1.0000  0.00  400.00",
      "  18/05/2026  20/05/2026  601946423302  MYSR*D360~~Riy  0.00  1.0000  0.00  50.00",
      "  18/05/2026  20/05/2026  601946423303  BARQ CAFE~~Riy  0.00  1.0000  0.00  12.00",
    ].join("\n"),
  );
  const { rows } = toImportRows(st);
  assert.deepEqual(rows.map((r) => [r.merchant, r.type]), [
    ["barq", "wallet_topup"],
    ["MYSR*D360", "wallet_topup"],
    ["BARQ CAFE", "purchase"],
  ]);
});
