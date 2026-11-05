# 05-backend-schema

Status: APPROVED by owner (2026-10-30). Postgres on Supabase, migrations in `supabase/migrations/`.

## Conventions
- Money: `bigint` halalas (1 SAR = 100). Never floats.
- Times: `timestamptz` in UTC. SMS timestamps are Riyadh local time; parsers convert (UTC+3). UI renders in Asia/Riyadh, 24h.
- Every table has `user_id uuid not null references auth.users`, default `auth.uid()`, plus `created_at timestamptz default now()`.
- Text search columns store a normalized form: lowercase, Arabic diacritics (tashkeel) and tatweel removed, alef/hamza variants folded, Arabic-Indic digits to ASCII, punctuation collapsed.
- Sign-up is open for the closed family test (2026-11-04): `enable_signup = true`, email confirmation off. The person's name is stored in the auth user's `user_metadata.name` (display only, never used for authorization). Risk accepted for the test: anyone who extracts the anon key could register directly; the AI ceiling (`AI_GLOBAL_CAP_HALALAS`) limits the cost.

## Access model (RLS)
- RLS enabled on every table. Default policy: `user_id = auth.uid()` for select, insert, update, delete, unless noted.
- **Service-role only** (no client policy at all): `ingest_tokens.token_hash` column, `ai_usage`, `rate_limits`.
- **`settings`**: the client can read it and update preferences only (`ai_enabled`, `locale`, `week_start`, `timezone`, `base_salary_halalas`, `salary_account_last4`, `monthly_budget_halalas`). `ai_monthly_cap_halalas` is not client-writable, and rows cannot be inserted or deleted by the client.
- **Tokens**: at most one active token per user **per kind** (`shortcut`: made by `scripts/get-ingest-token.ps1` for a hand-built shortcut, the app has no screen for it any more and a password change does not revoke it (rotate it with the script); `app`: created by the app and kept in the iOS Keychain; `widget`: read-only, for the home-screen widget, kept in the shared App Group, accepted only by `widget-summary`, never by `ingest`), partial unique index on `(user_id, kind)`. `rotate_ingest_token(user, hash, label, kind)` revokes that kind's token and inserts the new one in one transaction and is service-role only. The `rotate-token` function takes `kind` (default `shortcut`) and an `action` of `rotate` (default) or `revoke`.
- **Rate limits**: `ingest` allows 60 requests per minute and 500 per day per user (`bump_rate_limit(user, bucket, window)`), and purges windows older than 2 days.
- Writes by Edge Functions run with the service role and set `user_id` explicitly.
- Client never receives: service-role key, Claude API key, token hash, any IBAN/full card number.

## Tables

### settings (1 row per user)
`user_id pk`, `base_salary_halalas bigint` (1,410,000), `salary_account_last4 text[]`, `ai_enabled bool default false`, `ai_monthly_cap_halalas bigint` (default 1,900 = about 5 USD, adjustable), `locale text` ('en'|'ar'), `week_start smallint default 0`, `timezone text default 'Asia/Riyadh'`, `monthly_budget_halalas bigint null` (one overall monthly spending limit; null = not set; client-writable, must be positive).

### own_accounts
`id`, `user_id`, `bank text` (alrajhi, snb, alinma, barq, d360, stc), `last4 text`, `kind text` (account, debit_card, credit_card, wallet), `label text`, `is_active bool`, `is_house_card bool`.
Unique `(user_id, bank, last4)`. Seed: Al Rajhi 6331 (account), 1271 (mada card); SNB 0102, 0103 (accounts), 3301 (mada card); Alinma 6000 (account), 6698, 8119 (credit); D360 5911, 0513 (accounts), 7705, 8920 (house card); barq 1224, 9105; STC 6190; D360 5745 inactive. Evidence: SNB "between your accounts" SMS and Al Rajhi/SNB transfers to Alinma 6000 under the owner's name.

### ingest_tokens
`id`, `user_id`, `label`, `kind text` (`shortcut` | `app` | `widget`, default `shortcut`), `token_hash text` (SHA-256, service-role only), `created_at`, `last_used_at`, `revoked_at`. Created/rotated only by the `rotate-token` function, which returns the plaintext once.

