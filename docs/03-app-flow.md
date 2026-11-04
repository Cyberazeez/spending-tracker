# 03-app-flow

Bottom tab bar (Cupertino): **Home, Transactions, Obligations, Insights, More**. Large titles, swipe actions, sheets for editing, haptics on confirm/warn. All times 24h, Riyadh. Every list has loading (skeleton rows), empty and error (retry) states unless noted.

## 0. Launch and lock
- **Splash** then **Lock** (Face ID/Touch ID via `local_auth`). Success to last tab. Failure shows "Try again" and "Use passcode" (device passcode fallback). Re-lock after 30 s in background.
- **Login** (first run or signed out): email, password, "Sign in". Error: wrong credentials, no network. A **Create account** link opens the sign-up screen (name, email, password twice; 8 characters minimum): errors for taken email, weak password, sign-up closed, no network; if the project asks for email confirmation the screen says to check the email. Swipe back returns to login.
- **First-run setup** (once): choose language, confirm own accounts list, base salary, open More > SMS capture for the Shortcuts steps (the app provisions its own token).

## 1. Home
- Month-to-date spend (SAR), vs same day last month, top category, budget alerts strip (80%/100%), next 3 obligations with due date and amount, "Needs review (n)" badge, "no messages for N days" alert (opens SMS capture).
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
- **Account** (2026-11-04): **Bank accounts** (own accounts, cards and wallets by bank + last 4 digits, so transfers between them are not counted as spending; tap a row to remove), Profile (name, email; an email change is confirmed by a link sent to the new address), Security (change password: current one is checked first; afterwards this phone's capture and widget tokens are replaced and reconnect by themselves), Privacy (a short note and **Delete my account**: warning, type DELETE, password again, then the account is marked for deletion; see the grace period below). **Removed:** the Ingest token screen (the app issues its own token; hand-built shortcuts are no longer supported from the app) and the Possible gaps screen (Home's "no messages for N days" alert now opens SMS capture).
- **Setup guide:** per sender Shortcuts steps with screenshots, "Test now" button that waits for a test SMS to arrive.
- **Data:** CSV import (map columns, preview, dedupe), CSV export, delete all data (double confirm).
- **Sign out.**

## 8. Notifications and deep links
- Due-date reminder (lead days) opens the obligation. Budget alert opens the category. Widget tap opens Home or Obligations. Weekly insight ready (later, push) opens Insights.

## 9. Widget (milestone 6)
- Small/medium: month-to-date spend, top category, next 3 obligations. Reads `home_widget` shared data; refreshes when the app syncs. Empty state: "Open the app to sync".

- **Navigation (2026-11-04):** every sub-screen is an iOS page: swipe from the left edge (right edge in Arabic) or the back button returns, one level at a time.

- **Welcome card on Home** (2026-11-04, stage C): for accounts that have not finished the first three steps: add bank accounts, set up SMS capture (done once a message was received), set a monthly budget. Shows "n of 3 done", each step opens its screen, **Hide** is remembered per account on the phone, and the card disappears by itself when all three are done.

- **Polish (2026-11-04, after the first family test):** tabs are **Home, Activity, Bills, Insights, More** (Activity was Transactions, Bills was Obligations). Quick add (+) lives only in Activity. The login fields are one autofill group so a password manager fills email and password together. While Face ID is asked at start the app shows its skeleton with the logo instead of a blank page. The welcome card folds into one line with Hide (tap to open again) and removes itself 3 days after it was first shown if still unfinished. Delete my account asks "Are you sure?" (all data lost, cannot be restored) after the form.

- **Account deletion grace period (2026-11-04):** Delete my account does not delete at once. After the warning, DELETE, password and "Are you sure?", the server marks the account (`account_deletions`), revokes SMS capture and widget tokens and ends all sessions; the phone is wiped and the app returns to login. A daily database job (pg_cron `purge-deleted-accounts`, 01:17 UTC) deletes accounts still marked after 30 days (every table cascades). Signing in again within 30 days cancels it: the app calls `reactivate_my_account()` after sign-in and shows "Welcome back, your account is active again and the deletion is cancelled". No email for now (add it with an email provider before public release).

- **Category picker (2026-11-04):** one bottom sheet for the transaction, bill and budget category pickers: search (English or Arabic name), "suggested for this merchant" (what the same merchant was filed under before, transactions only), categories as icon tiles grouped like Home, the current one ringed with a check, and a fixed Remove (transactions) / None (bills) button. The Activity filter sheet keeps its list.
