# 03-app-flow

Bottom tab bar (Cupertino): **Home, Transactions, Obligations, Insights, More**. Large titles, swipe actions, sheets for editing, haptics on confirm/warn. All times 24h, Riyadh. Every list has loading (skeleton rows), empty and error (retry) states unless noted.

## 0. Launch and lock
- **Splash** then **Lock** (Face ID/Touch ID via `local_auth`). Success to last tab. Failure shows "Try again" and "Use passcode" (device passcode fallback). Re-lock after 30 s in background.
- **Login** (first run or signed out): email, password, "Sign in". Error: wrong credentials, no network. No sign-up link.
- **First-run setup** (once): choose language, confirm own accounts list, base salary, show the ingest token (once) with a link to the Shortcuts guide.

## 1. Home
- Month-to-date spend (SAR), vs same day last month, top category, budget alerts strip (80%/100%), next 3 obligations with due date and amount, "Needs review (n)" badge, "Possible gaps" badge.
- Tap spend to Transactions filtered to this month. Tap an obligation to its detail. Tap Needs review to the inbox.
- Empty (no data yet): "Waiting for your first SMS" with button to Setup guide and Quick add.
- Error: shows cached numbers with "Offline, last updated HH:mm".

## 2. Transactions
- List grouped by day (Riyadh), search bar (Arabic/English, normalized), filter sheet (date range, category, bank/card, type, uncategorized only, include internal). Swipe right: recategorize. Swipe left: delete (soft).
- **Detail:** amount, merchant, category chip (tap to change, then "Apply to N past transactions?"), card, source SMS (collapsed, with "Report parse issue"), linked obligation, note.
- **Quick add** (+): amount, merchant, category, date/time (default now), own account, note. Saves as `source = manual`. Also reachable from the share-sheet shortcut.
- Empty: "No transactions match". Error: retry.

## 3. Needs review inbox (under Transactions and Home badge)
- Rows: raw SMS preview, sender, time, reason (unparsed, low confidence, unknown sender format).
- Actions: Convert to transaction (prefilled form), Mark as not a transaction (creates an ignore reason), Re-run parser (after an update). Empty: "Nothing to review".

## 4. Obligations
- Segmented: **Upcoming** (next 30 days, total committed at top), **Overdue**, **History**.
- Row: name, due date, expected vs actual, status. Swipe: Mark paid / Skip.
- **Detail/edit** (sheet): amount type and value, frequency, due rule, lead days, match hints, active toggle, linked transactions.
- **Match prompt**: when a transaction probably matches an open instance, a banner on Home/Obligations offers "Mark X as paid with this payment? (Confirm / Not this)".
- Month view: committed vs discretionary bar.
- Add (+): from templates (bill, fixed, loan, card statement) or custom.
- Empty: "Add your first obligation" with seed suggestions.

## 5. Insights
- Cards: spend by category (donut), top merchants (bars), month-over-month, vs 3-month average, spikes, subscriptions detected (with monthly total and "cancel candidates"), savings rate (salary vs spend), salary above base flag.
- **Tips** (if AI on): each shows text plus the numbers behind it, period covered, "Refresh" (on demand). If AI is off: deterministic cards only, with "Turn on AI tips" link.
- Empty: "Need at least 2 weeks of data" with partial cards.

## 6. Budgets (from Insights and Categories)
- List of categories with monthly limit, progress bar (green under 80%, amber 80-99%, red 100%+), edit limit in a sheet. Local notification at 80% and 100%, evaluated on sync and app open.

## 7. More
- **Categories and rules:** edit categories, see rules (confirmed vs auto-unconfirmed), confirm or delete a rule.
- **Own accounts:** list with bank, last4, kind, active, house card.
- **Settings:** language (English/العربية), base salary, notifications (due dates, budgets), AI switch and monthly cap with spend so far this month, week start fixed to Sunday, theme (system).
- **Ingest token:** show status, last used, Rotate (confirm sheet shows new token once with copy button), Revoke.
- **Setup guide:** per sender Shortcuts steps with screenshots, "Test now" button that waits for a test SMS to arrive.
- **Possible gaps:** per sender, days since last captured SMS vs usual cadence, tap for a backfill form.
- **Data:** CSV import (map columns, preview, dedupe), CSV export, delete all data (double confirm).
- **Sign out.**

## 8. Notifications and deep links
- Due-date reminder (lead days) opens the obligation. Budget alert opens the category. Widget tap opens Home or Obligations. Weekly insight ready (later, push) opens Insights.

## 9. Widget (milestone 6)
- Small/medium: month-to-date spend, top category, next 3 obligations. Reads `home_widget` shared data; refreshes when the app syncs. Empty state: "Open the app to sync".