### raw_messages
`id`, `user_id`, `sender text`, `body text`, `received_at timestamptz`, `dedupe_hash text`, `parse_status text` (parsed, ai_parsed, low_confidence, needs_review, ignored, failed), `ignore_reason text` (otp, marketing, declined, wallet_event, maintenance, ...), `parser text` (e.g. `alinma/v1`), `confidence real`, `transaction_id uuid null`, `created_at`.
- Unique `(user_id, dedupe_hash)` where hash = SHA-256 of sender + normalized body + 2-minute bucket of `received_at`.
- OTP/verification messages: body replaced with `[redacted]` before insert, and the dedupe hash is computed from the redacted body so a code cannot be recovered from it.
- Bodies are stored in full (they are the only way to re-run a parser), so balances, names and IBANs exist in `raw_messages` even though `transactions` never stores balances. A retention or scrub policy for parsed bodies is decided in milestone 2.
- Dedupe is best effort: a Shortcut retry that crosses a 2-minute bucket can store a message twice, and two truly identical messages in one bucket collapse to one. The parser/transaction layer is the real reconciler (same account, amount, merchant and `occurred_at`).
- Index `(user_id, sender, received_at desc)` for the gaps view.

### categories
`id`, `user_id`, `name`, `name_ar`, `kind text` (spend, income, transfer, fee). 19 seeded per user, including Loans (M3) and Car (2026-11-01: car purchase, service and insurance), `excluded_from_spend bool`, `icon`, `color`, `sort_order`.

### merchant_rules
`id`, `user_id`, `pattern text` (normalized), `match_type text` (exact, contains, prefix), `category_id`, `status text` (confirmed, auto_unconfirmed), `source text` (user, ai, seed), `hit_count int`, `updated_at`. Unique `(user_id, pattern, match_type)`.
- Pattern is `normalizeMerchant()` output (TS `_shared/normalize.ts`, Dart mirror `app/lib/core/normalize.dart`). Special patterns: `acct:<last4>` and `card:<last4>` match the transaction's account or card instead of the merchant text.
- Precedence in `categorize()`: internal -> Transfers; type map (fee->Fees, salary->Income, wallet_topup->Transfers, loan_installment->Loans, atm_withdrawal->Other); then rules ranked user > confirmed seed > ai-unconfirmed, account/card over text, exact > prefix > contains, then longer pattern. `contains` means a whole-word prefix match. Unmatched incoming transfers -> Transfers; anything else stays uncategorised (reviewable in the app).
- Seeded per user by `seed_merchant_rules(user)` (about 60 rules, e.g. `acct:7892` -> Horse, `card:8920` -> House Card).
- A manual recategorisation upserts an exact `confirmed/user` rule; the app can also update past transactions with that merchant (never ones set manually).
- AI rules (`source ai`, `auto_unconfirmed`) are written only by `categorize-batch`, which is off by default (settings switch + monthly cap, no key deployed).

### transactions
`id`, `user_id`, `raw_message_id null`, `source text` (sms, manual, csv, ai), `bank text`, `account_last4 text`,
`direction text` (in, out), `type text` (purchase, refund, atm_withdrawal, transfer_out, transfer_in, salary, bill_payment, card_payment, wallet_topup, loan_installment, fee),
`amount_halalas bigint` (always positive, SAR), `orig_amount_minor bigint null`, `orig_currency text null`, `fx_rate numeric null`,
`merchant_raw text`, `merchant_norm text`, `card_last4 text null`, `counterparty_name text null`, `counterparty_last4 text null`,
`category_id`, `category_source text` (rule, ai, manual), `rule_id null`,
`is_internal bool` (both sides in own_accounts), `excluded_from_spend bool` (derived from internal flag or category),
`occurred_at timestamptz`, `note text`, `deleted_at null`.
- **No balances stored** (balance lines in SMS are dropped at parse time).
- Counterparty names are stored only as given in the SMS (already masked by banks). Names and account numbers are never sent to Claude.
- Indexes: `(user_id, occurred_at desc)`, `(user_id, category_id, occurred_at)`, trigram or `pg_trgm` on `merchant_norm`.

