# Home redesign (UI stage 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Home tab's settings-style lists with a bold fintech layout (hero card, 7-day chart, grouped categories, bill cards) and a floating tab bar, without changing any data or backend.

**Architecture:** A small design layer in `app/lib/ui/` (tokens, card, charts) plus pure functions in `app/lib/features/home/` for the two new calculations (7-day spend, category groups). Home composes those widgets from providers that already exist. Cupertino stays for navigation, sheets and haptics.

**Tech Stack:** Flutter 3.47.9, Riverpod, `fl_chart` 1.3.0 and `phosphor_flutter` 2.1.0 (both resolve with the current constraints), existing l10n (`flutter gen-l10n`).

**Spec:** `docs/superpowers/specs/2026-11-03-home-redesign-design.md` (mockup: https://claude.ai/artifact/1pdADNMnXjBzfgBvRQjR6V)

## Global Constraints
- Money is integer halalas, never floats. Timezone is fixed UTC+3 (use `riyadhToday`, `toRiyadh`).
- Amounts render left-to-right inside Arabic text (`Directionality(textDirection: TextDirection.ltr, ...)`), Western digits, `formatSar(h, arabic:)`.
- Light and dark mode, English and Arabic (layout mirrors), Dynamic Type to accessibility sizes without clipping: `test/accessibility_test.dart` (2x text, all tabs, en/ar, light/dark) must keep passing.
- Charts are never color-only: every chart has labels, the category list repeats the numbers, VoiceOver labels on bars ("Spent SAR 145 on Tuesday").
- Reduce Motion (`MediaQuery.disableAnimationsOf`) turns off count-up and bar animation.
- No backend, schema or provider-semantics change. No new network calls.
- Repo rules: branch (never `main`), run `flutter analyze` + `flutter test`, `ship-review` before the PR, honest PR template, Swift/visuals not judged here, so say so.

## Review Focus
- No monthly budget set: ring and "Left to spend" are hidden, hero shows "Set a monthly budget" (not 0%).
- Spend above budget (over 100%): ring caps at full, percent shows the true number, color turns danger.
- Brand-new user with no transactions: zero bars, no category rows, no crash, friendly empty state (existing `EmptyState`).
- A category not in the group mapping (user-added later) or an uncategorised spend: lands in Other, never dropped.
- Refund bigger than that day's purchases: the day's bar is clamped at 0, the month total still subtracts it (consistent with `spendOf`).

---

### Task 1: Dependencies and design tokens

**Files:**
- Modify: `app/pubspec.yaml` (add `fl_chart: ^1.3.0`, `phosphor_flutter: ^2.1.0`)
- Create: `app/lib/ui/tokens.dart`, `app/lib/ui/app_card.dart`
- Test: `app/test/tokens_test.dart`

**Interfaces:**
- Produces: `class AppTokens` with static `CupertinoDynamicColor` fields `bg`, `card`, `tab`, `muted`, `text`, `accent`, `onAccent`, `bar`, `warnBg`, `warnText`, `okBg`, `okText`, `heroFrom`, `heroTo` (values from the mockup, dark and light); `static const double radiusCard = 24, radiusHero = 28`; `class AppCard extends StatelessWidget` (child, padding default 18, background `AppTokens.card`, radius 24).

- [ ] **Step 1: Write the failing test** `tokens_test.dart`: `AppTokens.card.resolveFrom(ctx)` equals `Color(0xFFFFFFFF)` under light and `Color(0xFF141A22)` under dark; `AppTokens.accent` light `0xFF0A7E6B`, dark `0xFF3CC4A8`; every pair meets 4.5:1 for `text` on `card` and `muted` on `card` in both modes (compute contrast in the test).
- [ ] **Step 2: Run** `cd app && flutter test test/tokens_test.dart` Expected: FAIL (file missing).
- [ ] **Step 3:** `flutter pub add fl_chart phosphor_flutter`; implement `tokens.dart` and `app_card.dart` with the mockup's hex values.
- [ ] **Step 4: Run** the test. Expected: PASS. Run `flutter analyze`: no issues.
- [ ] **Step 5: Commit** `feat: design tokens, card and chart/icon dependencies`.

### Task 2: Category groups (pure)

**Files:**
- Create: `app/lib/features/home/category_groups.dart`, `app/lib/features/home/group_style.dart`
- Test: `app/test/category_groups_test.dart`

**Interfaces:**
- Produces: `enum CategoryGroup { food, transport, homeBills, horse, lifestyle, subscriptions, health, money, other }`; `CategoryGroup groupOf(String? categoryName)` (null or unknown → `other`); `class GroupSpend { final CategoryGroup group; final int halalas; }`; `List<GroupSpend> groupSpend(List<CategorySpend> byCategory, List<Category> cats)` (sum per group, drop `halalas <= 0`, sorted by amount descending). `group_style.dart`: `Color groupColor(CategoryGroup)` (food `0xFF3CC4A8`, transport `0xFF6C8CFF`, homeBills `0xFFFFB340`, horse `0xFFA97B50`, lifestyle `0xFFC084FC`, subscriptions `0xFFF472B6`, health `0xFFFF6B66`, money `0xFF94A3B8`, other `0xFF8B97A5`), `IconData groupIcon(CategoryGroup)` (Phosphor), `String groupLabel(AppLocalizations t, CategoryGroup g)`.
- Consumes: `CategorySpend` (`metrics.dart`), `Category` (`models.dart`).

- [ ] **Step 1: Write the failing tests:** every seeded category name (`Groceries, Dining, Fuel, Utilities, Rent/Housing, Horse, Transport, Shopping, Subscriptions, Health, Entertainment, Travel, House Card, Fees, Other, Loans, Car`) maps to the group in the spec table; `groupOf('Brand new')` and `groupOf(null)` are `other`; `groupSpend` sums Groceries+Dining into `food`, drops a negative total, puts an uncategorised `CategorySpend(null, 500)` into `other`, and sorts descending.
- [ ] **Step 2: Run** `flutter test test/category_groups_test.dart` Expected: FAIL.
- [ ] **Step 3: Implement** the mapping as a `const Map<String, CategoryGroup>`; `groupSpend` looks category names up by id from `cats`.
- [ ] **Step 4: Run** Expected: PASS.
- [ ] **Step 5: Commit** `feat: group categories for Home`.

### Task 3: Seven-day spend (pure)

**Files:**
- Modify: `app/lib/features/insights/metrics.dart` (`Insights` gains `final List<DaySpend> last7Days;`, `computeInsights` fills it)
- Test: `app/test/insights_metrics_test.dart` (add cases)

**Interfaces:**
- Produces: `class DaySpend { const DaySpend(this.day, this.halalas); final DateTime day; final int halalas; }` (`day` = Riyadh calendar date as UTC midnight, like `riyadhToday`); `Insights.last7Days`: exactly 7 entries, oldest first, the last is today.
- Rule: same as the existing month total (`spendOf` plus excluded categories); a day's total is clamped at 0 for display.

- [ ] **Step 1: Write the failing tests:** with a clock of `2026-10-30 12:00Z` and rows on today, yesterday and 8 days ago, `last7Days.length == 7`, today's entry is today's sum, the 8-day-old row is absent; a row at `2026-10-29 21:30Z` (00:30 Riyadh on the 30th) counts for the 30th; a refund larger than the day's purchases gives 0 for that day; internal and excluded-category rows are ignored; empty history gives seven zeros.
- [ ] **Step 2: Run** `flutter test test/insights_metrics_test.dart` Expected: FAIL (no `last7Days`).
- [ ] **Step 3: Implement** inside `computeInsights` with one pass over `all`, reusing `day(t)` and `spendOf`; add the `last7Days:` argument to the single `Insights(...)` call.
- [ ] **Step 4: Run** the whole file. Expected: PASS (existing tests unchanged).
- [ ] **Step 5: Commit** `feat: seven-day spend in Insights`.

### Task 4: Home widgets

**Files:**
- Create: `app/lib/features/home/widgets/hero_card.dart`, `week_bars.dart`, `share_bar.dart`, `bill_card.dart`, `attention_chip.dart`
- Test: `app/test/home_widgets_test.dart`

**Interfaces:**
- `HeroCard({required int monthHalalas, int? budgetHalalas, required int todayHalalas, required int? lastMonthDiffHalalas, required bool arabic})`: no budget → shows "Set a monthly budget" in place of the ring and hides "Left to spend"; over 100% → ring full, text keeps the true percent, danger color. Count-up animation unless `disableAnimations`.
- `WeekBars({required List<DaySpend> days, required bool arabic})`: 7 bars via `fl_chart` `BarChart` (fallback: `CustomPainter` if RTL mirrors wrongly, noted in the PR); today highlighted; each bar has `Semantics(label: 'Spent SAR 145 on Tuesday')`.
- `ShareBar({required List<GroupSpend> top, required AppLocalizations t, required bool arabic})`: stacked bar plus up to 4 `CategoryRow`s (round badge with `groupIcon`, label, percent, amount in an LTR isolate).
- `BillCard({required ObligationInstance bill, required DateTime today, required bool arabic})`: status pill (overdue danger, due within 7 days warn, else ok), amount or "~" estimate, due date.
- `AttentionChip({required String label, required Color dot, required VoidCallback onTap})`.

- [ ] **Step 1: Write the failing widget tests** (pump each in light/dark and `Locale('ar')`): hero with budget 800000 and month 481200 shows `60%`; hero without budget shows the set-budget text and no `%`; hero over budget (month 900000) shows `112%`; `WeekBars` exposes seven semantics labels and today's is bold; `ShareBar` with `[food 1396, transport 770]` shows two rows and percents summing to 100 for the shown groups; `BillCard` overdue shows the overdue pill.
- [ ] **Step 2: Run** `flutter test test/home_widgets_test.dart` Expected: FAIL.
- [ ] **Step 3: Implement** the five widgets from the mockup values (radius 28 hero, gradient `heroFrom`→`heroTo`, ring via `CustomPainter`).
- [ ] **Step 4: Run** Expected: PASS; `flutter analyze` clean.
- [ ] **Step 5: Commit** `feat: Home widgets (hero, week bars, share bar, bill card)`.

### Task 5: Strings

**Files:**
- Modify: `app/lib/l10n/app_en.arb`, `app_ar.arb` (+ regenerate with `flutter gen-l10n`)

**Interfaces:**
- Produces new keys used by Task 4 and 6: `homeOverview` ("Overview"/"نظرة عامة"), `homeLast7`, `homeWhereItWent`, `homeSeeAll`, `homeNextBills`, `homeAllBills`, `homeLeftToSpend`, `homeVsLastMonth`, `homeSetBudget`, `homeToReview(count)`, `homePossibleGap`, `groupFood`…`groupOther` (nine group names), `homeBarLabel(amount, weekday)`.

- [ ] **Step 1:** add the keys in both files (Arabic written natively, short, no mixed English).
- [ ] **Step 2: Run** `flutter gen-l10n && flutter analyze` Expected: no issues; every key exists in both languages (a test in `l10n_keys_test.dart` compares the two key sets).
- [ ] **Step 3: Commit** `feat: Home strings (en, ar)`.

### Task 6: Home screen and floating tab bar

**Files:**
- Modify: `app/lib/features/home/home_page.dart` (rewrite the build to the spec layout, keep providers, pull to refresh, alerts, routes), `app/lib/features/shell/shell_page.dart` (floating translucent bar), `app/lib/ui/bottom_inset.dart` (account for the taller floating bar)
- Test: `app/test/home_test.dart` (update), `app/test/accessibility_test.dart` (must still pass)

**Interfaces:**
- Consumes: `Insights.last7Days`, `groupSpend`, Task 4 widgets, `obligationsProvider`, `needsReviewProvider`, `senderGapsProvider`, `todaySpendProvider`, `monthlyBudgetProvider`.
- Behavior kept: pull to refresh invalidates the same providers; the add button goes to `quickAddPath`; attention chips go to `reviewPath` and `gapsPath`; budget alerts still shown (as a compact warn/danger card under the hero) so no feature is lost; silent-days banner kept.

- [ ] **Step 1: Update `home_test.dart` first:** Home with data shows the hero amount, `Last 7 days`, the top group name, one bill card; with no budget shows the set-budget text; empty history shows the empty state; tapping the review chip routes to `reviewPath`; Arabic render has no overflow.
- [ ] **Step 2: Run** `flutter test test/home_test.dart test/accessibility_test.dart` Expected: FAIL.
- [ ] **Step 3: Implement** the layout: `CupertinoSliverNavigationBar` large title collapse, `CustomScrollView` with `BouncingScrollPhysics`, loading placeholders (grey rounded boxes, no spinner), `BottomInset` sized for the floating bar; shell: `CupertinoTabBar` with `backgroundColor` translucent plus blur, Phosphor icons, inset margins.
- [ ] **Step 4: Run** the two files plus the full suite `flutter test`. Expected: all pass (2x text test included).
- [ ] **Step 5: Commit** `feat: new Home screen and floating tab bar`.

### Task 7: Docs, ship-review, PR

**Files:**
- Modify: `docs/04-design-brief.md` (new look: tokens, components, fonts note), `docs/06-implementation-plan.md` (UI stages 2 to 5, add obligations by hand)

- [ ] **Step 1:** update the two docs to match what was built.
- [ ] **Step 2:** run `flutter analyze` and `flutter test`, then the `ship-review` skill; fix anything high or critical.
- [ ] **Step 3:** push, open a draft PR with the template filled in honestly (not tested on a phone, charts RTL decision, what the owner should check on TestFlight), subscribe to it.
- [ ] **Step 4: Commit** `docs: Home redesign design brief and roadmap`.
