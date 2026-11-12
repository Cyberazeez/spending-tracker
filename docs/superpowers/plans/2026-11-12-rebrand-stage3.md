# Rebrand stage 3 (Bills and Insights) Plan

**Goal:** Give the Bills and Insights tabs and what opens from them the Emerald look of the mockups (boards Bills, BillSheet, AddBill, ConfirmSheet, AmountSheet, Insights, Chat).

**Spec:** `docs/superpowers/specs/2026-11-11-rebrand-design.md`, stage 3. Constraints as in stage 2: restyle only, `AppTokens` and the outline/shadow helpers, `accentText` for text on cards, `onTint` on gold, mint and category fills, 44 pt targets, 2x text, Arabic.

## Not built (flow changes, wait for the owner)
- **Bill detail sheet with fields and switches** (board BillSheet): a row still opens the short list of actions (edit amount, edit details, mark paid, skip, stop).
- **"Add a bill" start tiles** (board AddBill): the + still opens the form directly.
- **Budget pills "82%" / "Over"** on budget rows: they would need new text keys; the bar colour and the "of limit" line stay.
- **"Try asking" chips under the chat**: the chat keeps its own prompt chips, restyled.

## Tasks
1. Shared: `AppCard(shadow:)` for the (5, 6) hero shadow; `HeaderIconButton` (from stage 2's Activity button, now shared); `OutlinedBar`.
2. Bills: gold hero with ink text and an outlined white bar; gold square add button; outlined segments with a shadow and an outlined count badge; outlined status pills with a word (overdue red with white or ink text, due-soon gold, paid mint, else plain); pastel kind tiles; rows card outlined with 2 pt lines; leftover notice as a gold card.
3. Bill form: outlined fields, labels in ink 13/700, outlined round steppers.
4. Insights: outlined budget bars (emerald, gold when close, red when over), category tiles, outlined donut (outer and inner ring, lines between slices) and legend squares, outlined month bars, savings box and rank circles outlined.
5. AI: tips card gold with ink text (was white on gold, 1.6:1), white outlined pills; chat bubbles outlined with a shadow and a tight corner on the speaker's side, outlined input, gold send button.
6. Sheets: confirm buttons are outlined pills with a shadow (destructive label readable in dark); amount sheet field outlined, quick amounts outlined and 44 pt tall.
7. Snapshots of the form, row actions, amount and confirm sheets, the tips card and the chat; docs; checks; ship-review; PR.

## What was built differently (2026-11-12)
- **Bill form tests** scroll to Save before tapping it: outlines and shadows made the form about 12 pt taller than the test screen.
- **Kind tiles** use the category pastels (bill coral, card statement gold, loan sky, fixed cost lilac) instead of the old saturated kind colours, so text on them is ink.
