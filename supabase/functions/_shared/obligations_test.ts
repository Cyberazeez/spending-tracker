import assert from "node:assert/strict";
import {
  addDays,
  dueDateAfterSalary,
  dueDateFor,
  effectiveStatus,
  type Inst,
  instanceFromBill,
  instanceFromStatement,
  matchTransaction,
  type MatchTxn,
  monthStartOf,
  type Ob,
  obligationForBill,
  obligationForStatement,
  riyadhYmd,
} from "./obligations.ts";

const HORSE: Ob = {
  id: "horse",
  name: "Horse and foal",
  kind: "fixed",
  expectedHalalas: 180000,
  dueRule: { after: "salary", fallback_day: 28, grace: 3 },
  match: { types: ["transfer_out"], counterparty_last4: "7892", tolerance_pct: 0 },
};
const LOAN: Ob = {
  id: "loan",
  name: "Murabahah",
  kind: "loan",
  expectedHalalas: 385833,
  dueRule: { day: 28 },
  match: { types: ["loan_installment"], accumulate: true },
};
const NET: Ob = {
  id: "net",
  name: "Internet",
  kind: "bill",
  expectedHalalas: null,
  dueRule: { day: 2, next_month: true },
  match: { line: "7356", merchant: ["stc"], tolerance_pct: 1 },
};
const CARD: Ob = {
  id: "card",
  name: "Card 8119",
  kind: "card_statement",
  expectedHalalas: null,
  dueRule: { day: 25 },
  match: { card: "8119", counterparty_last4: "8119", merchant: ["alinma"], tolerance_pct: 1 },
};
const OBS = [HORSE, LOAN, NET, CARD];

function inst(o: Partial<Inst> & { obligationId: string }): Inst {
  return {
    id: "i-" + o.obligationId,
    periodStart: "2026-11-01",
    dueDate: "2026-11-28",
    expectedHalalas: 0,
    actualHalalas: null,
    status: "pending",
    transactionId: null,
    matchState: "none",
    createdAt: "2026-11-01T00:00:00Z",
    ...o,
  };
}
function tx(o: Partial<MatchTxn>): MatchTxn {
  return {
    id: "t1",
    type: "transfer_out",
    direction: "out",
    amountHalalas: 180000,
    counterpartyLast4: null,
    cardLast4: null,
    merchantNorm: null,
    occurredAt: "2026-11-29T10:00:00Z",
    ...o,
  };
}

Deno.test("riyadh dates: 22:00 UTC is already the next day in Riyadh", () => {
  assert.equal(riyadhYmd("2026-10-31T22:30:00Z"), "2026-11-01");
  assert.equal(monthStartOf("2026-10-31T22:30:00Z"), "2026-11-01");
  assert.equal(addDays("2026-02-27", 3), "2026-03-02");
});

Deno.test("due dates: month ends, next-month bills and year rollover", () => {
  assert.equal(dueDateFor({ day: 31 }, "2026-02-01"), "2026-02-28");
  assert.equal(dueDateFor({ day: 31 }, "2028-02-01"), "2028-02-29");
  assert.equal(dueDateFor({ day: 31 }, "2026-04-01"), "2026-04-30");
  assert.equal(dueDateFor(NET.dueRule, "2026-10-01"), "2026-11-02");
  assert.equal(dueDateFor(NET.dueRule, "2026-12-01"), "2027-01-02");
  assert.equal(dueDateFor(HORSE.dueRule, "2026-11-01"), "2026-11-28");
});

Deno.test("salary rule: due the day the salary landed, other rules are untouched", () => {
  assert.equal(
    dueDateAfterSalary(HORSE.dueRule, "2026-11-29T05:00:00Z", "2026-11-28"),
    "2026-11-29",
  );
  assert.equal(
    dueDateAfterSalary(LOAN.dueRule, "2026-11-29T05:00:00Z", "2026-11-28"),
    "2026-11-28",
  );
});

