# Transfer handling (final, owner decision 2026-11-08)

Supersedes the earlier "ask in Needs review" design. No questions, no Needs review for transfers.

## Rules
1. Every transfer is an expense (transfer out) or income (transfer in).
2. If one out and one in arrive with the same amount within 5 minutes, from different banks, or the same bank with two known different account digits, and their digits do not contradict, both become internal (excluded from spend and income). Both accounts and banks are saved to `own_accounts` (a last4 already saved is skipped).
3. Order does not matter: the first counts until the second arrives, then both flip.
4. A single SMS whose other side matches a saved own account is internal automatically.
5. Fees stay separate expenses. Wallet top-ups and own credit-card payments stay auto-internal.
6. More > Bank accounts (was Account > Bank accounts until 2026-11-13): add, edit, delete. Deleting never touches past transactions.

## Code
- `_shared/enrich.ts`: `pairsWith`, `accountsOfPair`.
- `ingest/handler.ts` + `index.ts`: `findTransferCounterparts`, `saveOwnAccounts`.
- `supabase/scripts/pair_existing_transfers.sql`: one-time backfill (preview first; production preview found 0 pairs).
