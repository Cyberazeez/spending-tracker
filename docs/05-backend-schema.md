# 05-backend-schema

Status: DRAFT for owner review. Postgres on Supabase, migrations in `supabase/migrations/`.

## Conventions
- Money: `bigint` halalas (1 SAR = 100). Never floats.
- Times: `timestamptz` in UTC. SMS timestamps are Riyadh local time; parsers convert (UTC+3). UI renders in Asia/Riyadh, 24h.
- Every table has `user_id uuid not null references auth.users`, default `auth.uid()`, plus `created_at timestamptz default now()`.
- Text search columns store a normalized form: lowercase, Arabic diacritics (tashkeel) and tatweel removed, alef/hamza variants folded, Arabic-Indic digits to ASCII, punctuation collapsed.
- Signups are disabled in Supabase Auth after the owner account is created.

## Access model (RLS)
- RLS enabled on every table. Default policy: `user_id = auth.uid()` for select, insert, update, delete, unless noted.
- **Service-role only** (no client policy at all): `ingest_tokens.token_hash` column, `ai_usage`, `rate_limits`.
- Writes by Edge Functions run with the service role and set `user_id` explicitly.
- Client never receives: service-role key, Claude API key, token hash, any IBAN/full card number.

## Tables

### settings (1 row per user)
`user_id pk`, `base_salary_halalas bigint` (1,410,000), `salary_account_last4 text[]`, `ai_enabled bool default false`, `ai_monthly_cap_halalas bigint` (default 1,900 = about 5 USD, adjustable), `locale text` ('en'|'ar'), `week_start smallint default 0`, `timezone text default 'Asia/Riyadh'`.

### own_accounts
`id`, `user_id`, `bank text` (alrajhi, snb, alinma, barq, d360, stc), `last4 text`, `kind text` (account, debit_card, credit_card, wallet), `label text`, `is_active bool`, `is_house_card bool`.
Unique `(user_id, bank, last4)`. Seed: Al Rajhi 1271; Alinma 6000 (account), 6698, 8119 (credit); SNB 3301; D360 5911, 0513, 7705, 8920 (house card); barq 1224, 9105; STC 6190; D360 5745 inactive.

### ingest_tokens
`id`, `user_id`, `label`, `token_hash text` (SHA-256, service-role only), `created_at`, `last_used_at`, `revoked_at`. Created/rotated only by the `rotate-token` function, which returns the plaintext once.

### raw_messages
`id`, `user_id`, `sender text`, `body text`, `received_at timestamptz`, `dedupe_hash text`, `parse_status text` (parsed, ai_parsed, low_confidence, needs_review, ignored, failed), `ignore_reason text` (otp, marketing, declined, wallet_event, maintenance, ...), `parser text` (e.g. `alinma/v1`), `confidence real`, `transaction_id uuid null`, `created_at`.
- Unique `(user_id, dedupe_hash)` where hash = SHA-256 of sender + normalized body + 2-minute bucket of `received_at`.
- OTP/verification messages: body replaced with `[redacted]` before insert.
- Index `(user_id, sender, received_at desc)` for the gaps view.

### categories
`id`, `user_id`, `name`, `name_ar`, `kind text` (spend, income, transfer, fee), `excluded_from_spend bool`, `icon`, `color`, `sort_order`.

### merchant_rules
`id`, `user_id`, `pattern text` (normalized), `match_type text` (exact, contains, prefix), `category_id`, `status text` (confirmed, auto_unconfirmed), `source text` (user, ai, seed), `hit_count int`, `updated_at`. Unique `(user_id, pattern, match_type)`.

### transactions
`id`, `user_id`, `raw_message_id null`, `source text` (sms, manual, csv, ai), `bank text`, `account_last4 text`,
`direction text` (in, out), `type text` (purchase, refund, atm_withdrawal, transfer_out, transfer_in, salary, bill_payment, card_payment, wallet_topup, loan_installment, fee),
`amount_halalas bigint` (always positive, SAR), `orig_amount_minor bigint null`, `orig_currency text null`, `fx_rate numeric null`,
`merchant_raw text`, `merchant_norm text`, `counterparty_name text null`, `counterparty_last4 text null`,
`category_id`, `category_source text` (rule, ai, manual), `rule_id null`,
`is_internal bool` (both sides in own_accounts), `excluded_from_spend bool` (derived from internal flag or category),
`occurred_at timestamptz`, `note text`, `deleted_at null`.
- **No balances stored** (balance lines in SMS are dropped at parse time).
- Counterparty names are stored only as given in the SMS (already masked by banks). Names and account numbers are never sent to Claude.
- Indexes: `(user_id, occurred_at desc)`, `(user_id, category_id, occurred_at)`, trigram or `pg_trgm` on `merchant_norm`.

### obligations
`id`, `user_id`, `name`, `category_id`, `kind text` (bill, fixed, loan, card_statement), `amount_type text` (fixed, estimated), `expected_amount_halalas bigint null`, `frequency text` (monthly, quarterly, annual, custom), `due_rule jsonb` (e.g. `{"day":2}`, `{"after":"salary"}`, `{"day":28}`), `lead_days int`, `match jsonb` (sender, merchant pattern, counterparty last4, amount tolerance %), `active bool`.

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