Deno.test("overdue: only after the due date plus grace; paid and skipped never change", () => {
  const i = { status: "pending" as const, dueDate: "2026-11-28" };
  assert.equal(effectiveStatus(i, { grace: 0 }, "2026-11-28"), "pending");
  assert.equal(effectiveStatus(i, { grace: 0 }, "2026-11-29"), "overdue");
  assert.equal(effectiveStatus(i, { grace: 3 }, "2026-12-01"), "pending");
  assert.equal(effectiveStatus(i, { grace: 3 }, "2026-12-02"), "overdue");
  assert.equal(effectiveStatus({ ...i, status: "paid" }, {}, "2027-01-01"), "paid");
  assert.equal(effectiveStatus({ ...i, status: "skipped" }, {}, "2027-01-01"), "skipped");
});

Deno.test("notices create instances: bill (due 2nd of next month) and statement (SMS due date)", () => {
  assert.equal(obligationForBill(OBS, "7356")?.id, "net");
  assert.equal(obligationForBill(OBS, "0569"), undefined);
  assert.equal(obligationForStatement(OBS, "8119")?.id, "card");
  assert.deepEqual(instanceFromBill(NET, 17250, "2026-10-31T07:00:00Z"), {
    periodStart: "2026-10-01",
    dueDate: "2026-11-02",
    expectedHalalas: 17250,
  });
  assert.deepEqual(instanceFromStatement(1673073, "2026-10-25", "2026-10-02T02:00:00Z"), {
    periodStart: "2026-10-01",
    dueDate: "2026-10-25",
    expectedHalalas: 1673073,
  });
});

Deno.test("match: transfer to 7892 for exactly 1,800 pays the horse instance automatically", () => {
  const r = matchTransaction(tx({ counterpartyLast4: "7892" }), [
    inst({ obligationId: "horse", expectedHalalas: 180000 }),
  ], OBS);
  assert.equal(r?.state, "auto");
  assert.equal(r?.status, "paid");
  assert.equal(r?.actualHalalas, 180000);
});

Deno.test("match: wrong amount, wrong payee, wrong direction or wrong type never match", () => {
  const i = [inst({ obligationId: "horse", expectedHalalas: 180000 })];
  assert.equal(
    matchTransaction(tx({ counterpartyLast4: "7892", amountHalalas: 180100 }), i, OBS),
    null,
  );
  assert.equal(matchTransaction(tx({ counterpartyLast4: "1111" }), i, OBS), null);
  assert.equal(matchTransaction(tx({ counterpartyLast4: "7892", direction: "in" }), i, OBS), null);
  assert.equal(matchTransaction(tx({ counterpartyLast4: "7892", type: "purchase" }), i, OBS), null);
});

Deno.test("match: the amount alone is never enough", () => {
  const i = [inst({ obligationId: "net", expectedHalalas: 17250 })];
  assert.equal(
    matchTransaction(
      tx({ type: "purchase", amountHalalas: 17250, merchantNorm: "some shop" }),
      i,
      OBS,
    ),
    null,
  );
});

Deno.test("match: a merchant hint plus amount within tolerance is only a suggestion", () => {
  const i = [inst({ obligationId: "net", expectedHalalas: 17250 })];
  const r = matchTransaction(
    tx({ type: "purchase", amountHalalas: 17250, merchantNorm: "stc pay" }),
    i,
    OBS,
  );
  assert.equal(r?.state, "suggested");
  assert.equal(r?.status, "pending");
  assert.equal(r?.transactionId, "t1");
  // 1% of 172.50 is 1.73 SAR: 1.00 off is fine, 3.00 off is not
  assert.ok(
    matchTransaction(tx({ type: "purchase", amountHalalas: 17350, merchantNorm: "stc" }), i, OBS),
  );
  assert.equal(
    matchTransaction(tx({ type: "purchase", amountHalalas: 17550, merchantNorm: "stc" }), i, OBS),
    null,
  );
});

Deno.test("match: an instance that already has a payment is not matched again", () => {
  const i = [
    inst({
      obligationId: "horse",
      expectedHalalas: 180000,
      transactionId: "old",
      matchState: "auto",
    }),
  ];
  assert.equal(matchTransaction(tx({ counterpartyLast4: "7892" }), i, OBS), null);
});

Deno.test("match: paid and skipped instances are left alone", () => {
  for (const status of ["paid", "skipped"] as const) {
    const i = [inst({ obligationId: "horse", expectedHalalas: 180000, status })];
    assert.equal(matchTransaction(tx({ counterpartyLast4: "7892" }), i, OBS), null);
  }
});

