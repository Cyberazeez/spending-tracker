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

## Owner's TestFlight round (2026-11-12)
1. **Pill bars slide** (`ui/sliding_pill.dart`, `SlidingPill`): every `PillSegments` (Bills Upcoming / Overdue / History, the bill form's type, amount and repeat pickers, Quick add) now slides its emerald pill like the tab bar. Reduce Motion: fade.
2. **Every button presses** (`PressShadow` in `ui/press.dart`: a small 2 x 3 hard shadow and the press): Activity filter chips, Home's attention chip, Home's bill cards (now outlined, 4 x 5 shadow), amount-sheet suggestion chips, AI chat prompt chips and send button, AI tips pills, the close buttons of every sheet (now all outlined), the bill form's minus / plus buttons. Rows inside cards (More, Account, Privacy with "Delete my account") light up while held (`PressHighlight`): a row has no shadow of its own to sink into. Text links keep the system fade.
3. **Switches** (`appSwitch`): a 2 x 3 hard shadow under the track that the switch presses into; the thumb keeps its own slide.
4. **Coin drop at launch:** the lock screen waits until the coins land (`lockPromptDelay`, 0.9 s) before asking for Face ID, so the drop is seen; Unlock tapped earlier asks at once. Reduce Motion: asks straight away, no drop.
5. **Home budget ring** and 6. **Bills progress bar** (`ui/grow_in.dart`, `GrowIn`): fill from empty with a small overshoot (the ring's percentage counts up with it) each time the screen comes into view, not only the first time it was built (which happened behind the lock screen, unseen). Reduce Motion: shown at the value at once.

Not changed: field-style pickers (date row, bank and type pickers in the account sheet), the category tiles and list rows of Activity, which are rows or fields rather than buttons.
