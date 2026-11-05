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
Status: built 2026-10-31 (not yet reviewed/merged). Confirmed by the owner 2026-10-31: STC bills are issued on the 27th and due the 2nd of the next month (paid after the card statement is settled, from a clean card balance); House Card top-up due day 2; the seeded bill amounts (172.50, 278.93) are the plan prices and rise only on overage, and each bill SMS sets the real amount. Electricity skipped for now; instances before today are not invented (the first month starts from the next due date). Everything is matched automatically (owner asked for max automation): horse (account 7892), loan deductions, and bills / House Card / statement by merchant words (STC, D360, Alinma) plus an amount within tolerance. A payment that fits the hint but not the amount is never matched; a suggestion banner only appears for obligations without `auto_merchant`. Wrong auto-matches can be re-opened from the row. Local notifications: the reminder schedule is planned and tested (`planReminders`), the iOS scheduling plugin comes with the first iOS build.
Scope: obligations and instances, seeds (internet, mobile, electricity, horse and foal, house card, Murabahah installment, card statement), generation per period, auto-match with confirm step, bill-issued SMS (900) and card-statement SMS creating instances, upcoming/overdue/history, committed vs discretionary, local notifications.
Tests: matching (amount tolerance, counterparty 7892, salary-day rule), overdue transitions, period generation across month ends, notification scheduling.
Done when: a full simulated month (statement on the 2nd, salary, horse transfer) ends with every instance paid and correct totals.

