# Rebrand stage 4 (Start and More) Plan

**Goal:** Give the start screens (launch, lock, sign in, create account, forgot and reset password) and the More tab with everything opened from it the Emerald look of the mockups (boards Loading, Lock, Login, Signup, Error, More, Accounts, Capture, Guide, Delete, NoticeSheet, ChoiceSheet).

**Spec:** `docs/superpowers/specs/2026-11-11-rebrand-design.md`, stage 4. Handoff: `rebrand-handoff.md`.

## Constraints
- Restyle only. No backend, schema, routing, l10n-key or behaviour change. Gate before the PR: `git diff origin/main --stat -- app/lib/l10n app/lib/router.dart app/lib/core supabase` is empty; test changes are finder updates plus new tests.
- Reuse `AppTokens`, `outlineOf`, `hardShadowOf`, `IconTile`, `HeaderIconButton`, `SecondaryButton`. Text on cards `accentText`; text and icons on gold, mint or category fills `onTint`.
- Keep stage 1's decisions: tab labels always visible, Home keeps the ring, sheets keep the paper fill.
- 44 pt tap targets, no overflow at 2x text on a 360 pt phone, Arabic mirrors the layout.

## Tasks
1. **Shared pieces** (`app/lib/ui/`)
   - New `halala_logo.dart`: the logo drawn from the path in `docs/brand/logo.svg` (no new package). Outline and shadow in `line` (ink in light, paper in dark, so it shows on the dark page), letters in `accent`, coins in `gold`. Coins are separate shapes so stage 5 can drop them.
   - `appNavBar`: the back button becomes an outlined 40 pt square with a (3, 4) shadow (`HeaderIconButton`), chevron mirrored in Arabic, label from Flutter's own `backButtonLabel`, same `popOrHome` action. Key `nav-back`; tests that found `CupertinoNavigationBarBackButton` find the key.
   - `SettingsGroup` / `SettingsRow`: 38 pt `IconTile` with an `onTint` icon, palette pastels instead of the old blue, orange and purple, title 15/700, value muted 14/500, 2 pt `bar` dividers, group title 14/700. Danger rows: pink tile, title in `danger`.
   - `AppField` label: 13/700 in `text`.
   - `SkeletonSliver`: outlined cards with `bar` blocks (same heights).
   - `EmptyState`: icon in a 64 pt `IconTile` (sand), title 20/800.
   - Choice sheet: one outlined card per option; when some option is selected, every option gets a ring and the selected one is an emerald circle with a check and a hard shadow. Lists with no selection (review actions) show no ring.
   - `PrimaryButton(icon:)`, `SecondaryButton(icon:)`: optional leading icon.
2. **Start screens**: launch skeleton and lock with the logo; lock card with a gold lock tile. Sign in with the logo, start-aligned 26/800 title, 15/700 links, `or` divider with 2 pt lines. Create account: outlined checkbox (still `CupertinoCheckbox`). Forgot and reset password pick up the fields and buttons.
3. **More screens**: More, account, profile, security, privacy (through the shared rows), bank accounts rows with tiles, SMS capture (gold numbered steps, guide as a secondary button with icon), guide sheet (ink top border, gold step pill, outlined picture box, outlined dots, Back and Next as pill buttons; keys `guide-pages`, `guide-next`, `guide-skip` kept), delete my account (pink warning card, danger pill with outline and shadow, label colour from `onDanger`).
4. **Snapshots and docs**: add the screens above to `screens_snapshot_test.dart` (light and dark, English and Arabic), look at every picture; brief 04 Brand section, spec status line, handoff table. `flutter analyze`, `flutter test`, `dart format`, ship-review, PR.

## Not built (needs the owner: flow, content or Apple rules)
- **More:** the mockup's account card at the top and its regrouped rows ("Categories and rules", "Bank accounts" on More). The current order and groups stay.
- **Lock:** the subtitle "Use Face ID to open Halala" and "Use passcode" (new text and a new flow).
- **Capture:** the mint "Working" card and per-bank "Connected" pills (the app does not work out such a state), "Send a test message".
- **Sign in with Apple:** Apple's own button stays as it is. Apple's rules allow black, white and white-outline styles; a custom outline and hard shadow could be questioned in review.
- **Notice sheet icon:** the mockup's icon above the title needs a meaning per call (success or failure); not added.
- **Sheets:** white fill (stage 1 kept paper).

## What was built differently (2026-11-12)
- **Sign out** is a white pill under the groups (as in the mockup) instead of a red row in its own group; same action.
- **Create account checkbox:** still the native `CupertinoCheckbox` (outlined, emerald when ticked), drawn 1.4x so it is close to the mockup's 24 pt box.
- **Guide sheet, first page:** with no Back or Skip, Next takes the full width.
- **Choice sheets** with long lists (the bank picker) are taller now, one card per option; they scroll as before.
- **Lock screen:** the logo sits above the scrim so it is not dimmed.
- **Snapshots:** the guide pictures sometimes are not decoded yet when the snapshot is taken (an empty picture box in a few of the pictures); the app itself is unaffected.

## Owner's TestFlight fixes (2026-11-12)
- **Launch screen** (iOS storyboard, shown while the app starts and Face ID asks): was white with no logo. Now the page colour (also behind the Flutter view in `Main.storyboard`, so no white flash before the first frame) (`LaunchBackground`, paper in light, ink in dark) with the logo in the middle (`LaunchImage`, rendered from `HalalaLogo`, a dark-mode copy with the paper outline).
- **Lock screen:** no placeholder cards and no card: only the logo, the gold lock tile with "Locked", the failure line and Unlock, centred. `LaunchSkeleton` is gone (it had no other use).
- **Bills, next month:** the folded card no longer has its own arrow; the heading's down arrow is the only one.
