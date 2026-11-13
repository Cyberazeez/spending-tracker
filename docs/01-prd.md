# 01-prd: Personal spending tracker

Status: APPROVED by owner (2026-10-30). Nothing is built yet.

## Who it's for
One user (Azeez), Riyadh. iPhone (iOS 27), Windows laptop, no Mac. Built for one user; since 2026-11-04 it is a multi-user **closed test**: family testers invited on TestFlight create their own accounts in the app (open sign-up, email + password, no confirmation). Public release later (invite codes, Sign in with Apple and Google).

## Problem
Spending is spread over six banks and wallets. Azeez pays one credit card (Alinma 8119) for almost everything, settles it around the 2nd of each month, then pays the monthly bills. He wants every purchase captured automatically from bank SMS, a clear view of where money goes, a tracker for regular obligations, and budgets that warn before overspending.

## Fixed constants
| | |
|---|---|
| Currency | SAR, stored as integer halalas |
| Timezone | Asia/Riyadh (UTC+3, no DST) |
| Week | starts Sunday (work week Sun to Thu) |
| Time | 24-hour everywhere, never AM/PM |
| Languages | English and Arabic UI with an in-app toggle. Layout is RTL-safe. Merchant names and SMS are often Arabic or mixed |
| Salary | expected net deposit 14,100 SAR. Anything above it in a month is flagged as an anomaly (bonus/overtime) |

## Core concepts
- **Own accounts** (user-maintained list of account/card/wallet last-4s): any transfer where both sides are own accounts is an *internal transfer*, excluded from spend and income. Includes wallet top-ups (Apple Pay into D360/barq/STC from own cards) and credit card payoffs.
- **Credit card**: spend counts at swipe time on the card. The monthly payoff is an internal transfer, never spend again.
- **Obligation**: a regular bill or payment due on a schedule. **Instance**: one occurrence for one period.

## Features (user stories + acceptance criteria)

### F1. Capture purchases from SMS
As the owner, every bank SMS I receive reaches the app without my touching it.
- iOS Shortcuts personal automation (trigger "Message", one per sender ID, Run Immediately) POSTs `{sender, body, received_at}` to the `ingest` Edge Function with my ingest token in a header.
- Supported senders: Al Rajhi, SNB, Alinma, barq, D360, STC Bank/STC Pay. Sender "900" (STC telecom bills) is also supported as a bill-notice source.
- Every message is stored raw with a parse status. Nothing is silently dropped.
- Duplicate deliveries do not create duplicate transactions.
- Token: shown once, only its hash stored, rotatable, endpoint rate-limited.
- Fallbacks I must have: quick-add (manual), a share-sheet shortcut, CSV import. (The possible-gaps screen was removed 2026-11-04; Home still warns when no message arrived for 3 days.)
- Done when: a real SMS from each supported bank (see Open items for Al Rajhi/SNB samples) lands as a correct transaction in under 10 s, and a replay of the same SMS creates nothing new.

### F2. Parsing
- Per-bank templates (regex/rules, Arabic and English) extract: amount, currency, merchant, card/account last-4, type, timestamp.
- Types: purchase, refund, ATM withdrawal, transfer out, transfer in, salary, bill payment, card payment (own), wallet top-up (own), loan installment, fee.
- Non-financial SMS (OTP, maintenance notices, marketing, card-added-to-wallet) are recorded as `ignored`; OTP bodies are not retained.
- Declined/rejected transactions are recorded as `ignored` with reason, not as spend.
- Foreign currency: keep original amount + currency + FX and store the SAR amount.
- Parsers are built test-first from real redacted fixtures in `supabase/tests/fixtures/<bank>/`. No invented formats.
- Fallback chain: rule parser, then Claude structured extraction (only if AI is on), then **Needs review** inbox. The extraction step for unknown banks is designed in `docs/superpowers/specs/2026-11-05-ai-sms-parsing-design.md` (paid accounts only).
- Done when: every fixture parses to its expected values and unknown formats land in Needs review.

