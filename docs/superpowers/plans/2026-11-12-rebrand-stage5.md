# Rebrand stage 5 (Motion) Plan

**Goal:** The motion of the spec: buttons and cards press into their shadow and spring back; sheets rise with a small overshoot; the tab pill slides; the logo's coins drop on launch. All of it becomes a plain fade (or stays still) when Reduce Motion is on.

**Spec:** `docs/superpowers/specs/2026-11-11-rebrand-design.md`, stage 5. Handoff: `rebrand-handoff.md`.

## Constraints
- Motion only: no layout, colour, text, routing or behaviour change. Gate: every snapshot of `screens_snapshot_test.dart` is pixel-identical to the one before the stage (settled screens look the same); `git diff --stat -- app/lib/l10n app/lib/router.dart app/lib/core supabase` is empty.
- A tap fires exactly when it did (on release, through the same button or gesture detector), never after an animation.
- Reduce Motion (`MediaQuery.disableAnimations`): nothing slides, bounces or moves.

## Built
1. **Press** (`ui/press.dart`, `Pressable`): watches the pointer only. While a finger is down the box moves by its shadow offset and the shadow shrinks to nothing (it sinks into it); on release it springs back with a small bounce past rest (`pressSpring`). A very quick tap still shows the full press. A finger that moves more than the touch slop (a scroll) lets go at once. Disabled buttons do not move. Reduce Motion: the box fades to 60% while held instead. Used on `PrimaryButton`, `SecondaryButton`, `HeaderIconButton` (title-bar and back buttons), the sheet buttons, the delete-account button, choice-sheet options and the cards that open something (`AppCard(pressable: true)`: Home's shortcut rows, the folded welcome card, the overdue notice and the folded next-month card on Bills). The moving buttons no longer dim on press (`pressedOpacity: 1`).
2. **Sheets** (`ui/app_sheet.dart`, `showAppSheet`): every bottom sheet now opens through one route, the same as the system one (root navigator, dimmed barrier that closes it, elevated level) but rising in 340 ms (the system takes 335) about 3% past its place before settling, with a strip of the page colour under it so no gap shows. Closing: ease-in, no bounce. Reduce Motion: fades in place.
3. **Tab pill** (`ui/pill_tab_bar.dart`): one emerald pill slides to the tapped tab in 320 ms, about 3% past it and back; right-to-left in Arabic. Reduce Motion: the pill fades out under the old tab and in under the new one.
4. **Coins** (`ui/halala_logo.dart`, `dropCoins`): on the lock and sign-in screens the two coins hop up and fall back into place with a bounce (1.1 s, the second coin a moment after the first). They never leave the picture, so the launch image (coins in place) hands over without a jump. On a phone with Face ID on, the Face ID prompt covers most of the drop on the lock screen; it is fully visible on sign-in and after a failed unlock is retried. Reduce Motion: no drop.

## Not built
- **Launch screen** (iOS storyboard) cannot animate; the coins drop starts on the first Flutter screen.
- **Cards with buttons inside** (the AI tips card) do not press as a whole, so pressing one of their buttons does not sink the card too.
