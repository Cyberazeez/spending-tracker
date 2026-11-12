# 04-design-brief

A calm, native-feeling iPhone app. Numbers first. Since 2026-11-03 (Home stage 1) the look is bold fintech: a gradient hero card, rounded cards on a dark or light background, round colored category badges, simple charts. Spec: `docs/superpowers/specs/2026-11-03-home-redesign-design.md`; tokens in `app/lib/ui/tokens.dart`; icons are Lucide (`lucide_icons_flutter`); the other tabs are redesigned in later stages.

## Brand (2026-11-11, owner decision)
- **Logo:** the Arabic word هللة only, no Latin companion. Flared letters with an ink outline and a hard offset shadow, tilted 8 degrees; the two dots of the ة are two gold coins. "Halala" in Latin is plain text wherever it is needed (App Store name, English UI, emails), never a drawn logo.
- **Files:** `docs/brand/` (`logo.svg`, `app-icon.svg`, `app-icon-small.svg`; see its README). The iOS icon set in `app/ios/Runner/Assets.xcassets/AppIcon.appiconset/` is exported from them.
- **Palette "Emerald":**

| Name | Hex | Role |
|---|---|---|
| Emerald | `#00A86B` | Brand, buttons, fills |
| Deep emerald | `#00704A` | Links and income amounts on light backgrounds |
| Gold | `#FFC93C` | Coins, highlights, warnings |
| Tomato | `#D11A3F` | Over budget, overdue |
| Ink | `#0D1F17` | Outlines, hard shadows, text |
| Paper | `#F0F5E6` | Page background (light) |
| Mint | `#3FD79B` | Brand colour on dark |
| Moss | `#173326` | Cards on dark |

- **In the app since rebrand stage 1 (2026-11-11):** the shared design layer and Home. Tokens in `app/lib/ui/tokens.dart` (`outlineOf`, `hardShadowOf`), outlined `AppCard`, pill `PrimaryButton`, outlined fields, chips, segmented control and tab bar (every tab keeps its label; the selected one sits on an emerald pill), pastel category tiles, the emerald Home hero with a gold budget ring. Typeface: bundled **Rubik** (Latin and Arabic); the riyal sign still comes from `SaudiRiyal`. Later stages (Activity, Bills and Insights, Start and More, motion, widget, emails, website): `docs/superpowers/specs/2026-11-11-rebrand-design.md`.
- **Stage 2 (2026-11-12), Activity:** outlined title-bar buttons (filter, gold add), gold chips for things waiting on the owner, muted day headers, category tiles on every row (`IconTile`, gold "?" when uncategorised), 2 pt row dividers; the category picker with 56 pt tiles and an emerald ring plus check on the chosen one; Quick add with a large amount and a field-style date row; Needs review rows with tiles; choice sheets (filter, review) in an outlined card. New shared pieces: `IconTile`, `SecondaryButton`, `FieldButton`. Sheets now draw their text in Rubik.
- **Stage 3 (2026-11-12), Bills and Insights:** gold Bills hero with an outlined bar, outlined status pills that always carry a word, pastel kind tiles, outlined bill form; outlined budget bars (`OutlinedBar`), donut with ink outlines, outlined month bars; the AI tips card in gold with ink text; outlined chat bubbles; outlined confirm and amount sheets. New shared pieces: `HeaderIconButton`, `OutlinedBar`, `AppCard(shadow:)`.
- **Stage 4 (2026-11-12), Start and More:** the logo in the app (`HalalaLogo`, drawn from `docs/brand/logo.svg`: outline and shadow in the line colour, so it shows in dark mode) on the launch, lock and sign-in screens; placeholder cards shaped like list rows while data loads; outlined back button on every sub-screen; settings rows with pastel tiles, 2 pt dividers and outlined switches; Sign out as a white pill; bank account rows with a tile per kind; gold numbered steps on SMS capture; the guide sheet with a gold step pill, outlined dots and pill buttons; a pink warning card and outlined red button on Delete my account; empty and failed states with a sand tile; choice sheets as one outlined card per option, with a radio ring only when one option is the current one. Apple's Sign in with Apple button is left as Apple draws it.
- **Still in the old shapes:** screens whose own widgets were not restyled yet pick up the new colours, cards and buttons but keep their old layout details. The colour table, typography and radius notes below are the pre-rebrand description and are replaced stage by stage.
- **Screenshots:** `flutter test test/screens_snapshot_test.dart` writes every tab (light, dark, English, Arabic) to `app/build/snapshots/`.

## Principles
- Looks like it shipped with iOS: Cupertino widgets, large titles, grouped lists, bottom sheets, swipe actions, haptics (light on confirm, medium on warning).
- Light and dark mode both first class. Respect Dynamic Type up to accessibility sizes without clipping.
- One screen, one job. Amounts are the loudest element.
- RTL-safe: mirrored layout in Arabic, but amounts, card digits and SAR codes stay left-to-right inside Arabic text.

## Color
Use system semantic colors where possible so dark mode is free; brand accents are few.
| Role | Light | Dark |
|---|---|---|
| Accent (buttons, links, selected tab) | `#0A7E6B` (deep teal-green) | `#3CC4A8` |
| Background (grouped) | iOS `systemGroupedBackground` | same |
| Positive / income | `#1E8E3E` | `#4CD07A` |
| Warning (budget 80%) | `#B26A00` | `#FFB340` |
| Danger (over budget, overdue) | `#C5221F` | `#FF6B66` |
| Neutral text | `label`, `secondaryLabel` | same |
Category colors come from a fixed 12-color palette checked for contrast on both backgrounds; never rely on color alone (always icon + label).

## Typography
- System font: SF Pro for Latin, SF Arabic for Arabic (automatic). No custom fonts.
- Amounts: tabular numerals, semibold. Large title 34, title 22, body 17, caption 13 (scales with Dynamic Type).
- SAR shown as "SAR 1,234.50" in English and "1,234.50 ر.س" in Arabic. Western digits in both.
- Time 24h, e.g. `19:34`. Dates "Fri 30 Oct" / "الجمعة 30 أكتوبر".

## Spacing and shape
- 4 pt grid; screen margins 16 pt (20 on large phones); list row min height 44 pt, touch targets 44 pt.
- Corner radius 12 for cards/sheets, 10 for chips. Hairline separators, no heavy shadows.

## Tone
Plain, specific, no cheerleading. "Dining is 38% above your 3-month average (SAR 1,240 vs 898), mostly 4 merchants." Errors say what happened and what to do next. Never shame on overspending.

## References
1. Apple Wallet / Apple Card spending summary: category ring, weekly/monthly view, restrained color.
2. Copilot Money (iOS): clean transaction list, swipe categorization, budget bars.
3. Apple Health summary cards: large number plus small trend, consistent card pattern.

## Component set (all under `app/lib/ui/`)
`AmountText`, `TxnRow` (merchant, category chip, amount, time), `CategoryChip`, `BudgetBar`, `SpendRing`, `ObligationRow` (status pill), `SectionCard`, `EmptyState`, `ErrorState`, `SkeletonRow`, `ConfirmSheet`, `SegmentedHeader`. Built on `CupertinoApp`, `CupertinoTabScaffold`, `CupertinoSliverNavigationBar`, `CupertinoListSection`, `CupertinoContextMenu`, `showCupertinoModalPopup`. Material is not used except where a Cupertino widget is missing (date range picker fallback).

## Accessibility
VoiceOver labels on every amount ("Spent 49 riyals at Extra, 20:22"), 4.5:1 contrast, reduce-motion respected, charts have a table alternative.
