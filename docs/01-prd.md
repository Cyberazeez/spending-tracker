# 01-prd: Personal spending tracker

Status: DRAFT for owner review. Nothing is built yet.

## Who it's for
One user (Azeez), Riyadh. iPhone (iOS 27), Windows laptop, no Mac. Single-user app: signups are disabled after the owner account exists. If it is ever opened to others, that is a new project phase (multi-user, Sign in with Apple), not v1.

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
- Fallbacks I must have: quick-add (manual), a share-sheet shortcut, a "possible gaps" view, CSV import.
- Done when: a real SMS from each supported bank (see Open items for Al Rajhi/SNB samples) lands as a correct transaction in under 10 s, and a replay of the same SMS creates nothing new.

### F2. Parsing
- Per-bank templates (regex/rules, Arabic and English) extract: amount, currency, merchant, card/account last-4, type, timestamp.
- Types: purchase, refund, ATM withdrawal, transfer out, transfer in, salary, bill payment, card payment (own), wallet top-up (own), loan installment, fee.
- Non-financial SMS (OTP, maintenance notices, marketing, card-added-to-wallet) are recorded as `ignored`; OTP bodies are not retained.
- Declined/rejected transactions are recorded as `ignored` with reason, not as spend.
- Foreign currency: keep original amount + currency + FX and store the SAR amount.
- Parsers are built test-first from real redacted fixtures in `supabase/tests/fixtures/<bank>/`. No invented formats.
- Fallback chain: rule parser, then Claude structured extraction (only if AI is on), then **Needs review** inbox.
- Done when: every fixture parses to its expected values and unknown formats land in Needs review.

### F3. Categorization
- `merchant_rules` (Arabic-aware normalized merchant, then category) first.
- Unknown merchants: batched to Claude (if AI on), result cached as a rule flagged "auto, unconfirmed".
- Correcting a category creates/updates a rule and offers to recategorize past matches.
- Seed categories (editable): Groceries, Dining, Fuel, Utilities, Rent/Housing, Horse (boarding, feed, farrier, vet, equipment), Transport, Shopping, Subscriptions, Health, Entertainment, Travel, Transfers, Fees, Income, Other. Plus House Card (wife's household spend, tag via card 8920).
- Transfers and own-account moves excluded from spend totals.
- With AI off, unknown merchants stay "Uncategorized" and show in a review list.

### F4. Transactions list
- Search (Arabic + English, diacritic/hamza insensitive), filter by category/bank/card/date/type, swipe to recategorize, tap for detail with the original SMS.
- Fees (e.g. the 0.58 SAR on local transfers) are their own category.

### F5. Obligations
- Fields: name, category, fixed or estimated amount, frequency (monthly/quarterly/annual/custom), due rule, reminder lead days, match hints (merchant/sender/counterparty account, amount tolerance), active flag.
- Seed obligations:
  | Name | Amount | Timing | Notes |
  |---|---|---|---|
  | Internet (STC, line 0138507356) | ~172.5, varies | paid ~2nd after card payoff | bill-issued SMS from 900 gives the amount |
  | Mobile (STC, line 0544520569) | ~278.93, varies | ~2nd | same |
  | Electricity | ~658.88, varies | ~2nd | no SMS found yet; manual until a sample exists |
  | Horse and foal housing | 1,800 fixed | day salary lands | transfer to account ending 7892 |
  | House Card top-up | 500 fixed | monthly | top-up of D360 8920 |
  | Alinma Murabahah installment | ~3,857.46 fixed | ~28th/29th until payoff | auto-deduction SMS |
  | Credit card statement (8119) | variable | statement date, due 25th | statement SMS gives total and minimum; settled ~2nd |
- Instances per period with expected vs actual amount and status pending/paid/overdue/skipped, linked transaction.
- Auto-match incoming transactions to open instances; ask to confirm when unsure; manual "mark paid" always available.
- Screens: upcoming 30 days with committed total, overdue, history. Month view of committed vs discretionary.
- Local notifications for due dates.

### F6. Insights and savings tips
- Deterministic first: spend by category and merchant, month-over-month, vs own 3-month average, spikes, recurring/subscription detection, savings rate (salary vs spend), salary-above-base flag.
- Weekly and on-demand Edge Function sends aggregated numbers only to Claude (if AI on) and caches tips in `insights` with the period they cover. Tips show their numbers. No generic advice.

### F7. Budgets
- Monthly limit per category, progress bars, warnings at 80% and 100%.
- Alerts: local notifications on sync/app open (v1). APNs push as a later milestone (needs paid Apple account).

### F8. Home screen widget
- Native WidgetKit (SwiftUI): month-to-date spend, top category, next 3 obligations. Fed via `home_widget` and an App Group. Needs the paid Apple account.

### F9. Security and lock
- Supabase email login, Face ID / Touch ID lock on launch and on return from background.
- RLS on every table, owner only. Service-role and Claude keys only in Edge Function secrets.

### F10. Data tools
- CSV import/export, manual backfill, possible-gaps view (days with no captured SMS per sender vs usual cadence).

## Cost control
- AI is an on/off switch in settings, default off until you flip it. Monthly cap 5 USD, enforced from an `ai_usage` ledger. At the cap, AI calls stop and the app degrades to rules-only.

## Out of scope
- Wallet/app-notification capture, email parsing, Open Banking, other users, Android polish (only must not crash), investment tracking, multi-currency budgets, tax/zakat.

## Known risks
1. Shortcuts "Message" automation may prompt for confirmation on some iOS versions. Tested on iOS 27.0.1 during milestone 2. Fallback: confirmation tap, share-sheet shortcut, CSV backfill.
2. No SMS means no capture (cash, some wallet-only spend). Quick-add covers it.
3. Date formats differ per bank (`dd-mm-yy`, `yyyy-mm-dd`, `dd/mm/yyyy`, and STC `M/D/YYYY` with `AM?`/`PM?` text). Parsers must pin the format per template.
4. Delivery gaps (phone off, automation disabled). Possible-gaps view.

## Open items
1. **Missing samples:** no Al Rajhi or SNB messages were in the screenshots I could see. I need 5 to 10 redacted per bank (purchase, refund, ATM, transfer, salary if it lands there).
2. Electricity bill: no SMS found. Need a sample if one exists.
3. Alinma salary SMS ("تم إيداع الراتب") appears to go to account 6000; confirm 6000 is the only salary account.
4. Own accounts to confirm in the app: 6000, 5911, 0513 (assumed yours), 5745 (cancelled).
