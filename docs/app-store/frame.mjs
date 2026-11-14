// Frames the App Store screenshots: paper background, caption on top (from docs/09-app-store-listing.md, section 8),
// the screen in an outlined card with a hard shadow. Input: app/build/snapshots/store/{en,ar}_{0..3}.png from
// `flutter test test/screens_snapshot_test.dart --dart-define=STORE_SHOTS=true --plain-name store` (run in app/).
// Output: docs/app-store/out/<size>/<lang>_<n>.jpg (JPEG, so no alpha channel; App Store Connect rejects alpha).
// Run from the repo root: node docs/app-store/frame.mjs   (needs Playwright with Chromium)
import { mkdirSync, readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
const { chromium } = createRequire(import.meta.url)("playwright");

const root = new URL("../../", import.meta.url);
const file = (p) => new URL(p, root);
const b64 = (p) => readFileSync(file(p)).toString("base64");

// Upload sizes: 1206x2622 and 1179x2556 (the slots App Store Connect offers for 6.1-6.3 inch), 1320x2868 (6.9 inch).
const SIZES = [[1206, 2622], [1179, 2556], [1320, 2868]];
const CAPTIONS = {
  en: ["See where your money goes", "Every bank SMS, captured", "Never miss a bill", "Understand your month"],
  ar: ["اعرف أين يذهب مالك", "كل رسالة بنك، تُلتقط تلقائيًا", "لا تفوّتك فاتورة", "افهم شهرك"],
};
const font = (w, n) =>
  `@font-face{font-family:Rubik;font-weight:${w};src:url(data:font/ttf;base64,${b64(`app/assets/fonts/Rubik-${n}.ttf`)})}`;

function page(lang, i, w, h) {
  const shot = b64(`app/build/snapshots/store/${lang}_${i}.png`);
  const u = w / 1206; // everything is laid out for 1206 px and scaled
  return `<!doctype html><html lang="${lang}" dir="${lang === "ar" ? "rtl" : "ltr"}"><meta charset="utf-8"><style>
${font(800, "ExtraBold")}
html,body{margin:0;width:${w}px;height:${h}px;background:#F0F5E6;overflow:hidden}
body{display:flex;flex-direction:column;align-items:center;font-family:Rubik}
h1{margin:${150 * u}px ${70 * u}px ${80 * u}px;font-size:${92 * u}px;line-height:1.15;font-weight:800;color:#0D1F17;text-align:center}
.shot{width:${930 * u}px;border:${8 * u}px solid #0D1F17;border-radius:${64 * u}px;box-shadow:${14 * u}px ${18 * u}px 0 #0D1F17;overflow:hidden;background:#F0F5E6}
.shot img{display:block;width:100%}
</style><h1>${CAPTIONS[lang][i]}</h1><div class="shot"><img src="data:image/png;base64,${shot}"></div></html>`;
}

const browser = await chromium.launch();
for (const [w, h] of SIZES) {
  const dir = file(`docs/app-store/out/${w}x${h}/`);
  mkdirSync(dir, { recursive: true });
  const p = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 1 });
  for (const lang of ["en", "ar"]) {
    for (let i = 0; i < 4; i++) {
      await p.setContent(page(lang, i, w, h));
      await p.evaluate(() => document.fonts.ready);
      await p.screenshot({ path: fileURLToPath(new URL(`${lang}_${i + 1}.jpg`, dir)), type: "jpeg", quality: 92 });
    }
  }
  await p.close();
}
await browser.close();
console.log("framed", SIZES.length * 8, "screenshots into docs/app-store/out/");
