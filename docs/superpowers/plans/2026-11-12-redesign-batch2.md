# Redesign batch 2: Activity

Owner's screenshots and comments (12 Nov): filter sheet, category sheet, add transaction screen, floating add button, transaction screen with more details. Owner rule: the redesign wins over the current app.

## Built
- **Chips under the search:** the period ("This month", "Last month", a custom range) and the account ("All banks" or "•••• 4821") open the filter sheet; "No category · N" (gold, emerald when on) switches the filter; "AI suggested" shows when the list has AI-categorised rows; "N to review" stays while messages wait (on a new account Home shows no chips, so this is the way to them).
- **Filter sheet:** Date (This month / Last month / Custom with From and To), Category (one group: Food, Transport, Home and bills, ...), Bank or card (All, each own account), switches "No category only" and "Include transfers between my accounts", Reset and "Show N" (counts as you change it). The list now shows this month by default.
- **Floating add button:** gold, round, bottom corner above the tab bar (the title-bar + is gone).
- **Transaction screen** (tap a row): category tile, merchant, date and time, the amount, the category pill and "Change category", Card / Source / Linked bill, a note (saved when you leave the field), "Original message" (the bank SMS), "Report a reading problem" (support page, for SMS rows), Delete. Before, a row opened the category picker.
- **Category picker:** "Suggested for this merchant" as chips (the best one gold), one 4-column grid of all categories (no group headings), Remove category.
- **Add a transaction** (was Quick add): the amount in a big card, Merchant, Category row, Date and Time, Paid with (one of the own accounts), Note, Save.

## Data (no backend change)
The app now reads `bank`, `account_last4`, `note`, `source` and `raw_message_id` of transactions, writes `note` and, on manual entries, `category_id`, `bank`, `account_last4`, `note` (columns and owner policies already existed). New repository calls: `countTransactions`, `setNote`, `rawMessageBody`.

## Changed by the redesign (owner's rule)
- **Spent / Received** is gone from Add a transaction (the mockup has none): money received is added through Needs review ("Add as transaction" keeps the switch). Flag for the owner.
- "Hide internal" chip moved into the sheet as "Include transfers between my accounts".
