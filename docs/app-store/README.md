# App Store screenshots

## Current set: style A "Paper & pastel" (owner's pick 2026-11-18)

Five screenshots, 1320x2868, English and Arabic, plus the product page header (21:9, 3840x1646, App Store Connect
creative assets). Pastel backgrounds, serif headline (Fraunces in English, El Messiri in Arabic), the app's real
screens in a phone with one card popping out. Mockups and the other directions: Artifact "Halala App Store visuals".

1. Screens: the STORE_SHOTS test below (step 1 of the older set).
2. From the repo root: `node docs/app-store/store-shots.cjs` (cloud session: prefix `NODE_PATH=$(npm root -g)`).
   Output: `docs/app-store/out/a/<lang>/01.png` to `05.png` and `header-3840x1646.png` (RGB, no alpha).
3. Order: 1 Every halala, tracked (Home) · 2 Your bank texts (Activity) · 3 At a glance (widget, drawn, not
   captured) · 4 Bills · 5 Insights. Upload English to the English listing and Arabic to the Arabic one.

Fonts in `fonts/` are OFL (licences beside them). No fake reviews, ratings or awards on any screenshot.

## Older set (rebrand stage 6, 2026-11-13)

Made from the app's own screens with fake sample data (never the owner's account), rebrand stage 6 (2026-11-13).

1. Screens: in `app/`, run `flutter test test/screens_snapshot_test.dart --dart-define=STORE_SHOTS=true --plain-name "store screenshot"`.
   It draws Home, Activity, Bills and Insights in light mode, English and Arabic, at 1206x2622 with an iPhone's
   safe areas, into `app/build/snapshots/store/`.
2. Frame: from the repo root, run `node docs/app-store/frame.mjs` (needs Playwright with Chromium; in a cloud
   session prefix `NODE_PATH=$(npm root -g)`). It adds the captions from `docs/09-app-store-listing.md` (section 8)
   and writes JPEGs (no alpha channel) to `docs/app-store/out/<size>/<lang>_<n>.jpg` for 1206x2622, 1179x2556 and
   1320x2868.
3. Upload the size App Store Connect asks for, English to the English listing and Arabic to the Arabic one, in the
   order 1 to 4.

`out/` is not committed (generated, about 5 MB). The status bar area at the top is empty paper: the screens are
drawn by the app, not captured on a phone.

Not made (would need a real phone or new screens): the widget on a home screen (plan item 6) and a separate
budgets screenshot (plan item 5; the budget shows on Home and Insights).
