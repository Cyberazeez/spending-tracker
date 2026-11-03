# Home redesign (UI stage 1)

Status: waiting for the owner's review of this spec. Approved in chat: look, approach and the Home layout (mockup: https://claude.ai/artifact/1pdADNMnXjBzfgBvRQjR6V, private to the owner).

## Goal
Make the app look and feel like a bold modern fintech app instead of a settings app. Stage 1 is the Home tab. It sets the design system that the other tabs (Transactions, Insights, Bills, More) reuse in later stages, one PR each.

## What the owner said
- Look: bold fintech (big hero number, gradient cards, real charts, smooth motion), dark and light, Arabic and English.
- Dislikes: settings-like list look, ugly icons, too many categories, too much text and too many screens, no charts, scrolling.
- Keep: Flutter, every current feature, all data. Nothing about the backend changes.

## Scope of stage 1
Home only, plus the shared design layer it needs. No backend, no schema change, no change to what the numbers mean.

## Design layer (`app/lib/ui/`)
- **Tokens** (`tokens.dart`): colors for dark and light (from the mockup), radii (card 24, hero 28, chip 22, badge round), spacing on a 4 pt grid, text styles with tabular numerals for amounts.
  - Font: the system font (SF Pro / SF Arabic), not Inter as in the mockup, to avoid a font download and RTL font problems. A bundled Inter is a later option.
- **Components:** `HeroCard` (gradient, animated count-up number, budget ring), `Card` (rounded surface), `SectionHeader`, `WeekBars` (7-day bar chart, today highlighted), `StackedShareBar` + `CategoryRow` (round colored badge, name, share, amount), `BillCard` (status pill), `AttentionChip`, floating translucent tab bar.
- **Charts:** plain widgets (decided while building): the 7-day bars and the stacked share bar are simple, so no chart library; every bar is a real, labelled element for VoiceOver and mirrors in Arabic for free. A chart library (`fl_chart`) is for stage 3 (Insights: trends, lines).
- **Icons:** `lucide_icons_flutter` (consistent set). `phosphor_flutter` was tried first and does not compile with Flutter 3.47. One icon per category group. Replaces `CupertinoIcons` on Home and the tab bar.
- Cupertino stays for navigation, sheets, dialogs and haptics so it still feels like iOS.

## Categories on Home
The database keeps all categories. Home groups them for display only (a fixed mapping in code, no schema change):

| Group | Categories |
|---|---|
| Food | Groceries, Dining |
| Transport | Fuel, Transport, Car |
| Home and bills | Utilities, Rent/Housing, House Card |
| Horse | Horse |
| Lifestyle | Shopping, Entertainment, Travel |
| Subscriptions | Subscriptions |
| Health | Health |
| Money | Loans, Fees |
| Other | Other, uncategorised |

Home shows the top 4 groups by spend and "See all" opens Insights. Each group has one color and one icon (never color alone).

## Home layout (top to bottom)
1. Header: date, large title "Overview", bell (alerts) and add buttons.
2. Hero card: month spend (animated), budget ring and percent, chips Today, vs last month, Left to spend. With no monthly budget set: the ring becomes "Set a monthly budget" and Left to spend is hidden.
3. Last 7 days bars (Riyadh days, today highlighted, tap a bar for the amount).
4. Where it went: stacked share bar and the top 4 groups.
5. Next bills: up to 3 cards (overdue first), horizontally scrollable.
6. Attention chips: needs review count and possible gaps (hidden when zero).
7. Translucent tab bar (colors and blur from the design tokens). A fully floating pill needs a custom tab bar; the standard `CupertinoTabBar` is kept for now so tab switching, safe areas and VoiceOver stay native.

## Data
All from providers that already exist (insights, today spend, monthly budget, obligations, needs-review, gaps). One new pure function: daily spend for the last 7 Riyadh days from the transactions the app already holds (same spend rule as `spendOf`, so it agrees with the month total and the widget). One new pure function for the group mapping. Both unit tested.

## Scrolling and motion
Large title that collapses, bouncing physics on iOS, content padded for the floating tab bar (existing `BottomInset` approach), loading placeholders instead of spinners, pull to refresh, light haptics on taps. Respect Reduce Motion (no count-up, no bar animation).

## Accessibility and RTL
Dynamic Type up to accessibility sizes without clipping (the existing 2x text test must pass for every tab), VoiceOver labels on every chart ("Spent SAR 145 on Tuesday"), charts also readable as the list beneath them, 4.5:1 contrast, amounts stay left-to-right inside Arabic, layout mirrors in Arabic.

## Testing
- Unit: daily-spend function (Riyadh midnight boundary, refunds, internal and excluded rows), group mapping (every seeded category lands in exactly one group).
- Widget tests: Home renders with data, with no budget, with no data, in English and Arabic, and at 2x text on a small phone.
- Mockup is the visual reference; owner checks on the phone from the TestFlight build.

## Out of scope (later stages)
Transactions, Insights, Bills and More redesigns, bundled Inter, animations between screens, home-screen widget visuals, the AI switch, add-obligation-by-hand form.

## Risks
- Charts library behaves differently in RTL: mitigated by painters fallback.
- Cannot run the app on a phone here: visual polish is judged by the owner on TestFlight, so expect one or two tweak rounds.
- Floating tab bar over scroll content needs careful bottom padding on every tab, not only Home.

## Roadmap additions (owner, 2026-11-03)
- Add obligations by hand (form to create bills and fixed payments).
- UI stages 2 to 5 (Transactions, Insights, Bills, More), then login, lock and token screens.