### obligations
`id`, `user_id`, `name`, `category_id`, `kind text` (bill, fixed, loan, card_statement), `amount_type text` (fixed, estimated), `expected_amount_halalas bigint null`, `frequency text` (monthly, quarterly, annual, custom), `due_rule jsonb` (e.g. `{"day":2}`, `{"after":"salary"}`, `{"day":28}`), `lead_days int`, `match jsonb` (sender, merchant pattern, counterparty last4, amount tolerance %), `active bool`.

- Seeded by `seed_owner_extras(user)` for the owner only (no trigger calls it; since 2026-11-04 a new sign-up gets no obligations): `seed_obligations(user)`: Internet (STC 7356, ~172.50, bill), Mobile (STC 0569, ~278.93, bill), Horse and foal (1,800, due the day the salary lands, fallback 28th, 3 days grace, paid by a transfer to account 7892), House Card top-up (500, day 2, transfer or top-up to 8920), Murabahah installment (3,858.33, day 28, several deductions add up), Credit card 8119 statement (amount from the statement SMS, due date from the SMS). Electricity is not seeded (no SMS yet). Amounts for the two bills are only a starting guess: each bill SMS sets that month's real amount.
- `due_rule`: `{"day":2,"next_month":true,"grace":3}` or `{"after":"salary","fallback_day":28,"grace":3}`. `match`: `types`, `counterparty_last4`/`card` (strong hint, auto-pays), `merchant` words (weak hint, only suggests unless `auto_merchant` is true, which the seeds set: merchant words plus an amount within tolerance then mark it paid by themselves), `tolerance_pct`, `accumulate` (loan), `line` (phone line of a bill SMS).
- The card statement obligation's `match.plan` records the Autopia payment plan (9,921 SAR, 6 x 1,653.50 from the October 2026 statement). Each instalment is already inside that statement's total due, so it is shown as a note ("includes instalment n of 6"), not as a second payable.
- Added by hand (migration `20261103140000_manual_obligations.sql`): the app calls `save_my_obligation(p_id, p jsonb)` (create when `p_id` is null, otherwise edit; kinds bill/fixed/loan only; validates name 1-60, amount 1 to 100,000,000 SAR (a bill may have none), day 1-31, grace 0-14, lead 0-14, start month for quarterly/yearly, up to 5 match words of 30 letters, tolerance 0-50, own category only; on edit the open untouched instances are rebuilt) and `stop_my_obligation(p_id)` (`active=false`, open untouched instances removed, history kept). Both run with the caller's rights (RLS). CHECK constraints on `obligations` repeat the limits for direct writes. `due_rule.start_month` (1-12) anchors quarterly (every 3 months) and annual schedules.
- `refresh_obligation_instances(user)` (service role) / `refresh_my_obligations()` (the app, signed-in user only) create this and next month's instances for fixed and loan obligations while they are not yet past due + grace days and mark pending ones overdue after due date + grace. Bill and statement instances are created by `ingest` from the SMS.

### obligation_instances
`id`, `user_id`, `obligation_id`, `period_start date`, `due_date date`, `expected_amount_halalas`, `actual_amount_halalas null`, `status text` (pending, paid, overdue, skipped), `paid_at null`, `transaction_id null`, `source_raw_message_id null` (bill-issued or statement SMS that created it), `match_state text` (auto, suggested, manual, none). Unique `(obligation_id, period_start)`.

### budgets
`id`, `user_id`, `category_id`, `monthly_limit_halalas bigint`, unique `(user_id, category_id)`. Month boundaries are Riyadh calendar months.

### insights
`id`, `user_id`, `period_start date`, `period_end date`, `kind text` (weekly, on_demand), `metrics jsonb` (deterministic numbers), `tips jsonb` (each tip carries its numbers), `model text null`, `created_at`. Unique `(user_id, kind, period_start)` for weekly.

### ai_usage (service-role only)
`id`, `user_id`, `day date`, `purpose text` (parse, categorize, insights), `input_tokens`, `output_tokens`, `cost_halalas bigint`. Cap check: sum for the Riyadh month must be under `settings.ai_monthly_cap_halalas`, else the call is skipped.

### rate_limits (service-role only)
`user_id`, `bucket text`, `window_start timestamptz`, `count int`. Used by `ingest` (e.g. 60 requests/min per token).

### device_tokens (later, APNs stretch)
`id`, `user_id`, `apns_token`, `environment` (sandbox/prod), `created_at`.