Deno.test("match: a payment from before the instance existed is ignored", () => {
  const i = [
    inst({ obligationId: "horse", expectedHalalas: 180000, createdAt: "2026-12-10T00:00:00Z" }),
  ];
  assert.equal(matchTransaction(tx({ counterpartyLast4: "7892" }), i, OBS), null);
});

Deno.test("loan: deductions add up, the month is paid only once covered", () => {
  const base = { obligationId: "loan", expectedHalalas: 385833 };
  const first = matchTransaction(tx({ type: "loan_installment", amountHalalas: 8700 }), [
    inst(base),
  ], OBS);
  assert.equal(first?.status, "pending");
  assert.equal(first?.actualHalalas, 8700);
  const second = matchTransaction(
    tx({ id: "t2", type: "loan_installment", amountHalalas: 377133 }),
    [inst({ ...base, actualHalalas: 8700, transactionId: "t1" })],
    OBS,
  );
  assert.equal(second?.status, "paid");
  assert.equal(second?.actualHalalas, 385833);
  assert.equal(second?.state, "auto");
});

Deno.test("loan: a deduction far above what is left does not match", () => {
  const r = matchTransaction(
    tx({ type: "loan_installment", amountHalalas: 900000 }),
    [inst({ obligationId: "loan", expectedHalalas: 385833 })],
    OBS,
  );
  assert.equal(r, null);
});

Deno.test("with two open months the closer amount, then the earlier due date wins", () => {
  const a = inst({
    id: "a",
    obligationId: "horse",
    expectedHalalas: 180000,
    dueDate: "2026-12-28",
    periodStart: "2026-12-01",
  });
  const b = inst({
    id: "b",
    obligationId: "horse",
    expectedHalalas: 180000,
    dueDate: "2026-11-28",
  });
  assert.equal(matchTransaction(tx({ counterpartyLast4: "7892" }), [a, b], OBS)?.instanceId, "b");
});

Deno.test("a suggestion does not block a later strong payment, but a weak guess never replaces a guess", () => {
  const sug = inst({
    obligationId: "card",
    expectedHalalas: 1673073,
    transactionId: "old",
    matchState: "suggested",
    actualHalalas: 1673073,
  });
  const strong = matchTransaction(
    tx({ id: "new", amountHalalas: 1673073, counterpartyLast4: "8119" }),
    [sug],
    OBS,
  );
  assert.equal(strong?.state, "auto");
  assert.equal(strong?.transactionId, "new");
  const weak = matchTransaction(tx({ id: "w", amountHalalas: 1673073, merchantNorm: "alinma" }), [
    sug,
  ], OBS);
  assert.equal(weak, null);
});

Deno.test("loan: the same deduction processed twice is not counted twice", () => {
  const i = inst({
    obligationId: "loan",
    expectedHalalas: 385833,
    actualHalalas: 8700,
    transactionId: "t1",
  });
  assert.equal(
    matchTransaction(tx({ id: "t1", type: "loan_installment", amountHalalas: 8700 }), [i], OBS),
    null,
  );
});

Deno.test("auto_merchant: merchant words plus the right amount mark a bill paid without asking", () => {
  const net: Ob = { ...NET, match: { ...NET.match, auto_merchant: true } };
  const i = [inst({ obligationId: "net", expectedHalalas: 17250 })];
  const r = matchTransaction(
    tx({ type: "purchase", amountHalalas: 17250, merchantNorm: "stc pay" }),
    i,
    [net],
  );
  assert.equal(r?.state, "auto");
  assert.equal(r?.status, "paid");
  // still needs both: the wrong amount, or no merchant words, never match
  assert.equal(
    matchTransaction(tx({ type: "purchase", amountHalalas: 20000, merchantNorm: "stc" }), i, [net]),
    null,
  );
  assert.equal(
    matchTransaction(tx({ type: "purchase", amountHalalas: 17250, merchantNorm: "lulu" }), i, [
      net,
    ]),
    null,
  );
});

Deno.test("auto_merchant: a bigger STC bill (overage) is not auto-paid by the usual amount", () => {
  const net: Ob = { ...NET, match: { ...NET.match, auto_merchant: true } };
  const i = [inst({ obligationId: "net", expectedHalalas: 25000 })];
  assert.equal(
    matchTransaction(tx({ type: "purchase", amountHalalas: 17250, merchantNorm: "stc" }), i, [net]),
    null,
  );
});
