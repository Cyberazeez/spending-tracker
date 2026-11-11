# Halala brand files

Owner decision 2026-11-11. Palette and usage rules: `docs/04-design-brief.md`, section "Brand".

| File | What it is |
|---|---|
| `logo.svg` | The logo: هللة in emerald with ink outline, hard shadow and gold coins, transparent background. |
| `app-icon.svg` | Square app icon, full detail. Used for the 60 pt, 76 pt, 83.5 pt and 1024 px iOS icons. |
| `app-icon-small.svg` | Small-size cut: no shadow, bigger letters. Used for the 20 pt, 29 pt and 40 pt iOS icons. |

## Rebuilding the iOS icons
Render each SVG at the pixel size of every entry in `AppIcon.appiconset/Contents.json` (point size times scale) and save as PNG **without an alpha channel** (App Store Connect rejects a 1024 px icon with alpha). The background is square; iOS rounds the corners itself.

## Origin of the letter shapes
The outlines started from the typeface Rakkas (SIL Open Font License 1.1, which allows modified use in a logo) and were changed: slanted, the two lams made taller, and the dots of the ة replaced by two coins. No font file is shipped for the logo.

## Known limit
At 29 px a four-letter word is hard to read. Those sizes only appear in Settings and notifications.
