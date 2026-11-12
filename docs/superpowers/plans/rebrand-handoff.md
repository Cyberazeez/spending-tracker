# Rebrand handoff (2026-11-12)

For the next session that picks up the Halala rebrand. Read the spec first: `docs/superpowers/specs/2026-11-11-rebrand-design.md`.

## Where it stands
| Stage | What | State |
|---|---|---|
| 1 | Design layer and Home | Merged (PR #104). Plan: `2026-11-11-rebrand-stage1.md` |
| 2 | Activity | Merged (PR #105). Plan: `2026-11-12-rebrand-stage2.md`. Owner tested on TestFlight: all pass |
| 3 | Bills and Insights | Merged (PR #106). Plan: `2026-11-12-rebrand-stage3.md`. Owner has not reported a TestFlight check yet |
| 4 | Start and More | Built, in review. Plan: `2026-11-12-rebrand-stage4.md` |
| 5 | Motion | **Next. Wait for the owner's go.** |
| 6 | Widget, emails, website, App Store screenshots | Not started |

## Owner's rules for this work
- One stage per pull request, in the spec's order. Stop after each stage and wait for the owner's go.
- Restyle only: no backend, schema, routing, text or behaviour change. Anything in a mockup that would change a flow is listed in the PR as "not built" for the owner to decide.
- Start each stage from the latest `main` on the session's assigned branch.
- Use `app/lib/ui/tokens.dart` (`outlineOf`, `hardShadowOf`, `AppTokens`). Text on cards: `accentText`, never `accent`. Text and icons on gold, mint or category fills: `onTint`.
- Keep stage 1's decisions: tab labels always visible, Home keeps the budget ring, sheets keep the paper fill.
- Before each PR: `flutter analyze` clean, `flutter test` all passing, look at the snapshots, run `ship-review`, fill in the PR template honestly.
- Owner wants short replies, simple numbered steps, and facts checked before they are stated.

## Shared pieces built so far (reuse them)
`AppCard` (outline, hard shadow, `flat`, `shadow:` offset), `HalalaLogo`, `appSwitch`, `PrimaryButton`, `SecondaryButton` (`icon:`), `FieldButton`, `AppField` (`large:`), `IconTile` (`outline:`), `HeaderIconButton`, `OutlinedBar`, `PillSegments`, `StatusPill`, `RowsCard`, `RankCircle`, `swipeLabelColor` / `onDanger` (white or ink on a red fill, whichever reads better). Sheets set their text to Rubik explicitly (`appFont`, `riyalFont` fallback) because they use `inherit: false`.

## Tools in a cloud session
- Flutter is not preinstalled: download `https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.9-stable.tar.xz` (about 1.5 GB), unpack into the scratchpad, put `flutter/bin` on PATH, run `flutter pub get` in `app/`. CI checks `dart format` too.
- Snapshots: `flutter test test/screens_snapshot_test.dart` writes PNGs to `app/build/snapshots/` (tabs, plus the stage 2 and 3 sub-screens and sheets, light and dark, English and Arabic). Add each stage's screens to it. Test fonts other than Rubik render as boxes, which is how the sheet-font bug was found.
- Mockups: https://claude.ai/artifact/SKu3Y19HmGqcn19UDyb1KS (private to the owner, made from the Design type). Read boards with the Artifact tool, `action: "read"` with `paths: ["project/<Board>.dc.html"]`. Stage 4 boards: Loading, Lock, Login, Signup, Error, More, Accounts, Capture, Guide, Delete, NoticeSheet, ChoiceSheet.

## Waiting on the owner
- Mockup items not built because they change flows: transaction detail screen, the bigger filter sheet, Add / Not a purchase buttons on review cards, floating add button (stage 2); bill detail sheet with fields, "Add a bill" start tiles, "82%" / "Over" pills on budget rows (stage 3); More's account card and regrouped rows, lock subtitle and "Use passcode", Capture's "Working" card and per-bank pills, the notice sheet icon, a restyled Apple button (stage 4).
- TestFlight check of stage 3.

## Other open items (outside the rebrand)
- App Store submission is on hold until the rebrand and new screenshots are done. Screenshots must be 1179x2556 or 1206x2622 for the size slot the owner's App Store Connect shows; the owner's Pro Max takes 1290x2796, so resize.
- Arabic store listing text (`docs/09-app-store-listing.md`), then submit.
- Lawyer review of privacy policy, terms of use and the Mumbai data location before publishing.
- Apple Paid Apps agreement (owner).
- Test the three untested emails (change email, reauthentication code, email changed) on a throwaway account; delete throwaway accounts afterwards.
- AI reading test with a real SMS from an unknown bank.
- Google sign-in on hold. The deploy workflow shows a Node 20 notice.