## Edge Functions
| Function | Auth | Does |
|---|---|---|
| `ingest` | ingest token header (hash compare), no JWT | rate limit, dedupe, store raw, parse, categorize, match obligations, return minimal ack |
| `rotate-token` | user JWT | create or rotate ingest token, return plaintext once |
| `categorize-batch` | user JWT or service | AI merchant categorization (if enabled) |
| `insights-weekly` | cron + user JWT on demand | build metrics, optional AI tips, cache |
| `apns-send` (later) | service | budget/obligation pushes |

## What is never sent to Claude
Account numbers, IBANs, personal names, balances, full SMS bodies for insights. Parsing fallback sends the SMS with those fields masked; categorization sends merchant string only; insights send aggregates only.

## Sign-up seeds and AI budget (family sign-up stage A, 2026-11-04)
- A new auth user is seeded by `seed_defaults` only: `settings` (AI off, base salary 0 = not set, no salary account), 17 generic categories (no Horse, no House Card) and the generic merchant rules. **No** `own_accounts`, **no** obligations, no household rules (`acct:7892`, `card:8920`).
- The owner's extras (Horse and House Card categories, 17 own accounts, household rules, the seven obligations) are `seed_owner_extras(user)`, service role only, called by no trigger. Existing rows are unchanged.
- AI budget: each user is measured against their own `ai_monthly_cap_halalas`; one ceiling over all users (`AI_GLOBAL_CAP_HALALAS` function secret, default 1,875 halalas = 5 USD (owner decision 2026-11-04, was 5,700 / about 15 USD)) makes every user `cap_reached` once reached. See `supabase/functions/_shared/ai_budget.ts`. Spend is summed in the database by `ai_spend_summary(user, since)` (service role only), not by selecting rows.

## Account deletion (stage C, 2026-11-04)
- Edge function `delete-account` (JWT required): body `{password}`. The account to delete is the token's user, never taken from the body. The password is checked again server side (a throwaway sign-in), at most 5 tries a day per user (`bump_rate_limit`, bucket `delete_account`), then `auth.admin.deleteUser`. Every user table references `auth.users` with `on delete cascade`, so all rows go, **except** the AI spend ledger: `ai_usage.user_id` is `on delete set null` (migration `20261104110000`), so deleting an account cannot reset the shared AI budget. `supabase/tests/db/rls_test.sql` checks that no other public table keeps a row of a deleted user and that the AI total does not drop. A 401 from the function means the account is already gone (a lost answer), and the phone is cleaned up as on success. Response: `{ok:true}` only.

- Edge function `ai-chat` (JWT required, migration `20261104130000` adds purpose `chat`): body `{aggregates, messages[{role,content}], language}`. Aggregates go through `sanitizeAggregates`; messages through `sanitizeMessages` (max 12 turns, starts and ends with the user, 500 characters per user turn, emails/URLs/8+ digit runs removed). Same cap checks as `insights-tips` plus `bump_rate_limit` bucket `ai_chat` (100/day). Response `{ok:true, reply}` or `{ok:false, reason}`. Nothing is stored except the `ai_usage` row.

## Ship-review fixes (2026-11-05)
- `ingest`: a bill or statement SMS now creates its obligation instance **before** the raw row is marked `parsed`. A failure leaves the row `needs_review` and the call fails, so the app's retry runs it again (the upsert is safe to repeat). Transaction matching stays best effort.
- `categorize-batch`: only category names of at most 40 characters, at most 50 of them, go into the prompt; a failed transaction update after the AI rule was saved deletes that rule so the merchant is asked about again.
- OTP detection: `one-time` now needs word boundaries ("phone time" is a purchase, not an OTP).
- Migration `20261105130000_record_bill_issue_days.sql`: records `issue_day` 27 (STC mobile, internet) and 6 (Electricity) for bills that lack it. Production already had them.
- Review items accepted for now (closed family test): `reactivate_my_account` has no server-side recent-sign-in check (an attacker holding a live JWT already has full access); widget token in App Group UserDefaults; ingest tokens never expire; no per-IP limit on token lookups; AI cost is check-then-record; transfer pairing ignores account numbers (only matters on a same-amount coincidence within 5 minutes); sender-gap view reads the newest 500 messages; month spend reads at most 1000 rows. Open decision: default AI cap for new accounts and open sign-up.
