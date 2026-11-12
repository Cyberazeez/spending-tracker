# Rebrand stage 2 (Activity) Plan

**Goal:** Give the Activity tab and everything opened from it the Emerald look of the mockups (boards Activity, Txn, QuickAdd, Review, FilterSheet, CategorySheet).

**Spec:** `docs/superpowers/specs/2026-11-11-rebrand-design.md`, stage 2. Stage 1: `2026-11-11-rebrand-stage1.md` (its "What was built differently" still holds: labels on every tab, Home keeps the ring, sheets keep the paper fill).

## Constraints
- Restyle only. No backend, schema, routing, l10n-key or behaviour change: every tap still does what it did, every text still says what it said.
- Reuse `AppTokens`, `outlineOf`, `hardShadowOf`. Text on cards: `accentText`, never `accent`. Text and icons on gold, mint or category tiles: `onTint`.
- Tap targets at least 44 x 44; nothing overflows at 2x text on a 360 pt phone; Arabic mirrors layout, not shadows.

## What the mockups show that the app does not have (not built)
- **Transaction detail screen** (board Txn): the app has none. Tapping a row opens the category picker. A new screen would be a flow change, so it waits for the owner.
- **Filter sheet with date segments, bank chips and switches** (board FilterSheet): the app's filter is a short list of choices. Same reason: only its look changes.
- **Review cards with Add / Not a purchase buttons** (board Review): the app opens a choice sheet per message. The rows get the new look; the flow stays.
- **Floating gold add button** (board Activity): the add button stays in the title bar (same position, same test path), drawn as the gold outlined circle with a hard shadow.

## Tasks
1. **Shared pieces** (`app/lib/ui/`)
   - New `icon_tile.dart`: `IconTile({icon, color, size = 42, radius = 13, iconSize})`, category fill, 2 pt `line` outline, icon in `onTint`.
   - `app_form.dart`: new `SecondaryButton({label, onPressed, danger = false})`: card fill, outline, (3, 4) shadow, label `text` or `danger`. New `FieldButton({icon, label, onPressed})`: a tappable row in the field look (card, outline, radius 14, 50 tall) for pickers.
   - `swipe_action.dart`: the Delete label is ink on the light dark-mode red (white on `#FF9DB0` was 1.9:1), white on the light-mode red.
   - `choice_sheet.dart` (filter sheet, review sheets): options in an outlined card; the message (an SMS) in a paper box with a 2 pt outline.
   - Tests: tile outline and ink icon in dark; `SecondaryButton(danger)` label colour; swipe label contrast at least 4.5 in both modes.
2. **Activity list** (`transactions_page.dart`, `widgets/txn_row.dart`, `widgets/filter_chips.dart`)
   - Title bar: filter button as a 44 pt outlined square with a (3, 4) shadow, emerald when a filter is on; add button gold circle with outline and shadow.
   - Chips 13/700; selected emerald; "No category" and "to review" chips gold with ink text (instead of the orange dot) when not selected.
   - Day header: label and total muted 14/700.
   - Rows: `IconTile` (uncategorised: gold tile with "?"), title 15/700, subline 13/500, amount 15/700 tabular; dividers 2 pt `bar`.
   - Tests: existing row and chip tests keep passing; new: uncategorised tile is gold with ink "?"; chip colours.
3. **Category picker** (`ui/category_sheet.dart`)
   - Ink top border, grabber in `line` at 35%, title 20/800, outlined close button.
   - Tiles: a 56 pt `IconTile` (radius 16) with the label under it, no card; selected: emerald ring around the tile plus the check badge (never colour alone).
   - Remove button: `SecondaryButton(danger: true)`.
   - Tests: selected tile has the ring and the check; remove button still returns `''`.
4. **Quick add and Needs review** (`manual_form.dart`, `review_page.dart`)
   - Quick add: amount field large (22/800); the time row becomes a `FieldButton` with a calendar icon (same text, same picker).
   - Needs review: section headings 18/800 in `text`; rows in an outlined card with an `IconTile` (sparkles on gold for AI reads, message icon on sand for unread messages); the SMS preview stays two lines.
   - Tests: existing review and quick-add tests keep passing.
5. **Snapshots and docs**
   - `screens_snapshot_test.dart`: add Quick add, Needs review, the category picker and the filter sheet, light and dark, English and Arabic. Look at every picture.
   - `docs/04-design-brief.md` (Brand section: what is in the app after stage 2), spec status line.
   - `flutter analyze` clean, `flutter test` all pass, ship-review, PR with the template.

## What was built differently (2026-11-12)
- **Sheet font:** the category picker, `SheetFrame` and the Shortcut guide set their own text style without a font family, so their text was in the system font, not Rubik. They now name Rubik (with the riyal fallback). Found in the snapshots.
- **Activity rows:** the card is inset by its outline so a row slid open to Delete no longer paints over the card's side edges.
- **Quick add date row:** the date keeps its left-to-right order inside the Arabic label (Unicode isolate marks) instead of turning the whole row left to right.
- **Category grid** stays three columns (the mockup has four) so two-line Arabic names and 2x text still fit.