### F3. Categorization
- `merchant_rules` (Arabic-aware normalized merchant, then category) first.
- Unknown merchants: batched to Claude (if AI on), result cached as a rule flagged "auto, unconfirmed". Planned: merchants other users already categorised are applied automatically for paying accounts (`docs/superpowers/specs/2026-11-05-shared-merchant-categories-design.md`).
- Correcting a category creates/updates a rule and offers to recategorize past matches.
- Seed categories (editable): Groceries, Dining, Fuel, Utilities, Rent/Housing, Horse (boarding, feed, farrier, vet, equipment), Transport, Shopping, Subscriptions, Health, Entertainment, Travel, Transfers, Fees, Income, Other. Plus House Card (wife's household spend, tag via card 8920).
- Own-account moves (detected automatically: wallet top-ups, card payoffs, matched transfer pairs, transfers to a saved own account) are excluded from spend totals. Money sent to other people counts as spending, also when filed under Transfers (owner decision 2026-11-13).
- With AI off, unknown merchants stay "Uncategorized" and show in a review list.

### F4. Transactions list
- Search (Arabic + English, diacritic/hamza insensitive), filter by category/bank/card/date/type, swipe to recategorize, tap for detail with the original SMS.
- Fees (e.g. the 0.58 SAR on local transfers) are their own category.

### F5. Obligations
- Fields: name, category, fixed or estimated amount, frequency (monthly/quarterly/annual/custom), due rule, reminder lead days, match hints (merchant/sender/counterparty account, amount tolerance), active flag.
- **Add by hand (built 2026-11-03):** Bills > "+" opens a form (name, type bill/fixed/loan, fixed or estimated amount, monthly / every 3 months / yearly, due day, first due month, grace days, reminder days, category, match words, amount tolerance, auto-mark-paid). A row's action sheet has **Edit details** and **Stop tracking** (history stays). A bill may have no amount (its bill SMS sets it). **Owner decision 2026-11-12:** card statements are no longer tracked on Bills (not seeded, no tile, old rows hidden); a month whose amount was changed by hand keeps it when the bill's settings are saved again.
- Seed obligations:
  | Name | Amount | Timing | Notes |
  |---|---|---|---|
  | Internet (STC, line 0138507356) | ~172.5, varies | paid ~2nd after card payoff | bill-issued SMS from 900 gives the amount |
  | Mobile (STC, line 0544520569) | ~278.93, varies | ~2nd | same |
  | Electricity | ~658.88, varies | ~2nd | no SMS found yet; manual until a sample exists |
  | Horse and foal housing | 1,800 fixed | day salary lands | transfer to account ending 7892 |
  | House Card top-up | 500 fixed | monthly | top-up of D360 8920 |
  | Alinma Murabahah installment | ~3,858.33 fixed | ~28th/29th until payoff | auto-deduction SMS |
  | ~~Credit card statement (8119)~~ | variable | statement date, due 25th | dropped from Bills 2026-11-12 (owner); the payment stays an internal transfer |
- Instances per period with expected vs actual amount and status pending/paid/overdue/skipped, linked transaction.
- Auto-match incoming transactions to open instances; ask to confirm when unsure; manual "mark paid" always available.
- Screens: upcoming 30 days with committed total, overdue, history. Month view of committed vs discretionary.
- Local notifications for due dates.

### F6. Insights and savings tips
- Deterministic first: spend by category and merchant, month-over-month, vs own 3-month average, spikes, recurring/subscription detection, savings rate (salary vs spend), salary-above-base flag.
- Weekly and on-demand Edge Function sends aggregated numbers only to Claude (if AI on) and caches tips in `insights` with the period they cover. Tips show their numbers. No generic advice.

### F7. Budgets
- Monthly limit per category, progress bars, warnings at 80% and 100%.
- Alerts, decided with the owner 2026-11-02 (phone-only first):
  - **Bill reminders:** local notifications scheduled on the phone at 09:00 Riyadh time, `lead_days` (2) before each unpaid due date; they fire even when the app is closed. Off by default; switching on in More > Bill reminders asks iOS for permission. They are rebuilt every time the obligations refresh or the app returns to the foreground, so one already paid (seen by the app) is removed; a payment the app has not yet seen can still produce a reminder.
  - **Budget alerts** (80% and 100%, category budgets and the monthly budget) are shown in the app (Home > Alerts). A notification at the moment of a purchase needs real push (APNs) and a server function; deliberately deferred.

### F8. Home screen widget
- Native WidgetKit (SwiftUI), fed via `home_widget` and an App Group. Decided with the owner 2026-11-02:
  - **Small:** spent today (Riyadh day; internal moves excluded).
  - **Medium:** spent this month and the percentage of the monthly budget.
  - **Lock screen:** the monthly budget percentage.
- **Monthly budget:** one overall spending limit for the month, set by the owner in the app (new setting `monthly_budget_halalas`). The widget percentage is month spend divided by it. Category budgets (F7) are unchanged and keep driving the alerts. With no monthly budget set, the widget shows the spend and "Set a monthly budget".
- **Self-refreshing (roadmap item 4, built 2026-11-03):** the app gives the widget extension its own **read-only token** (kind `widget`, created by the app on sign-in, stored in the shared App Group, revoked and wiped on sign-out). Each time iOS refreshes the widget (we ask for 15 minutes; iOS allows a few dozen a day) it calls the `widget-summary` Edge Function and gets three numbers: spent today, spent this month, monthly budget (Riyadh time, same spend rule as the app's month total). The token cannot post messages (`ingest` accepts only kinds `shortcut` and `app`) and cannot read anything else. Offline or no token: the widget shows what the app last saved. A day-old `--` only happens when both fail. Limit 300 calls per day per user.
- Later (after the widget): an app-provided Shortcuts action ("Add bank message") so users do not put a token in their own shortcut. See `docs/06-implementation-plan.md`.

### F9. Security and lock
- Supabase email login, Face ID / Touch ID lock on launch and on return from background.
- RLS on every table, owner only. Service-role and Claude keys only in Edge Function secrets.

### F10. Data tools
- CSV import/export, manual backfill, possible-gaps view (days with no captured SMS per sender vs usual cadence).

### F11. Apple Wallet capture (DROPPED by the owner 2026-11-05; kept for the record)
- **Not planned.** SMS capture already covers every purchase; the Shortcuts Wallet trigger adds steps and did not fire for the owner's Barq top-up. Do not build it unless the owner asks again.
- iOS cannot read other apps' notifications, so the route is the Shortcuts **"Transaction"** automation (iOS 17+): it fires when a card in Wallet is used and passes the merchant, amount and card name. The automation sends them to the same ingest function as SMS, as a new source `wallet`.
- Each purchase can arrive twice (the wallet event and the bank SMS). They are matched on amount, merchant and time (a few minutes) and stored once; the SMS stays the source of truth when both exist, the wallet event fills the gap when the SMS never comes.
- Needs: a real sample of what the automation passes (merchant, amount, currency, card name) before any parser is written; fixtures follow the same privacy rules as SMS.
- Open question: whether the Transaction trigger covers all of the owner's cards (mada, credit) or only some.

### F12. App-provided Shortcuts action (roadmap item 3, designed 2026-11-02)
Goal: the Shortcut carries no secret and no web request. Public users should not have to paste a token or build a request.
- The app provides an iOS **App Intent**, "Add bank message" (parameters: Sender, Message), which appears in the Shortcuts app under Spending Tracker. The automation is only: *When I get a message from <bank>* -> *Add bank message* (Sender = the message's sender, Message = its content). Apple does not allow sharing automations, so each user still creates one automation per bank; the in-app **Set up SMS capture** screen walks through it step by step and opens Shortcuts.
- The intent runs inside the app's process without opening the app and sends the message to the same `ingest` function as today (same parsing, same dedupe, same rate limits). Server address, request format and the token live in the app, so changing them is an app update, not a rewrite of every user's shortcut.
- **App token:** a second ingest token of kind `app`, created by the app on sign-in and kept only in the iOS Keychain (never shown, never typed, never in a shortcut). The `shortcut` kind still works on the server, but the app no longer has a screen to create it (removed 2026-11-04); changing the password replaces the app and widget tokens. Signing out revokes the app token.
- **Offline:** if the request fails (no connection, server error), the message is kept on the phone and retried the next time the intent runs and whenever the app comes to the foreground. Retrying is safe because `ingest` dedupes.
- iOS 16+ (App Intents); the app's minimum moves from 15 to 16 (the widget already needs 16).
- **Why no one-tap install (checked 2026-11-03):** a shared shortcut gets plain text or a file as Shortcut Input, with no Sender, and the "Type" list has no Message type, so it cannot know which bank sent the SMS. The automation is the only place with Sender, and Apple does not share automations ([Apple Shortcuts guide, iOS 26](https://support.apple.com/en-ca/guide/shortcuts/apd690170742/9.0/ios/26)). Describe-a-shortcut (Apple Intelligence) was tried and is slow and device-dependent. So the in-app screen (More > SMS capture) gives the steps, an Open Shortcuts button, queue status and last-send result.
- Not in this item: reading messages without a Shortcut (iOS does not allow it), Apple Wallet capture (dropped 2026-11-05).

## Cost control
- AI is an on/off switch in settings, default off until you flip it. Monthly cap 5 USD, enforced from an `ai_usage` ledger. At the cap, AI calls stop and the app degrades to rules-only.

## Out of scope
- Reading other apps' notifications (iOS does not allow it), email parsing, Open Banking, other users, Android polish (only must not crash), investment tracking, multi-currency budgets, tax/zakat.

## Known risks
1. Shortcuts "Message" automation may prompt for confirmation on some iOS versions. Tested on iOS 27.0.1 during milestone 2. Fallback: confirmation tap, share-sheet shortcut, CSV backfill.
2. No SMS means no capture (cash, some wallet-only spend). Quick-add covers it.
3. Date formats differ per bank (`dd-mm-yy`, `yyyy-mm-dd`, `dd/mm/yyyy`, and STC `M/D/YYYY` with `AM?`/`PM?` text). Parsers must pin the format per template.
4. Delivery gaps (phone off, automation disabled). Possible-gaps view.

## Open items
1. Samples received for all six senders plus 900. Catalog in `docs/07-sms-catalog.md`. Still missing: ATM withdrawal, and a salary SMS from banks other than Alinma.
2. Electricity bill: no SMS found. Need a sample if one exists.
3. Alinma salary SMS ("تم إيداع الراتب") appears to go to account 6000; confirm 6000 is the only salary account.
4. Incoming transfers from family/others (SNB 6905 and 9000, Al Rajhi 5247 and 3384): decided by the owner, excluded from income and the savings rate. Stored as `transfer_in`, shown separately.
5. Alinma loan: one new loan; a month's installment can arrive as several deductions, which the obligation instance sums (see `docs/07-sms-catalog.md`).
6. ATM withdrawals and salary from other banks: owner says they are rare or absent, so no fixtures are needed.

### AI in the app (built 2026-11-03)
- **More > AI assistant** switch (`settings.ai_enabled`, off by default). The server refuses AI calls while it is off.
- **Suggest with AI** card on Transactions (when AI is on and uncategorised rows exist): calls `categorize-batch`; only merchant names go to Claude; results become unconfirmed rules the user can correct.
- **AI tips** card on Insights (when AI is on): the app sends only month totals and the user's category names to `insights-tips` and shows up to 5 tips; the last answer for the month is kept in `insights`.
- Cap 5 USD/month (global), reasons shown in plain words: off, no key, cap reached, no connection, failed.
