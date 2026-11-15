# Halala brand files

Owner decision 2026-11-11. Palette and usage rules: `docs/04-design-brief.md`, section "Brand".

| File | What it is |
|---|---|
| `logo.svg` | The logo: هللة in emerald with ink outline, hard shadow and gold coins, transparent background. |
| `app-icon.svg` | Square app icon, full detail. Used for the 60 pt, 76 pt, 83.5 pt and 1024 px iOS icons. |
| `app-icon-small.svg` | Small-size cut: no shadow, bigger letters. Used for the 20 pt, 29 pt and 40 pt iOS icons. |

## In the home screen widget (2026-11-15)
`app/ios/SpendingWidget/` carries its own copies, added to the widget target by `scripts/ios_widget_resources.rb`:
- `HalalaLogo@2x.png` / `@3x.png`: `logo.svg` with paper letters instead of emerald (it sits on the emerald tile), 60 pt wide, rendered to PNG with a transparent background.
- `Rubik-Bold.ttf` and `Rubik-ExtraBold.ttf`: the app's files with their name table fixed. The app's static instances all carry the internal name "Rubik-Light", which Flutter ignores but iOS uses to register fonts, so two of them would collide. The widget copies are named `Rubik-Bold` / `Rubik-ExtraBold` (fontTools, name IDs 1-6, 16, 17).
- `SaudiRiyal-Bold.ttf`: the riyal sign, unchanged (PostScript name `saudi_riyalbold`).
All three fonts are listed under `UIAppFonts` in the widget's `Info.plist`.

## Rebuilding the iOS icons
Render each SVG at the pixel size of every entry in `AppIcon.appiconset/Contents.json` (point size times scale) and save as PNG **without an alpha channel** (App Store Connect rejects a 1024 px icon with alpha). The background is square; iOS rounds the corners itself.

## Origin of the letter shapes
The outlines started from the typeface Rakkas (SIL Open Font License 1.1, which allows modified use in a logo) and were changed: slanted, the two lams made taller, and the dots of the ة replaced by two coins. No font file is shipped for the logo.

## Known limit
At 29 px a four-letter word is hard to read. Those sizes only appear in Settings and notifications.
