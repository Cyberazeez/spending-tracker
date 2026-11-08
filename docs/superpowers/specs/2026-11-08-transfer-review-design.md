# Transfers: ask once in Needs review, learn the user's own accounts

Status: DESIGN for the owner's approval (2026-11-08). Part 1 (welcome card) is already built. Nothing below is built yet.
Owner's request: remove the "add bank details" onboarding step; detect internal vs external transfers through Needs review; manage accounts in Account > Bank accounts; fix the bank list from SAMA.

## 1. Onboarding (built)
The welcome card has two steps (SMS capture, monthly budget). No bank-account step.

## 2. Transfers in Needs review
### What changes for a captured transfer (transfer_in / transfer_out only)
`ingest` decides one of three outcomes when it saves the row:
1. **Auto internal** (as today, plus the stricter rule below): the row is saved `is_internal = true`, left out of spend and income, and the user is never asked.
2. **Ask**: the row is saved as an ordinary transaction with `transfer_check = 'pending'` and appears in Needs review under "Transfers to check".
3. Not a transfer (purchase, salary, bill, wallet top-up, card payment): unchanged. Wallet top-ups and own-card payments stay auto internal.

**Auto-internal rule.** The SMS shows up to two last-4 values: the account side (`accountLast4`, the account it left or entered) and the other side (`counterpartyLast4`). A transfer is auto internal when the other side matches one of the user's saved accounts and the account side either matches too or is not shown in the SMS. Matching is by last 4 digits (the bank is used only when both sides know it), because SMS from one bank usually do not name the other bank. Transfers the SMS itself calls "between your accounts" (SNB) stay auto internal.

**Until answered, a pending transfer counts like an external one** (money out is spend, money in is income), which is what the app does today for unmatched transfers. Answering Internal removes it from the totals.

### The question
A row in "Transfers to check" shows direction, amount, the other side's name and last 4 if known, and the date. Tapping it opens a sheet: "Is this transfer internal (between your own accounts) or external?" with **Internal** and **External**.
- **External**: `transfer_check = 'external'`; it stays an ordinary expense or income. Nothing else changes.
- **Internal**: one database function, `answer_transfer_check(txn_id, internal)`, does everything atomically:
  - saves the last 4 of both sides as the user's own accounts, skipping any last 4 that is already saved (any bank);
  - sets `is_internal = true`, `excluded_from_spend = true`, `transfer_check = 'internal'` and files it under Transfers;
  - finds the other bank's message of the same move (opposite direction, same amount, another bank, within 5 minutes, same user) and marks it internal too, so the move is never counted twice (this also clears its own pending question).
- If the SMS shows only one side's last 4, only that one is saved; the answer is never blocked.
- **The bank of a saved account.** The side the SMS belongs to gets that SMS's bank. The other side's bank is not in the SMS, so it is saved as "Other bank" until the other bank's own message arrives (it then fills in the real bank) or the user edits it in Bank accounts.

From then on, the second SMS of an internal move (or any later transfer between saved accounts) is auto internal by the rule above, so the user is not asked again. If the second SMS arrives while the first is still unanswered, both show up; answering one clears the other.

Old transfers already in the database are not asked about (no flood of questions): only transfers captured after this ships get `transfer_check`.

### Data
- `transactions.transfer_check text null check (transfer_check in ('pending','internal','external'))`. Null for non-transfers, auto-internal rows and old rows.
- `own_accounts.bank` accepts `other` (and the approved SAMA list, section 4); `last4` stays unique per bank.
- `answer_transfer_check(p_txn uuid, p_internal boolean)`: security invoker (RLS keeps it to the caller's rows), validates the row is a transfer owned by the caller.
- The Needs review count (badge on Activity and Home) includes pending transfers.

## 3. Account > Bank accounts
- Add, **edit** (bank, last 4, kind, label) and delete. Today only add and delete exist.
- Accounts saved from Needs review appear here with their bank (or "Other bank", to edit).
- Deleting an account deletes no transaction: transactions keep their own copy of the last 4, and rows already marked internal stay internal. Future transfers involving that last 4 will be asked about again.
- A duplicate (same bank and last 4, or the same last 4 under "Other bank") is explained, not blocked silently.

## 4. Bank list from SAMA
- Source: https://www.sama.gov.sa/ar-sa/Supervision/LicenseEntities/pages/licensedbanks.aspx, official Arabic and English names as shown, digital banks included if SAMA lists them.
- **Not done yet.** The session's network blocked the site; access was requested for `www.sama.gov.sa` and the page then returned an empty reply to automated requests. The list is not filled in from memory. Options: the owner pastes the list (or a screenshot of the page), or the page is fetched once access works.
- The full list will be shown to the owner for approval before anything is added to the app. Adding banks needs a database change too: `own_accounts.bank` has a CHECK limited to six banks today, and the parsers' `Bank` type is separate (a bank only needs a parser if its SMS are read).

## 5. Tests
Deno: auto-internal rule (both sides, one side, none), pending flag, merge with the counterpart. SQL (local database test): `answer_transfer_check` internal/external, skipping existing accounts, counterpart merge, another user's row refused. Flutter: Needs review section, the question sheet, Bank accounts add/edit/delete, welcome card.

## 6. Rollout
Migration, then `ingest` deploy (owner's go), then an app build. Until the build, new transfers carry `transfer_check = 'pending'` that the old app does not show (they count as before, nothing is lost).
