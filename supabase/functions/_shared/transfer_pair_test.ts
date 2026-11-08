import assert from "node:assert/strict";
import { accountsOfPair, pairsWith, type TransferCandidate } from "./enrich.ts";

const BANKS = ["alrajhi", "snb", "alinma", "barq", "d360", "stc"] as const;
const cand = (c: Partial<TransferCandidate>): TransferCandidate => ({
  id: "x",
  isInternal: false,
  type: "transfer_out",
  bank: "alrajhi",
  accountLast4: null,
  counterpartyLast4: null,
  ...c,
});
const me = (
  m: Partial<
    { type: string; bank: string; account_last4: string | null; counterparty_last4: string | null }
  >,
) => ({
  type: "transfer_in",
  bank: "snb",
  account_last4: null,
  counterparty_last4: null,
  ...m,
});

Deno.test("pairing: an out and an in at two banks pair, even with no digits at all", () => {
  assert.equal(pairsWith(me({}), cand({})), true);
});

Deno.test("pairing: two outs (or two ins) never pair", () => {
  assert.equal(pairsWith(me({ type: "transfer_out" }), cand({ type: "transfer_out" })), false);
});

Deno.test("pairing: matching digits pair, contradicting digits do not (either direction of the check)", () => {
  assert.equal(
    pairsWith(
      me({ account_last4: "2222", counterparty_last4: "1111" }),
      cand({ accountLast4: "1111", counterpartyLast4: "2222" }),
    ),
    true,
  );
  // the sender says it paid 9999, the receiver's own account is 2222
  assert.equal(
    pairsWith(me({ account_last4: "2222" }), cand({ counterpartyLast4: "9999" })),
    false,
  );
  // the receiver says it came from 8888, the sender's own account is 1111
  assert.equal(
    pairsWith(me({ counterparty_last4: "8888" }), cand({ accountLast4: "1111" })),
    false,
  );
});

Deno.test("pairing: the same bank needs two known, different accounts", () => {
  assert.equal(
    pairsWith(me({ bank: "alrajhi" }), cand({ bank: "alrajhi" })),
    false,
    "unknown digits: could be anything",
  );
  assert.equal(
    pairsWith(
      me({ bank: "alrajhi", account_last4: "2222" }),
      cand({ bank: "alrajhi", accountLast4: "1111" }),
    ),
    true,
  );
  assert.equal(
    pairsWith(
      me({ bank: "alrajhi", account_last4: "1111" }),
      cand({ bank: "alrajhi", accountLast4: "1111" }),
    ),
    false,
    "the same account cannot be both sides",
  );
});

Deno.test("accounts of a pair: sender at the sending bank, receiver at the receiving bank, digits from either SMS", () => {
  const incoming = me({ account_last4: "2222", counterparty_last4: "1111" });
  assert.deepEqual(
    accountsOfPair(incoming, cand({ accountLast4: "1111", counterpartyLast4: "2222" }), BANKS),
    [
      { bank: "alrajhi", last4: "1111" },
      { bank: "snb", last4: "2222" },
    ],
  );
  // the sender's SMS shows only where it went; the receiver's shows only its own account
  assert.deepEqual(
    accountsOfPair(me({ account_last4: "2222" }), cand({ counterpartyLast4: "2222" }), BANKS),
    [{ bank: "snb", last4: "2222" }],
  );
  // seen from the outgoing side
  assert.deepEqual(
    accountsOfPair(
      me({
        type: "transfer_out",
        bank: "alrajhi",
        account_last4: "1111",
        counterparty_last4: "2222",
      }),
      cand({ type: "transfer_in", bank: "snb" }),
      BANKS,
    ),
    [{ bank: "alrajhi", last4: "1111" }, { bank: "snb", last4: "2222" }],
  );
});

Deno.test("accounts of a pair: an unknown bank or a missing digit group is skipped, never invented", () => {
  assert.deepEqual(
    accountsOfPair(
      me({ bank: "other", account_last4: "2222" }),
      cand({ accountLast4: "1111" }),
      BANKS,
    ),
    [
      { bank: "alrajhi", last4: "1111" },
    ],
  );
  assert.deepEqual(accountsOfPair(me({}), cand({}), BANKS), []);
});