## M5. Insights and budgets
Status: built 2026-11-01. The Insights tab computes everything on the phone from the last four months of transactions (`features/insights/metrics.dart`): month spend and same-day comparison, by category, top merchants, 3-month averages and spikes (1.5x and at least 200 SAR over, needs history), subscriptions (same merchant charged once a month in 3 of the last 4 months, amounts within 10%), savings rate, salary above 14,100 flag. Budgets: set/remove per category, warning at 80%, over at 100%, shown as an alert strip. The AI tips function `insights-tips` is written and tested (aggregates only, category names must match the owner's own, tips must quote a number, cap + ledger) but **not deployed and off** (no API key). Reviewed by security and correctness agents; fixes applied (excluded categories honoured, history read in pages because the API caps rows at 1000, budgets can be created before any spend, averages divide by months with data). Known and left: subscriptions miss merchants with extra one-off charges or varying amounts (STC) and can list a cancelled one for a month; savings rate uses salary received so far in the month; spikes lag early in the month. Not done: the Home screen (still a placeholder), a "tips" card in the app, the weekly job, charts (bars only), local notifications for budgets (same iOS-build dependency as M4), subscription "cancel candidates" beyond listing them. Subscriptions and spikes need 3-4 months of history, so they stay empty at first.
Scope: deterministic metrics (category, merchant, MoM, 3-month average, spikes, subscriptions, savings rate, salary above 14,100 flag), `insights-weekly` with cache and optional Claude tips on aggregates only, budgets with 80/100% local alerts.
Tests: metric math on fixed datasets, subscription detection, budget thresholds, payload-contains-no-PII test for the Claude request.
Done when: weekly tips cite their numbers and no raw SMS, name or account number leaves Supabase.

## Statement import (added 2026-11-01, between M5 and M6)
Why: subscriptions and spikes need 3-4 months of history, and the SMS flow only started on 31 Oct. Alinma card statement PDFs (card 8119, five months May-Sep 2026) give that history.
- `_shared/statement.ts` reads the text of the PDF (`pdftotext -layout`). Real redacted fixtures are in `supabase/tests/fixtures/statement/`. Every statement is checked against the bank's own totals (purchases and payments must add up exactly); an import is refused if they do not.
- Card payoffs ("Account to Card Transfer") are internal and skipped. A purchase the bank moved to a payment plan appears as four cancelling lines; it is imported once at full price and the rest is dropped. A foreign purchase's VAT line becomes a fee. Top-ups to barq/D360 wallets are imported as internal wallet top-ups, so they are not spending.
- Dates only (no times): rows are stored at 12:00 Riyadh. Rows are tagged `source = 'csv'` with an `external_ref`, so importing a statement twice changes nothing. Imported rows never touch obligations.
- `import_statement_cli.ts` is the developer tool: it prints a dry-run summary and writes a rows file; it never touches the database. The rows go in through `import_statement_rows` (service role only).
- Overlap with SMS: pass `--before <first SMS date>` so only earlier rows are imported. Later statements (from November) overlap the SMS capture; for those the in-app import (after the iOS build, M7) has to match against existing transactions first.
- Categorisation uses the same rules as SMS (about 95 seed words). Unknown merchants stay uncategorised for the owner to tag.
- Card instalment plan (Autopia 9,921, 6 x 1,653.50 from the October statement): the instalment is already inside each statement's total due, so it is a note on the statement obligation ("includes instalment n of 6"), not a second payable (owner agreed 2026-11-01).
- Owner's category calls (2026-11-01): the car dealership (Mohamed Yousuf Naghi, SAR 50,406), Autopia, Almajdouie, Universal Motors and the insurers (Tawuniya, Walaa, United Insurance) are all **Car** spending.

Import done 2026-11-01: 464 rows from the five Alinma statements (17 May to 28 Sep 2026) are in `transactions` (`source = 'csv'`), net spend SAR 134,013, 53% categorised by rules (Car 72,305; Travel 17,679; Dining 6,794). Row counts and sums per category were checked against the dry run and match exactly.

## M6. Widget (needs paid Apple account)
Scope: App Group, WidgetKit extension in SwiftUI, `home_widget` data feed, Codemagic signing and first TestFlight build, optional APNs (push) for budget and due alerts.
Needs from owner: bundle IDs, App Group, team ID, App Store Connect API key (steps given when we reach it).
Done when: widget shows live numbers on the owner's phone from a TestFlight build.

**M6 done 2026-11-02:** small, medium and lock-screen widgets show real numbers on the owner's phone from a TestFlight build (PR #25, first Codemagic build).

Status 2026-11-02: Apple account, bundle ID `com.cyberazeez.spendingtracker`, App Store Connect app (Apple id 6829500984), Codemagic signing and TestFlight delivery are done; builds install on the owner's phone.
Remaining widget steps, in order:
1. App: one overall monthly budget setting (`settings.monthly_budget_halalas`, migration + a field in Insights) and a "spent today" figure. Tests first.
2. Owner, on the Apple developer site: register the App Group `group.com.cyberazeez.spendingtracker` and the widget App ID `com.cyberazeez.spendingtracker.widget`, and enable App Groups on both IDs.
3. Widget extension target in the iOS project (SwiftUI, small / medium / lock screen) and the `home_widget` data feed through the App Group. The project file is edited without Xcode, so the first Codemagic build is the real test.
4. `codemagic.yaml`: create and use signing files for both bundle IDs.
Done when the three widgets show real numbers on the owner's phone.

Widget build notes (2026-11-02): the extension is `app/ios/SpendingWidget` (bundle id `com.cyberazeez.spendingtracker.widget`, iOS 16+, App Group `group.com.cyberazeez.spendingtracker`). It was added to `Runner.xcodeproj` by `scripts/ios_add_widget_target.rb` (Ruby `xcodeproj`), because there is no Xcode here; the first Codemagic build is the first time it is compiled. The widget only shows what the app last saved (the app saves when opened, on pull-to-refresh and on returning to the app), so "spent today" is stale until the app runs; a figure from an earlier day shows `--`. A later step can let the widget fetch by itself with a read-only token.

## Roadmap after M6 (agreed with the owner 2026-11-02, in this order)
1. Home wording: say there is no data for last month yet instead of "Up SAR ..." when last month has none; record the roadmap here.
2. Alerts (phone-only, built 2026-11-02): local bill reminders (switch in More) and the monthly budget at 80% / 100% in Home alerts. Real push for budget alerts is deferred (needs an APNs key and a server function).
3. App-provided Shortcuts action (PRD F12), in three steps, each its own PR and TestFlight build:
   - 3a. Server: ingest tokens get a `kind`; `rotate-token` can create and revoke the `app` token. Local DB test and function tests.
   - 3b. App: provision the app token on sign-in into the Keychain, the `Add bank message` App Intent (Swift) that posts to `ingest`, an offline queue with retry, iOS minimum 16. Swift is compiled for the first time by the Codemagic build.
   - 3c. App: **Set up SMS capture** screen (More > SMS capture): steps, an Open Shortcuts button, queue status and last-send result. A one-tap shared shortcut is not possible (no Sender outside the automation, see PRD F12). The share-into-app fallback is not built.
4. Self-refreshing widget (built 2026-11-03): the widget fetches its own numbers with a read-only token (kind `widget`) from the `widget-summary` function, so "spent today" is fresh without opening the app. Order of deploy after merge: apply migration `20261103100000_widget_token_kind.sql`, deploy `rotate-token`, `ingest` (now filters token kinds) and the new `widget-summary` (verify_jwt off), then build the app.
5. ~~Apple Wallet capture (PRD F11)~~ **Dropped by the owner 2026-11-05**: SMS capture already covers every purchase and the Wallet trigger did not fire reliably for the owner's cards.

## UI redesign and later items (owner, 2026-11-03)
- Stage 1 (built): Home. Design layer in `app/lib/ui/tokens.dart`, widgets in `app/lib/features/home/widgets/`.
- Stages 2 to 5: Transactions, Insights (charts: trends, categories), Bills, More; then login, lock and the sub-screens (done 2026-11-04: login, lock, review, quick add, SMS capture restyled; Ingest token and Possible gaps screens removed; Account added). One PR each, owner tests on TestFlight in between.
- Add obligations by hand (a form to create bills and fixed payments).
- AI switch in More, suggest-categories button and AI tips card (built 2026-11-03; no server change: the functions `categorize-batch` and `insights-tips` were already deployed and the owner stored `ANTHROPIC_API_KEY`). Not built: a usage-vs-cap readout (`ai_usage` is not readable by the app; would need a small function).
- ~~Apple Wallet / Apple Pay capture~~ dropped 2026-11-05 (see roadmap item 5).
- **Order from 2026-11-03 (owner):** 1) add obligations by hand, 2) AI switch + suggest-categories + AI tips, 3) **family sign-up** (below), then the sub-screen restyle (Apple Wallet was dropped 2026-11-05).
- **Family sign-up (owner, 2026-11-03):** let relatives create their own accounts so the owner can share the app for testing. This turns the single-user app into a multi-user one: needs signups enabled in Supabase Auth (or invite-only), per-user seeding of categories, settings and accounts on first sign-in (today only the owner is seeded), checking every table and function for per-user isolation, an onboarding flow without the owner's seeded obligations/SMS formats, and TestFlight invites. Decided 2026-11-03: invite-only, email + password for the family test; open sign-up with Apple and Google SSO is a later phase for the public release. Design: `docs/superpowers/specs/2026-11-03-family-signup-design.md` (stages A to D).

