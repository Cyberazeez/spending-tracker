# 06-implementation-plan

Same seven milestones as the brief. Riskiest first: the SMS path (Shortcuts, parsing) is what can sink the app, so a stub of it is proven in milestone 1. After each milestone: summary, wait for the owner's go. Small PR per milestone, conventional commits, `ship-review` before every PR.

## M1. Foundation and the riskiest assumption
Status: built 2026-10-30, waiting on the owner's Shortcuts test (README, Milestone 1 setup).
Scope
- Repo layout, CI (GitHub Actions), `codemagic.yaml` skeleton (not run).
- New Supabase project in "Cyberazeez's"; migrations for **all** tables in `05-backend-schema.md` with RLS; seed categories and own accounts; signups disabled; owner user created.
- Flutter app shell: Cupertino tabs, go_router, Riverpod, en/ar localization, login, Face ID lock, empty screens.
- **Stub `ingest`:** validates token, stores the raw message with status `needs_review`, returns 200. `rotate-token` function.
- Owner tests on iPhone (iOS 27.0.1): one Shortcuts automation (Message from `alinma`, Run Immediately) POSTing to the stub. We record whether it prompts and what the exact `sender` string is.
Tests: pgTAP RLS (a second test user cannot read or write anything), token hash/rotation unit tests, widget tests for lock and login.
Done when: the stub receives a real SMS with no tap, or we have chosen the fallback (confirm-tap, share-sheet shortcut).
Needs from owner: Supabase org confirmation, create owner user, run the Shortcuts test.

## M2. Ingest, parsers, Needs review, quick add
Status: built 2026-10-31 (67 real-format fixtures across all six senders, ingest parses and stores transactions, app has Transactions list, Needs review inbox, Quick add and Possible gaps). Known gaps carried to later milestones: a transfer *from* another own bank *into* Alinma 6000 is stored as external income (needs out/in pairing by amount and time, M4); the manual `merchant_norm` and manual income type are simpler than the server's (M3); foreign amounts assume 2 decimals (BHD has 3). Not done yet: CSV import (moved to M7), the `900` bill-notice parser (no exact sample captured yet), pairing the two sides of a wallet top-up (both sides are already flagged internal, so spend is not double counted).
Scope
- Parsers test-first from `docs/07-sms-catalog.md` fixtures, one per sender: alinma, barq, D360, STC Bank, SNB-AlAhli, AlRajhiBank, 900 (bill notices). Date resolver using `received_at` proximity. Ignore rules (OTP, declined, wallet events).
- Dedupe hash, rate limit, internal-transfer and top-up pairing (5 min window), own-account detection, fee split, foreign-currency handling.
- Needs review inbox, manual quick-add, share-sheet shortcut guide, possible-gaps view, CSV import (basic).
Tests: fixture per template (expected amount in halalas, type, merchant, last4, timestamp), replay idempotency, ambiguous-date cases, no-balance-stored assertion, OTP redaction.
Done when: every fixture passes, unknown formats land in Needs review, a real SMS from each sender appears correctly in the app.
Needs from owner: the Shortcuts test result from M1 (sender string, whether it prompts). ATM and other-bank salary fixtures are not needed (owner confirmed they are rare).

## M3. Categorization and transactions UI
Status: built 2026-10-31. Rules-first categorisation in `ingest` (migration `20261031130000_categorization.sql`), search/filter/recategorise-with-propagation in the app. The AI path (`_shared/ai.ts`, `categorize-batch`) is written and tested but **switched off and not deployed** (no API key yet). Not done: backfill of rows stored before M3 (one-off), a detail screen beyond the category picker (tap a row to change its category), re-check Anthropic pricing before enabling AI.
Scope
- Arabic-aware normalization (TS + Dart mirror), `merchant_rules`, seed rules for merchants seen in the samples (Jahez, HungerStation, Kudu, Noon, Amazon, Apple, YouTube Premium, AWS, Aldrees, Lulu...).
- AI categorization (batched, cached as `auto_unconfirmed`) behind the switch and cap; `ai_usage` ledger.
- Transactions list, search, filters, detail, recategorize-with-propagation, House Card tagging.
Tests: normalization fixtures (hamza/tashkeel/digits), rule precedence, cap enforcement, AI wrapper masks account numbers, names and balances.
Done when: seeded history from the owner's CSV or backfilled SMS categorizes at least 80% without AI and everything left is reviewable.

## M4. Obligations
Scope: obligations and instances, seeds (internet, mobile, electricity, horse and foal, house card, Murabahah installment, card statement), generation per period, auto-match with confirm step, bill-issued SMS (900) and card-statement SMS creating instances, upcoming/overdue/history, committed vs discretionary, local notifications.
Tests: matching (amount tolerance, counterparty 7892, salary-day rule), overdue transitions, period generation across month ends, notification scheduling.
Done when: a full simulated month (statement on the 2nd, salary, horse transfer) ends with every instance paid and correct totals.

## M5. Insights and budgets
Scope: deterministic metrics (category, merchant, MoM, 3-month average, spikes, subscriptions, savings rate, salary above 14,100 flag), `insights-weekly` with cache and optional Claude tips on aggregates only, budgets with 80/100% local alerts.
Tests: metric math on fixed datasets, subscription detection, budget thresholds, payload-contains-no-PII test for the Claude request.
Done when: weekly tips cite their numbers and no raw SMS, name or account number leaves Supabase.

## M6. Widget (needs paid Apple account)
Scope: App Group, WidgetKit extension in SwiftUI, `home_widget` data feed, Codemagic signing and first TestFlight build, optional APNs (push) for budget and due alerts.
Needs from owner: bundle IDs, App Group, team ID, App Store Connect API key (steps given when we reach it).
Done when: widget shows live numbers on the owner's phone from a TestFlight build.

## M7. Polish
Also: store the Supabase session in the iOS keychain (`flutter_secure_storage` as the auth `LocalStorage`) instead of the default SharedPreferences, add a "last message received" staleness warning, and mark the ingest token clipboard copy as local-only.

Dark mode pass, empty/error states audit, accessibility pass (Dynamic Type, VoiceOver), full Shortcuts setup guide with screenshots, CSV import/export hardening, README, `ship-review` and security audit on the whole repo.

## Standing rules
- Never commit raw SMS with real names or numbers; fixtures are redacted.
- Every milestone ends with a short list: what works, what was not tested, what I need from the owner.
- Update the docs when a decision changes.
