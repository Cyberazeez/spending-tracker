# Rebrand: Emerald, outlined cards, hard shadows

Status: approved by the owner 2026-11-11 ("Go with recommendations": bundle Rubik, derive dark mode, start after PR #103). Stage 1 built (plan: `docs/superpowers/plans/2026-11-11-rebrand-stage1.md`). Stage 2 built (plan: `docs/superpowers/plans/2026-11-12-rebrand-stage2.md`). Stage 3 built (plan: `docs/superpowers/plans/2026-11-12-rebrand-stage3.md`). Stage 4 built (plan: `docs/superpowers/plans/2026-11-12-rebrand-stage4.md`). Stage 5 built (plan: `docs/superpowers/plans/2026-11-12-rebrand-stage5.md`). Approved in chat (2026-11-11): the logo, the Emerald palette and the look of the mockups ("I like the rebrand, use it"). Mockups: https://claude.ai/artifact/SKu3Y19HmGqcn19UDyb1KS (31 boards, private to the owner). Logo and palette: `docs/04-design-brief.md`, section "Brand", and `docs/brand/`.

## Goal
Make the whole app look like the mockups: paper background, white cards with a 2.5 pt ink outline and a hard offset shadow (no blur), a flat emerald hero, gold highlights, pastel category tiles, pill buttons that press into their shadow. English and Arabic, light and dark.

## What does not change
- No backend, schema, function or SMS-parsing change. No change to what any number means.
- Every current screen, feature, text key and navigation path stays. This is a restyle, not a redesign of flows.
- Cupertino stays for navigation, back swipe, haptics and text input. Sheets keep the shared `SheetFrame`.
- The riyal sign keeps using the bundled `SaudiRiyal` font (the mockups write "SAR" only because the canvas has no such font).

## Design layer (`app/lib/ui/`)
Most of the look lives in the shared layer, so stage 1 changes every screen at once.

- **Tokens** (`tokens.dart`, `theme.dart`): replace the colour values, keep the names where the role is the same so call sites do not change.

| Token | Light | Dark |
|---|---|---|
| `bg` | `#F0F5E6` paper | `#0D1F17` |
| `card`, `tab` | `#FFFFFF` | `#173326` moss |
| `text` | `#0D1F17` ink | `#F0F5E6` |
| `muted` | `#45564B` | `#A9BBAF` |
| `accent` (fills, buttons) | `#00A86B` emerald | `#3FD79B` mint |
| `onAccent` | `#0D1F17` | `#0D1F17` |
| new `accentText` (links, income amounts) | `#00704A` | `#3FD79B` |
| new `line` (outlines, shadows) | `#0D1F17` | `#F0F5E6` |
| new `gold` | `#FFC93C` | `#FFC93C` |
| `danger` | `#D11A3F` | `#FF9DB0` |
| `bar` (tracks) | `#DCE5CC` | `#2B4C3D` |

  `heroFrom` / `heroTo` are removed (the hero is flat emerald). Warning uses gold with ink text; "ok" uses mint with ink text. Radii: card 20, hero 26, sheet 28, tile 13, pills fully round. Outline 2.5 pt (2 pt on small elements). Shadow offset 4 x 5 pt (3 x 4 on buttons), no blur.
- **Category group colours** (`group_style.dart`): food gold `#FFC93C`, transport sky `#9CC4FF`, home and bills coral `#FFA574`, lifestyle lilac `#CDB4FF`, subscriptions lilac, health and care pink `#FF9DB0`, money and fees mint `#3FD79B`, family aqua `#9BE7E0`, horse and other sand `#DDE3CC`. Tiles are a filled rounded square with an ink outline and an ink icon. Never colour alone: icon and label stay.
- **Components:** `AppCard` gets the outline and shadow (with a flat variant for nested boxes). New `AppButton` (primary, secondary, danger, text) replaces the ad-hoc `CupertinoButton` styling; new `AppChip` / status pill; `IconTile`; `SegmentedPill`. `PillTabBar`: outlined pill, the active tab is an emerald pill with its label. `SheetFrame`: ink top border, 28 pt top corners. Form fields: outlined, 14 pt radius, 50 pt tall. Skeleton blocks use `bar`.
- **Typeface:** see open decision 1.

## Stages (one pull request each, stop for the owner after each)
1. **Design layer and Home.** Tokens, the components above, tab bar, sheet frame, fields; Home hero (flat emerald, gold budget bar), week bars, share bar, chips, welcome card. Every other tab picks up the new cards, buttons and colours through the shared layer; anything that looks broken there is fixed in this stage, anything that only looks plain waits for its own stage.
2. **Activity.** List rows and day groups, search and filter chips, transaction detail, quick add, needs review, filter sheet, category picker.
3. **Bills and Insights.** Gold bills hero, status pills, bill sheet, add-a-bill tiles, confirm sheets; tip card, donut with outlines, budget bars, amount sheet, AI chat bubbles.
4. **Start and More.** Launch skeleton and lock with the logo, sign in, create account, forgot and reset password, More groups, account pages, bank accounts, SMS capture and the guide sheet, delete account, notice and choice sheets.
5. **Motion.** Buttons and cards press into their shadow and spring back; sheets rise with a small overshoot; the tab pill slides; the logo's coins drop on launch. All of it becomes a plain fade when Reduce Motion is on.
6. **Outside the Flutter app.** Home screen widget (Swift, cannot be compiled in cloud sessions: first compile is the Codemagic build), emails (`docs/email-design/`, `_shared/email_layout.ts`), website (`site/`), App Store screenshots.

## Accessibility
- Contrast checked for the palette: ink on emerald 5.6:1, deep emerald on paper 5.5:1 and on white 6.1:1, tomato on white 5.3:1 and on paper 4.8:1, mint on moss 7.4:1, paper on moss 12.3:1, ink on gold 11.2:1. Muted text is checked in the token test.
- Tap targets stay 44 x 44; the existing `a11y_guidelines_test.dart` and the 2x text test must keep passing.
- Income is deep emerald with a plus sign, spending has a minus sign, status pills carry a word: nothing relies on colour alone.

## Testing
- Update `tokens_test.dart` to the new values and keep its contrast assertions (text and muted on card and on bg, both modes, plus `accentText` on card and bg).
- Widget tests for each new component (outline present, shadow offset, pressed state, right-to-left).
- The whole existing test suite must pass; tests that assert old colours or the gradient are updated in the stage that changes them.
- Flutter is not installed in cloud sessions by default. Stage 1 starts by installing the SDK version CI uses (3.47.9) in the session; if that fails, CI on the pull request is the test run and the PR says so.
- Not testable here: the look on a real iPhone, the widget, VoiceOver order. Each stage ends with a TestFlight build for the owner to look at.

## Risks
- A one-step token change touches every screen. Stage 1 is the largest and the riskiest; screenshots of all five tabs in both languages and both modes go in its PR.
- Outlines and offset shadows need room: dense rows (Activity, More) may need slightly more spacing, which shows fewer rows per screen.
- Shadows on the trailing side must not be clipped by scroll views and must mirror correctly in Arabic (the mockup keeps the shadow to the right and down in both directions).

## Open decisions for the owner
1. **Typeface.** The mockups use Rubik (one family for Arabic and Latin, SIL Open Font License). Recommended: bundle Rubik in the app (four weights, roughly 1 MB) so the app matches the mockups. Alternative: keep the system font (SF Pro / SF Arabic), which is lighter and more "iOS" but less chunky.
2. **Dark mode.** Only Home was mocked in dark. Recommended: derive the rest from the dark tokens above and review them on the TestFlight build of each stage.
3. **Order.** Recommended: merge the icon pull request (#103) first, then stage 1 on a fresh branch.
