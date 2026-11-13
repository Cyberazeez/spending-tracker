# Redesign batch 5: Needs review, AI chat, monthly budget, rules that stay deleted

Owner's screenshots and comments: "needs review screen should match this", "AI chat screen should look like this", "monthly budget sheet should match this". Owner rule: the mockup wins. Plus the owner's yes (2026-11-13) to "a deleted rule stays deleted".

## Done
- **Needs review**: "Read by AI: please check" rows (gold sparkle tile, what it found, "SAR 86.00 · date", chevron); "Could not read" is one card per message: the bank (sender IDs mapped to bank names), the time, the SMS in a box, a coral tag for why it is here (`needs_review` New message format, `low_confidence` Not sure, `failed` Could not read it), and the links Add (opens the form) and Not a purchase (one tap, no sheet). A load failure shows the shared Could not load card.
- **AI chat**: rounded bubbles (the person emerald, answers white) with hard shadows; "Try asking" chips stay under the conversation; pill input and a round gold send button.
- **Monthly budget**: one sheet (no "Set / Remove" choice first): the amount big and centred, presets 4,000 / 5,000 / 6,000 / 8,000 with the chosen one in emerald, Save, and "Remove the budget" only while one is set. Saving the same amount sends nothing. The shared amount sheet (bill amounts, category budgets) gets the same look.
- **Deleted rules stay deleted**: migration `20261113100000_disabled_merchant_rules.sql` allows `merchant_rules.status = 'disabled'`. Deleting on Categories and rules sets it.
  - Ingest skips disabled rules, and `categorize()` itself skips them (so the statement import tool cannot apply one either).
  - Seeds ("on conflict do nothing") never re-create them.
  - categorize-batch never asks the AI about a merchant whose **exact** rule was deleted, so that merchant's new purchases stay uncategorised until the owner files them. Deleting a seed contains/prefix rule (e.g. `starbucks`) does let the AI suggest exact rules for the merchants it used to cover.
  - Filing one purchase by hand no longer brings a deleted rule back (the app skips the rule save when the place's rule is disabled). There is no way to turn a deleted rule back on yet.
- **Needs review "Not a purchase"** asks first in a sheet showing the whole SMS (the card shows four lines), so a real purchase is not hidden by a stray tap; a failed save says so.

## Not from the mockup
- "Looks like a transfer" (a tag in the mockup) needs a reason the server does not record today; the tags follow the stored parse status instead.
- Today the server only ever stores `needs_review`, so every card shows "New message format"; the Not sure / Could not read it tags appear once the server records those states.
