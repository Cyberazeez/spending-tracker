# Rebrand stage 1 (design layer and Home) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the whole app the Emerald look (paper background, outlined cards with hard shadows, pill buttons, Rubik) through the shared design layer, and finish the Home tab to match the mockup.

**Architecture:** Colours stay in `AppTokens` under their current names so call sites do not change; two new helpers (`outlineOf`, `hardShadowOf`) carry the outline and shadow so every component draws them the same way. Shared components (`AppCard`, `PrimaryButton`, `PillTabBar`, `SheetFrame`, form fields) are restyled in place; Home's own widgets are restyled last.

**Tech Stack:** Flutter 3.47.9 (Cupertino), Riverpod, `lucide_icons_flutter`, bundled fonts (Rubik, SaudiRiyal).

**Spec:** `docs/superpowers/specs/2026-11-11-rebrand-design.md` (owner approved 2026-11-11: "Go with recommendations": bundle Rubik, derive dark mode, fresh branch after PR #103).

## Global Constraints
- No backend, schema, function, routing or l10n-key change. No change to what any number means.
- Colours, exactly: bg `#F0F5E6` / `#0D1F17`; card and tab `#FFFFFF` / `#173326`; text `#0D1F17` / `#F0F5E6`; muted `#45564B` / `#A9BBAF`; accent `#00A86B` / `#3FD79B`; onAccent `#0D1F17` both; accentText `#00704A` / `#3FD79B`; line `#0D1F17` / `#F0F5E6`; gold `#FFC93C` both; danger `#D11A3F` / `#FF9DB0`; bar `#DCE5CC` / `#2B4C3D`.
- Outline 2.5 pt (2 pt on small elements). Shadow: offset (4, 5), no blur, colour `line`; buttons (3, 4). The shadow goes right and down in both text directions.
- Radii: card 20, hero 26, sheet 28, tile 13, buttons and chips fully round.
- Tap targets stay at least 44 x 44. Text contrast at least 4.5:1.
- The riyal sign keeps rendering from the `SaudiRiyal` font.
- Money stays integer halalas; no float maths added.
- Every commit message uses `feat:` / `fix:` / `docs:` / `test:`.

## Review Focus
1. **Arabic (right to left):** outlines and shadows must not clip or flip; the tab pill, chevrons and bars mirror, the shadow does not. Test in task 4 and 7.
2. **2x text size on a 360 x 720 phone:** outlined buttons, chips and the tab bar must not overflow. `a11y_guidelines_test.dart` covers the tabs; task 3 adds a 2x test for `PrimaryButton`.
3. **Dark mode:** the outline is light (`#F0F5E6`) on moss cards; a component that hard-codes ink disappears. Every component test runs in both brightnesses (tasks 2 to 5).
4. **Disabled and busy buttons:** must stay readable and visibly different from enabled without relying on opacity alone on the label. Test in task 3.
5. **Shadows inside scroll views and sheets:** the 5 pt shadow must not be cut off by a clip at the card's edge. Task 2 gives `AppCard` its own bottom and trailing margin so the shadow is inside its box; test asserts the painted shadow lies inside the widget's size.

---

### Task 1: Tokens and theme

**Files:**
- Modify: `app/lib/ui/tokens.dart`, `app/lib/ui/theme.dart`
- Modify: `app/lib/features/home/widgets/hero_card.dart`, `app/lib/features/ai/widgets/ai_tips_card.dart` (only to stop using the removed gradient tokens: fill with `AppTokens.accent` and `AppTokens.gold`)
- Test: `app/test/tokens_test.dart`

**Interfaces:**
- Produces: `AppTokens.bg, card, tab, text, muted, accent, onAccent, bar, danger, income` (same names, new values; `income` = `accentText`); new `AppTokens.accentText`, `AppTokens.line`, `AppTokens.gold` (all `CupertinoDynamicColor`); `warnBg` = gold, `warnText` = ink (both modes), `okBg` = `#3FD79B`, `okText` = ink. Removed: `heroFrom`, `heroTo`. New constants `radiusCard = 20`, `radiusHero = 26`, `radiusSheet = 28`, `radiusTile = 13`, `outline = 2.5`, `outlineThin = 2.0`. New functions `Border outlineOf(BuildContext c, {double width = AppTokens.outline})` and `List<BoxShadow> hardShadowOf(BuildContext c, {Offset offset = const Offset(4, 5)})` (blurRadius 0, colour `line`). `AppColors.accent` and `AppColors.danger` in `theme.dart` point at the token values.

- [ ] **Step 1:** In `tokens_test.dart` change the expected values to the Global Constraints (card, accent, bg, text, line, gold, danger, in both brightnesses) and add contrast assertions of at least 4.5 for: text on card, text on bg, muted on card, muted on bg, accentText on card, accentText on bg, onAccent on accent, danger on card, `warnText` on `warnBg`, `okText` on `okBg`. Add a test that `hardShadowOf` returns one shadow with `blurRadius == 0` and `offset == Offset(4, 5)`.
- [ ] **Step 2:** Run `flutter test test/tokens_test.dart`. Expected: FAIL on the first colour.
- [ ] **Step 3:** Implement the Produces block.
- [ ] **Step 4:** Run `flutter analyze` and `flutter test test/tokens_test.dart`. Expected: no analyzer errors, PASS.
- [ ] **Step 5:** Commit `feat: Emerald design tokens, outline and hard-shadow helpers`.

### Task 2: Rubik typeface

**Files:**
- Create: `app/assets/fonts/Rubik-Regular.ttf`, `Rubik-Medium.ttf`, `Rubik-Bold.ttf`, `Rubik-ExtraBold.ttf`, `app/assets/fonts/Rubik-LICENSE.txt` (static instances of the official Rubik variable font at weights 400, 500, 700, 800, Latin and Arabic glyphs kept; SIL OFL 1.1)
- Modify: `app/pubspec.yaml` (family `Rubik`, four weights), `app/lib/ui/theme.dart` (`CupertinoTextThemeData` with `fontFamily: 'Rubik'`), `app/assets/fonts/README.md`
- Test: `app/test/icon_font_test.dart` style: new `app/test/font_test.dart`

**Interfaces:**
- Produces: `appTheme` whose `textTheme.textStyle.fontFamily == 'Rubik'`; nav titles, large titles and tab labels also Rubik. Existing riyal-sign rendering (see how `SaudiRiyal` is referenced in `core/format.dart` / `core/money.dart`) is left as it is.

- [ ] **Step 1:** Write `font_test.dart`: `appTheme.textTheme.textStyle.fontFamily == 'Rubik'`, and the four font files exist (`dart:io`). Glyph coverage (Latin letters, Western digits, Arabic letters) is checked once with fontTools when the files are made and recorded in the fonts README.
- [ ] **Step 2:** Run it. Expected: FAIL.
- [ ] **Step 3:** Produce the four static TTFs, add them to `pubspec.yaml`, set the theme.
- [ ] **Step 4:** Run `flutter test test/font_test.dart test/money_test.dart test/polish_test.dart`. Expected: PASS (the riyal-sign tests still pass).
- [ ] **Step 5:** Commit `feat: bundle Rubik and make it the app typeface`.

### Task 3: Cards and buttons

**Files:**
- Modify: `app/lib/ui/app_card.dart`, `app/lib/ui/app_form.dart` (`PrimaryButton` and the other buttons and fields defined there)
- Test: `app/test/design_layer_test.dart` (new)

**Interfaces:**
- Consumes: `outlineOf`, `hardShadowOf`, tokens.
- Produces: `AppCard({child, padding = EdgeInsets.all(16), Color? color, bool flat = false, double radius = AppTokens.radiusCard})`: outline always; hard shadow unless `flat`; the widget reserves 4 pt at the trailing-right and 5 pt at the bottom so the shadow is inside its own box. `PrimaryButton` keeps its constructor; look: accent fill, outline, shadow (3, 4), label `onAccent` weight 700, height 52; disabled: fill `bar`, label `muted`, no shadow. New `SecondaryButton({label, onPressed, IconData? icon, bool danger = false})`: card fill, outline, shadow (3, 4), label `text` (or `danger`). Text fields in `app_form.dart`: fill `card`, outline, radius 14, min height 50.

- [ ] **Step 1:** Tests, each in light and dark: `AppCard` paints a `BoxDecoration` with a 2.5 border in `line` and one blur-0 shadow; `flat: true` has no shadow; the shadow rect lies within the widget's size. `PrimaryButton` enabled has the shadow and `onAccent` label; disabled has no shadow and a `muted` label; at `textScaler: TextScaler.linear(2)` in a 360-wide box there is no overflow exception; its tap target is at least 44 high. `SecondaryButton(danger: true)` label colour equals `danger`.
- [ ] **Step 2:** Run `flutter test test/design_layer_test.dart`. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the new test plus `flutter test test/sheets_test.dart test/signup_test.dart test/a11y_guidelines_test.dart`. Expected: PASS.
- [ ] **Step 5:** Commit `feat: outlined cards and pill buttons`.

### Task 4: Tab bar and sheet frame

**Files:**
- Modify: `app/lib/ui/pill_tab_bar.dart`, `app/lib/ui/sheet_frame.dart`, `app/lib/ui/skeleton.dart`, `app/lib/ui/launch_skeleton.dart`
- Test: `app/test/design_layer_test.dart`

**Interfaces:**
- Produces: `PillTabBar` (same constructor and `copyWith`): card-coloured pill, outline, shadow (4, 5); the selected item is an accent pill with outline (2 pt) holding icon and label in `onAccent`; unselected items are icon only in `text` with the label kept in semantics; every item keeps a 44 x 44 hit area. `SheetFrame` (same constructor): fill `card`, a 2.5 pt `line` border on the top edge, radius 28, grabber in `line` at 35% opacity. Skeleton blocks use `bar`.

- [ ] **Step 1:** Tests in light, dark, English and Arabic: the selected tab shows its label text, unselected ones do not show text but expose their label to semantics; tapping an unselected item calls `onTap` with its index; in Arabic the first item is on the right; `SheetFrame`'s decoration has a top border of 2.5 in `line`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the new test plus `flutter test test/router_test.dart test/app_flow_test.dart test/a11y_guidelines_test.dart test/sheets_test.dart`. Expected: PASS.
- [ ] **Step 5:** Commit `feat: outlined tab bar and sheet frame`.

### Task 5: Category colours and tiles

**Files:**
- Modify: `app/lib/features/home/group_style.dart`; create `app/lib/ui/icon_tile.dart`, `app/lib/ui/app_chip.dart`
- Modify the call sites that draw a round coloured badge (`features/home/widgets/share_bar.dart`, `features/transactions/widgets/txn_row.dart`, `ui/category_sheet.dart`, `features/insights/widgets/*`) to use `IconTile`
- Test: `app/test/category_groups_test.dart`, `app/test/design_layer_test.dart`

**Interfaces:**
- Produces: `groupColor`: food `#FFC93C`, transport `#9CC4FF`, homeBills `#FFA574`, family `#9BE7E0`, horse `#DDE3CC`, lifestyle `#CDB4FF`, subscriptions `#CDB4FF`, health `#FF9DB0`, money `#3FD79B`, other `#DDE3CC`. `IconTile({required IconData icon, required Color color, double size = 42})`: rounded square (radius 13), 2 pt outline, icon in ink `#0D1F17` in both modes (the fills are light in both modes). `AppChip({required String label, Color? color, VoidCallback? onTap})`: pill, 2 pt outline, label 13/700, ink label when `color` is given, else `text` on `card`.

- [ ] **Step 1:** Tests: every `CategoryGroup` has a colour with contrast of at least 4.5 against ink `#0D1F17`; `IconTile` has the outline and an ink icon in dark mode; `AppChip` with `onTap` has a hit area at least 44 high.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement and switch the call sites.
- [ ] **Step 4:** Run `flutter test test/category_groups_test.dart test/design_layer_test.dart test/home_widgets_test.dart test/transactions_redesign_test.dart test/category_sheet_test.dart test/insights_widgets_test.dart`. Expected: PASS (update assertions that named the old round badge or old colours).
- [ ] **Step 5:** Commit `feat: pastel category tiles and chips`.

### Task 6: Home

**Files:**
- Modify: `app/lib/features/home/widgets/hero_card.dart`, `week_bars.dart`, `share_bar.dart`, `attention_chip.dart`, `bill_card.dart`, `welcome_card.dart`, `app/lib/features/home/home_page.dart`, `app/lib/features/ai/widgets/ai_tips_card.dart`
- Test: `app/test/home_widgets_test.dart`, `app/test/home_test.dart`

**Interfaces:**
- Consumes: `AppCard`, `IconTile`, `AppChip`, tokens.
- Produces (constructors unchanged): `HeroCard`: flat accent fill, outline, shadow (5, 6), radius 26, ink text; inside it a white outlined box with "Left to spend" and "Today"; the budget is a horizontal bar (white track, gold fill, 2 pt outline) with the "x% of budget" line under it, replacing the ring; no budget: the existing "Set a monthly budget" action in place of the bar; over 100%: bar full, text keeps the true percent, fill `danger`. Count-up animation and Reduce Motion behaviour unchanged. `WeekBars`: outlined bars, selected bar accent, others `bar`. `ShareBar`: outlined stacked bar and `IconTile` rows. `AttentionChip`: `AppChip` in gold (review) or `#FFA574` (budget). `AiTipsCard`: gold fill, outline, shadow, ink text.

- [ ] **Step 1:** Update `home_widgets_test.dart`: hero shows the month amount, "Left to spend" and "Today"; with a budget a `Semantics` label gives the percent and the bar's fill fraction equals spent / budget capped at 1; at 120% the percent text reads 120 and the fill colour is `danger`; with no budget the set-budget action is present and no bar; right-to-left: the bar fills from the right. Keep every existing behavioural assertion; drop only the ones about the ring and the gradient.
- [ ] **Step 2:** Run `flutter test test/home_widgets_test.dart`. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run `flutter test test/home_widgets_test.dart test/home_test.dart test/states_test.dart test/a11y_guidelines_test.dart test/ai_test.dart`. Expected: PASS.
- [ ] **Step 5:** Commit `feat: Home in the Emerald look`.

### Task 7: Whole-app pass, screenshots, docs

**Files:**
- Modify: any screen where the token change left something unreadable or clipped (hard-coded colours, `CupertinoColors.*` backgrounds, old radii)
- Create: `app/test/screens_snapshot_test.dart` (writes PNGs of the five tabs, light and dark, English and Arabic, to `app/build/snapshots/`; not golden-compared, so it never fails on pixels)
- Modify: `docs/04-design-brief.md` (the Emerald section becomes the live description; old colour, radius and font sections updated), `docs/06-implementation-plan.md` (rebrand stages), `docs/superpowers/specs/2026-11-11-rebrand-design.md` (status line)

- [ ] **Step 1:** Run the whole suite: `flutter analyze && flutter test`. Fix failures caused by the restyle (assertions on old colours); do not weaken behavioural assertions.
- [ ] **Step 2:** Write and run the snapshot test; look at all 20 images; fix what is unreadable or clipped.
- [ ] **Step 3:** Search for leftovers: `grep -rn "0xFF0A7E6B\|0xFF3CC4A8\|LinearGradient\|blurRadius" app/lib` and resolve each hit (remove, or keep with a reason in the PR).
- [ ] **Step 4:** Update the docs. Run `flutter analyze && flutter test` again. Expected: clean, all pass.
- [ ] **Step 5:** Commit `fix: whole-app pass after the token change` and `docs: Emerald look is live in the design brief`.
- [ ] **Step 6:** Run the `ship-review` skill, fix anything high or critical, push, open the pull request with the snapshots described in "How it was tested" and the untested items (real iPhone, widget, VoiceOver) listed.
