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

- **AI tips card and chat (2026-11-04):** on Insights the AI tips are a hero-style gradient card (same look as Home). Tapping the card or "Ask a question" opens **Ask about your spending**: a chat about this month's totals, a category or a budget, with a few suggested questions. The assistant only sees the same totals as the tips (`ai-chat` function, same sanitised aggregates; typed text has emails, links and long digit runs removed). The conversation is kept on that screen only and is not saved. Spend counts against the same per-user and global AI caps (`ai_usage.purpose = chat`), plus 100 questions a day per user.

- **Fixes after the second test (2026-11-04):** amounts sit at the end of their row (a shared `TrailingBox`, not a half-width `Flexible`); the riyal font no longer maps A–D (those letters were vanishing: "ills", "ctivity", "ue"); row arrows follow the language direction (`ForwardChevron`); **Monthly budget** is a row in More (shows the amount or "Not set"; tap to set, change or remove) and the welcome card's budget step opens the amount prompt directly, so a new account with no transactions can set it; the AI tips follow the app language (saved tips are picked by language, and written again when none exist in the new one); the chat answers in the app language and drops the keyboard when you leave it.

- **Sheets (2026-11-04):** the monthly and category budget amount is asked in a bottom sheet (big field with the riyal sign, quick amounts, Save) instead of a native alert, and the language picker and the set/remove budget choices use the same sheet look (`showChoiceSheet`, `showAmountSheet`, `SheetFrame`). The stray box next to dates in Arabic was the invisible direction marks; the bundled font now has empty glyphs for them. The Activity filter, review a message, bank account pickers, bill actions and the first-due-month picker use the same sheet; no native action sheets are left.

- **Uncategorised count and AI (2026-11-04):** the "n transactions have no category" banner counts all history on the server (`uncategorizedSpendCount`), not just the latest 200 loaded in the list, so it matches the "No category" filter. The AI suggestion now also handles merchants with terminal numbers in the name ("KFIA 1831", "NMC7751"): it sends only the masked name (digit runs removed, at least 3 letters left) and saves the rule on the full name; merchants with fewer than 3 letters left stay for manual categorising.

- **Confirmations and notices (2026-11-04):** every native alert is now a bottom sheet too: yes/no questions (remove a bank account, stop a bill, delete my account, apply a category to past ones) use `showConfirmSheet`, messages (could not save, password changed, welcome back, reminders blocked) use `showNoticeSheet`, bill amount edits use the amount sheet, and the manual-entry date and time picker sits in the same frame. No native alerts or action sheets are left.

- **Ship review (2026-11-04):** three independent reviewers (security, trust boundaries, correctness), a challenger and a re-review of the fixes. No critical issues; row-level security and token handling held up. Fixed: ingest retries a message whose first parse failed (500 once, then 200), the 30-day purge keeps accounts that signed in again and deletes each account on its own, asking to delete twice restarts the clock, the app cancels a pending deletion only right after a fresh sign-in, more rate limits (AI tips 30/day, categorise 20/day, token rotation 30/day, no tokens for an account waiting to be deleted), an outgoing transfer is internal when the incoming one is, negative totals keep their minus sign, budget percent is never below 0, excluded categories are not subscriptions, history pages have a stable order. Accepted for the closed test (listed in PR #53): sign-up abuse of the AI budget, no email confirmation, no row quotas, dedupe of two identical SMS in the same 2 minutes, loan part-payment race.

- **Password change (2026-11-04):** the app sends the current password with the new one (`current_password`), so Supabase can check it on the server once "Require current password when updating" is switched on in the dashboard (Authentication > Sign In / Providers > Email). Turn that on only after a build with this change is installed.

- **Bills by cycle (2026-11-04):** a bill belongs to its **issue** month when its issue day is known (`due_rule.issue_day`; issued 1-19 = this month, 20+ = next month; STC 27, SEC 6), otherwise to the month it is due (owner correction 2026-11-04: the STC bills due 2 Dec are December's, the ones paid on 2 Nov are November's), so the November cycle holds the bills due in November. The Upcoming tab shows the current cycle (open items first, paid ones last, due date on each row), a card with what is still to pay and what is paid so far, and next month folded into one line you tap to open. Open items from an earlier cycle show as a reminder and under Overdue (red count on the tab), even inside their grace days.
- **Credit card statement and payment SMS (2026-11-04):** the statement date is accepted as dd-MM-yyyy or yyyy-MM-dd. "تم سداد البطاقة الائتمانية" (card paid from account 6000) is a `card_payment`: internal, excluded from spend, and it matches the statement by card number and amount. With an instalment plan that has `principal_halalas`, the statement row shows what is actually payable (total minus the principal of the instalments still to come: 21,090.78 - 4 x 1,564.07 = 14,834.50), not the full total.

- **Bills hero numbers (2026-11-05):** the credit card statement is left out of the paid / still-to-pay / x of y bills figures, because it already adds up last month's purchases and bills. Its row is still listed. Bill instances are created by issue day (`refresh_obligation_instances`): issued 1-19 gets this month and next, issued 20+ keeps last month and this month.
- **Coffee category (2026-11-05):** a flat `Coffee` / قهوة category for every account (migration `20261105100000_coffee_category.sql`, also in `seed_defaults` for new sign-ups). It belongs to the Food group on Home and has its own cup icon in the picker. Categories stay flat in the database; the grouping is app-side.
- **Hotel, Transfers, Income (2026-11-05):** a flat `Hotel` / فنادق category for every account (migration `20261105110000_hotel_category.sql`, also in `seed_defaults`) in the Lifestyle group with a hotel icon. Transfers and Income moved from Other to the Money group, with their own icons (arrows, banknote).
- **More default categories (2026-11-05):** Education, Family & Kids, Gifts & Charity, Pets, Personal care, Insurance, Government & fees (migration `20261105120000_more_categories.sql`, also in `seed_defaults`), each with its own icon. Home groups: new **Family** (Education, Family & Kids); Lifestyle gains Gifts & Charity and Pets; "Health" is now **Health and care** (adds Personal care); "Money" is now **Money and fees** (adds Insurance, Government & fees). Every new account starts with 26 categories; Horse and House Card stay owner-only.
