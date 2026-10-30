# 04-design-brief

A calm, native-feeling iPhone app. Numbers first, no decoration.

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