- **Later (owner, 2026-11-04): AI quota per subscribed user.** AI becomes an optional paid feature (in-app purchase / subscription). Needs a quota calculator per subscriber: plan tiers with a monthly allowance, usage measured per user from `ai_usage` (already per user since stage A), the cost-to-allowance conversion, a usage readout in More > AI assistant, StoreKit products and receipt validation on the server, and the global ceiling (`AI_GLOBAL_CAP_HALALAS`) turned into a safety net. Until then: AI is free for testers within the per-user cap.
- **Family testing decision (owner, 2026-11-04):** this is a closed test, not a soft launch. Only people the owner invites on TestFlight have the app, so sign-up is **open without invite codes** (email + password, email confirmation off so testers can start at once). Invite codes (`docs/superpowers/specs/2026-11-04-signup-stage-b-design.md`) stay the design for the public release, together with Apple and Google sign-in.

## M7. Polish
Also: store the Supabase session in the iOS keychain (`flutter_secure_storage` as the auth `LocalStorage`) instead of the default SharedPreferences, add a "last message received" staleness warning, and mark the ingest token clipboard copy as local-only.

Dark mode pass, empty/error states audit, accessibility pass (Dynamic Type, VoiceOver), full Shortcuts setup guide with screenshots, CSV import/export hardening, README, `ship-review` and security audit on the whole repo.

## Standing rules
- Never commit raw SMS with real names or numbers; fixtures are redacted.
- Every milestone ends with a short list: what works, what was not tested, what I need from the owner.
- Update the docs when a decision changes.

## Obligations list changes (2026-11-02)
- Upcoming is split into one box per month ("This month · November", "Next month · December"). The summary box "Committed" was renamed **Obligations this month** (everything due this month, paid and unpaid).
- STC bills and the card statement now appear **before** their SMS arrives (migration `20261102120000`). Bills show the usual amount (due the 2nd of the month after the bill month); the card statement shows with no amount until the statement SMS arrives. The SMS later fills in the real amount and due date on the same instance.
- Electricity (SEC) is an obligation: issued on the 28th, amount varies (shown as "Usually SAR 658 to 726", 692 used for totals), 7 days of grace. The bill-notice parser waits for a real SMS template.
