// App Store screenshots, style "A · Paper & pastel" (owner's pick 2026-11-18), and the product page header (21:9),
// English and Arabic. The phones show the app's real screens with fake sample data, from the STORE_SHOTS test.
// 1. in app/: flutter test test/screens_snapshot_test.dart --dart-define=STORE_SHOTS=true --plain-name "store screenshot"
// 2. from the repo root: node docs/app-store/store-shots.cjs   (Playwright + Chromium; cloud: NODE_PATH=$(npm root -g))
// Writes docs/app-store/out/a/<lang>/0<1-5>.png (1320x2868) and header-3840x1646.png. Headlines: Fraunces (English),
// El Messiri (Arabic), body Rubik; all OFL, in docs/app-store/fonts.
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const ROOT = path.resolve(__dirname, '../..');
const FONTS = path.join(__dirname, 'fonts');
const OUT = path.join(__dirname, 'out', 'a');
const SNAP = path.join(ROOT, 'app/build/snapshots/store');
const LOCAL = { 'SaudiRiyal-Bold.ttf': path.join(ROOT, 'app/assets/fonts/SaudiRiyal-Bold.ttf'), 'app-icon.svg': path.join(ROOT, 'docs/brand/app-icon.svg') };
const f = (n) => 'file://' + (LOCAL[n] ?? path.join(FONTS, n));

const INK = '#0D1F17';
const R = '<span class="sar">⃁</span>';

const css = `
@font-face{font-family:Fraunces;font-weight:600;src:url(${f('fraunces-latin-600-normal.woff2')})}
@font-face{font-family:Fraunces;font-weight:800;src:url(${f('fraunces-latin-800-normal.woff2')})}
@font-face{font-family:Messiri;font-weight:600;src:url(${f('el-messiri-arabic-600-normal.woff2')})}
@font-face{font-family:Messiri;font-weight:700;src:url(${f('el-messiri-arabic-700-normal.woff2')})}
${[400, 500, 700, 800].map((w) => `@font-face{font-family:Rubik;font-weight:${w};src:url(${f(`rubik-latin-${w}-normal.woff2`)});unicode-range:U+0000-00FF,U+2000-206F,U+20AC}
@font-face{font-family:Rubik;font-weight:${w};src:url(${f(`rubik-arabic-${w}-normal.woff2`)});unicode-range:U+0600-06FF,U+0750-077F,U+FB50-FDFF,U+FE70-FEFF,U+200C-200E}`).join('\n')}
@font-face{font-family:SaudiRiyal;font-weight:700;src:url(${f('SaudiRiyal-Bold.ttf')})}
*{box-sizing:border-box}
body{margin:0;font-family:Rubik,sans-serif;color:${INK}}
.sar{font-family:SaudiRiyal;font-weight:700;font-size:.82em}
.shot{width:440px;height:956px;position:relative;overflow:hidden}
.head{position:absolute;left:0;right:0;top:76px;display:flex;flex-direction:column;align-items:center;gap:14px;padding:0 34px;text-align:center}
h1{margin:0;font-family:Fraunces,serif;font-weight:800;font-size:50px;line-height:1.02;letter-spacing:-1px}
[dir=rtl] h1{font-family:Messiri,serif;font-weight:700;font-size:50px;line-height:1.25;letter-spacing:0}
.sub{margin:0;font-size:17px;line-height:1.45;color:#45564B;max-width:350px;text-wrap:balance}
.bub{position:absolute;border-radius:50%;border:2px solid ${INK}}
.abs{position:absolute}
.phone{width:300px;height:620px;padding:10px;border-radius:50px;background:${INK};box-shadow:0 30px 60px rgba(13,31,23,.28)}
.screen{width:280px;height:600px;border-radius:40px;overflow:hidden;position:relative;background:#F0F5E6}
.scaler{position:absolute;left:0;top:0;width:390px;height:844px;transform:scale(.718);transform-origin:0 0}
.island{position:absolute;left:50%;top:10px;width:84px;height:24px;margin-left:-42px;border-radius:12px;background:#000}
.app{width:390px;height:844px;padding:58px 18px 0;display:flex;flex-direction:column;gap:16px;background:#F0F5E6;position:relative;overflow:hidden}
.card{background:#fff;border:2px solid ${INK};border-radius:20px}
.muted{color:#45564B}
.tile{border:2px solid ${INK};flex:none;border-radius:12px}
.row{display:flex;align-items:center;gap:12px;padding:12px 14px;border-bottom:1.5px solid #DCE5CC}
.row:last-child{border-bottom:none}
.tabs{position:absolute;left:14px;right:14px;bottom:22px;height:64px;border-radius:32px;background:#fff;border:2px solid ${INK};display:flex;align-items:center;justify-content:space-around;font-size:12px;font-weight:700;color:#45564B}
.tabs span{display:flex;flex-direction:column;align-items:center;gap:4px}
.tabs i{width:22px;height:6px;border-radius:3px;background:currentColor;display:block}
.tabs .on{color:#00704A}
.tx{width:300px;height:84px;padding:12px 14px;display:flex;align-items:center;gap:12px;border-radius:20px;background:#fff;border:2px solid ${INK};box-shadow:0 18px 40px rgba(13,31,23,.18)}
.pill{font-size:11px;font-weight:700;padding:2px 8px;border-radius:10px;background:#FFC93C}
`;

const T = {
  en: {
    lang: 'en',
    hello: 'Good evening, Sara', home: 'Home', spent: 'Spent in November', left: '3,859 left · 14 days', budget: 'Budget 6,000', recent: 'Recent',
    tabs: ['Home', 'Activity', 'Insights', 'Bills', 'More'],
    rows: [['Al Noor Café', 'Coffee · 08:42', '18.00', '#FFE7A3'], ['Desert Market', 'Groceries · Yesterday', '236.75', '#C9F0DA'], ['Fuel Station 24', 'Fuel · Yesterday', '90.00', '#CFE6FA'], ['Book Corner', 'Shopping · Sun', '64.00', '#F6D3E4']],
    cats: [['Groceries', '812', '#C9F0DA'], ['Dining', '540', '#FFE7A3'], ['Fuel', '360', '#CFE6FA']],
    bills: 'Bills', upcoming: 'Upcoming', dueSum: 'Due this month', billRows: [['Internet', 'Due Mon 24 Nov', '299.00', '#CFE6FA'], ['Phone', 'Due Fri 28 Nov', '115.00', '#F6D3E4'], ['Rent', 'Due Mon 1 Dec', '3,500.00', '#FFE7A3'], ['Gym', 'Due Wed 3 Dec', '180.00', '#C9F0DA']], paid: 'Paid this month', paidRows: [['Electricity', 'Paid 12 Nov', '245.00', '#FFE7A3']],
    insights: 'Insights', where: 'Where it went', vs: 'Dining is 18% lower than October', tipT: 'Tip', tip: 'Dining is at 82% of its budget with 4 days left. Two home-cooked dinners keep you under.',
    legend: [['Groceries', '38%', '#00A86B'], ['Dining', '25%', '#FFC93C'], ['Fuel', '17%', '#6FA8DC'], ['Other', '20%', '#E79AC0']],
    widgetToday: 'Today', widgetBudget: '35% of the monthly budget',
    sms: ['Your bank', 'Purchase via mada\nAmount: SAR 164.50\nAt: Supermarket\nCard: *4821'],
    s1: ['Every halala,<br>tracked.', 'Purchases add themselves from your bank SMS.'],
    s2: ['Your bank texts.<br>Halala files it.', 'Works with major Saudi banks. No bank login.'],
    s3: ['Your spend,<br>at a glance.', "Today's total and your budget, right on the Home Screen."],
    s4: ['Bills,<br>never missed.', 'Electricity, water, internet: a reminder before each one is due.'],
    s5: ['Insights<br>that save.', 'See where your money goes, with tips to spend less.'],
    tx1: ['Coffee', 'Dining · just now', '18.00', 'From SMS'], tx2: ['Supermarket', 'Groceries · card *4821', '164.50', 'Sorted'],
    bell: ['Water bill is due soon', 'Reminder · 120.00'],
    banner: ['Every halala,<br>tracked.', 'Your purchases, bills and budget in one calm place. Added from your bank SMS.'],
  },
  ar: {
    lang: 'ar',
    hello: 'مساء الخير يا سارة', home: 'الرئيسية', spent: 'المصروف في نوفمبر', left: 'باقي 3,859 · 14 يومًا', budget: 'الميزانية 6,000', recent: 'آخر العمليات',
    tabs: ['الرئيسية', 'العمليات', 'التحليل', 'الفواتير', 'المزيد'],
    rows: [['مقهى النور', 'قهوة · 08:42', '18.00', '#FFE7A3'], ['سوق الصحراء', 'بقالة · أمس', '236.75', '#C9F0DA'], ['محطة وقود 24', 'وقود · أمس', '90.00', '#CFE6FA'], ['ركن الكتب', 'تسوق · الأحد', '64.00', '#F6D3E4']],
    cats: [['بقالة', '812', '#C9F0DA'], ['مطاعم', '540', '#FFE7A3'], ['وقود', '360', '#CFE6FA']],
    bills: 'الفواتير', upcoming: 'القادمة', dueSum: 'مستحق هذا الشهر', billRows: [['الإنترنت', 'تستحق الاثنين 24 نوفمبر', '299.00', '#CFE6FA'], ['الجوال', 'تستحق الجمعة 28 نوفمبر', '115.00', '#F6D3E4'], ['الإيجار', 'يستحق الاثنين 1 ديسمبر', '3,500.00', '#FFE7A3'], ['النادي', 'يستحق الأربعاء 3 ديسمبر', '180.00', '#C9F0DA']], paid: 'المدفوعة هذا الشهر', paidRows: [['الكهرباء', 'دُفعت 12 نوفمبر', '245.00', '#FFE7A3']],
    insights: 'التحليل', where: 'أين ذهبت أموالك', vs: 'المطاعم أقل بـ 18% من أكتوبر', tipT: 'نصيحة', tip: 'المطاعم وصلت إلى 82% من ميزانيتها وباقي 4 أيام. وجبتان في البيت تكفيان لتبقى ضمنها.',
    legend: [['بقالة', '38%', '#00A86B'], ['مطاعم', '25%', '#FFC93C'], ['وقود', '17%', '#6FA8DC'], ['أخرى', '20%', '#E79AC0']],
    widgetToday: 'اليوم', widgetBudget: '35% من الميزانية الشهرية',
    sms: ['البنك', 'شراء عبر مدى\nالمبلغ: 164.50 ريال\nلدى: Supermarket\nالبطاقة: 4821*'],
    s1: ['كل هللة،<br>محسوبة.', 'مشترياتك تنضاف لحالها من رسايل البنك.'],
    s2: ['بنكك يرسل،<br>وهللة يرتّب.', 'يشتغل مع أشهر البنوك السعودية، وبدون ما تربط حسابك.'],
    s3: ['مصروفك<br>قدّام عينك.', 'كم صرفت اليوم وكم باقي من ميزانيتك، على شاشتك الرئيسية.'],
    s4: ['ولا فاتورة<br>تفوتك.', 'الكهرباء والموية والإنترنت: نذكّرك قبل موعد كل وحدة.'],
    s5: ['شوف وين<br>تروح فلوسك.', 'تحليلات ونصايح تساعدك تصرف أقل.'],
    tx1: ['Coffee', 'مطاعم · الآن', '18.00', 'من الرسالة'], tx2: ['Supermarket', 'بقالة · بطاقة 4821*', '164.50', 'تم التصنيف'],
    bell: ['فاتورة المياه تستحق قريبًا', 'تذكير · 120.00'],
    banner: ['كل هللة،<br>محسوبة.', 'مشترياتك وفواتيرك وميزانيتك في مكان واحد، وتنضاف لحالها من رسايل البنك.'],
  },
};

const money = (v) => `<span style="display:inline-flex;gap:4px;align-items:baseline">${R}${v}</span>`;
const tabs = (t, on) => `<div class="tabs">${t.tabs.map((x, i) => `<span class="${i === on ? 'on' : ''}"><i></i>${x}</span>`).join('')}</div>`;
const list = (rows) => `<div class="card">${rows.map((r) => `<div class="row"><span class="tile" style="width:40px;height:40px;background:${r[3]}"></span><div style="flex:1;display:flex;flex-direction:column;gap:2px;min-width:0"><span style="font-size:15px;font-weight:700">${r[0]}</span><span class="muted" style="font-size:12px">${r[1]}</span></div><span style="font-size:15px;font-weight:700">${money(r[2])}</span></div>`).join('')}</div>`;
const title = (t, s) => `<div style="display:flex;align-items:center;justify-content:space-between"><div style="display:flex;flex-direction:column;gap:2px"><span class="muted" style="font-size:14px">${t.hello}</span><span style="font-size:28px;font-weight:800">${s}</span></div><img src="${f('app-icon.svg')}" style="width:44px;height:44px;border-radius:12px"></div>`;

const screens = {
  home: (t) => `<div class="app">${title(t, t.home)}
    <div style="background:#00A86B;border:2px solid ${INK};border-radius:22px;padding:18px;display:flex;flex-direction:column;gap:10px;box-shadow:3px 4px 0 ${INK};color:#fff">
      <span style="font-size:14px;font-weight:500;color:#E6FFF4">${t.spent}</span>
      <span style="font-size:38px;font-weight:800">${money('2,140.50')}</span>
      <div style="height:14px;border-radius:7px;background:#DCE5CC;border:2px solid ${INK};overflow:hidden"><div style="width:36%;height:100%;background:#FFC93C"></div></div>
      <div style="display:flex;justify-content:space-between;font-size:13px;color:#E6FFF4"><span>${t.left}</span><span>${t.budget}</span></div>
    </div>
    <div style="display:flex;gap:10px">${t.cats.map((k) => `<div class="card" style="flex:1;border-radius:16px;padding:10px 12px;display:flex;flex-direction:column;gap:6px"><span class="tile" style="width:26px;height:26px;border-radius:8px;background:${k[2]}"></span><span class="muted" style="font-size:12px">${k[0]}</span><span style="font-size:15px;font-weight:700">${k[1]}</span></div>`).join('')}</div>
    <span style="font-size:17px;font-weight:700">${t.recent}</span>${list(t.rows)}${tabs(t, 0)}</div>`,
  bills: (t) => `<div class="app">${title(t, t.bills)}
    <div style="background:#FFC93C;border:2px solid ${INK};border-radius:22px;padding:18px;display:flex;flex-direction:column;gap:6px;box-shadow:3px 4px 0 ${INK}">
      <span style="font-size:14px;font-weight:500">${t.dueSum}</span><span style="font-size:36px;font-weight:800">${money('4,094.00')}</span></div>
    <span style="font-size:17px;font-weight:700">${t.upcoming}</span>${list(t.billRows)}
    <span style="font-size:17px;font-weight:700">${t.paid}</span>${list(t.paidRows)}${tabs(t, 3)}</div>`,
  insights: (t) => `<div class="app">${title(t, t.insights)}
    <div class="card" style="padding:18px;display:flex;flex-direction:column;gap:14px">
      <span style="font-size:16px;font-weight:700">${t.where}</span>
      <div style="display:flex;align-items:center;gap:18px">
        <div style="width:130px;height:130px;border-radius:50%;flex:none;border:2px solid ${INK};background:conic-gradient(#00A86B 0 38%,#FFC93C 38% 63%,#6FA8DC 63% 80%,#E79AC0 80% 100%);display:flex;align-items:center;justify-content:center"><div style="width:72px;height:72px;border-radius:50%;background:#fff;border:2px solid ${INK}"></div></div>
        <div style="flex:1;display:flex;flex-direction:column;gap:8px">${t.legend.map((l) => `<div style="display:flex;align-items:center;gap:8px;font-size:13px"><span style="width:12px;height:12px;border-radius:4px;background:${l[2]};border:1.5px solid ${INK}"></span><span style="flex:1">${l[0]}</span><b>${l[1]}</b></div>`).join('')}</div>
      </div>
      <div style="font-size:13px;font-weight:700;padding:8px 12px;border-radius:12px;background:#C9F0DA">${t.vs}</div>
    </div>
    <div class="card" style="padding:16px;display:flex;flex-direction:column;gap:8px;background:#FFF6D9"><span style="font-size:13px;font-weight:800;color:#7A4A00">${t.tipT}</span><span style="font-size:15px;line-height:1.45">${t.tip}</span></div>
    ${tabs(t, 2)}</div>`,
};

const SCREEN_IDX = { home: 0, activity: 1, bills: 2, insights: 3 };
const phone = (t, screen, style) => `<div class="abs" style="${style}"><div class="phone"><div class="screen"><img src="file://${path.join(SNAP, `${t.lang}_${SCREEN_IDX[screen]}.png`)}" style="width:280px;height:600px;object-fit:cover;object-position:top;display:block"><div class="island"></div></div></div></div>`;
const tx = (d, tint, style, extra = '') => `<div class="abs" style="${style}"><div class="tx" style="${extra}"><span class="tile" style="width:46px;height:46px;border-radius:14px;background:${tint}"></span><div style="flex:1;min-width:0;display:flex;flex-direction:column;gap:3px"><span style="font-size:16px;font-weight:700">${d[0]}</span><span class="muted" style="font-size:12px">${d[1]}</span></div><div style="display:flex;flex-direction:column;align-items:flex-end;gap:4px"><span style="font-size:17px;font-weight:800">${money(d[2])}</span><span class="pill">${d[3]}</span></div></div></div>`;
const head = (s) => `<div class="head"><h1>${s[0]}</h1><p class="sub">${s[1]}</p></div>`;
const mir = (ar, l) => (ar ? l.replace(/left:/g, 'TMP:').replace(/right:/g, 'left:').replace(/TMP:/g, 'right:') : l);

function shot(lang, n) {
  const t = T[lang];
  const ar = lang === 'ar';
  const m = (s) => mir(ar, s);
  const rot = (d) => (ar ? -d : d);
  switch (n) {
    case 1: return `<div class="shot" style="background:#E2F2DC">
      <div class="bub" style="${m('left:-26px')};top:300px;width:92px;height:92px;background:#FFE7A3"></div>
      <div class="bub" style="${m('right:22px')};top:250px;width:64px;height:64px;background:#FFC93C;box-shadow:3px 4px 0 ${INK}"></div>
      <div class="bub" style="${m('right:-18px')};top:640px;width:80px;height:80px;background:#CFE6FA"></div>
      ${head(t.s1)}${phone(t, 'home', 'left:70px;top:300px')}
      ${tx(t.tx1, '#FFE7A3', `${m('left:150px')};top:520px;transform:rotate(${rot(-4)}deg)`)}</div>`;
    case 2: return `<div class="shot" style="background:#FBEFD2">${head(t.s2).replace('<h1>', `<h1 style="font-size:${ar ? 46 : 42}px">`)}
      <div class="abs" style="left:0;right:0;top:300px;display:flex;justify-content:center;gap:12px">${['#FFC93C', '#C9F0DA', '#FFC93C', '#CFE6FA', '#FFC93C'].map((c) => `<span style="width:54px;height:54px;border-radius:50%;background:${c};border:2px solid ${INK};box-shadow:2px 3px 0 ${INK};display:flex;align-items:center;justify-content:center;font-size:28px">${R}</span>`).join('')}</div>
      <div class="abs" style="${m('left:34px')};top:400px;width:300px;display:flex;flex-direction:column;gap:6px"><span class="muted" style="font-size:12px;font-weight:700;padding:0 12px">${t.sms[0]}</span><div style="padding:12px 16px;border-radius:${ar ? '22px 22px 6px 22px' : '22px 22px 22px 6px'};background:#E9E9EB;font-size:14px;line-height:1.45;white-space:pre-line;box-shadow:0 14px 30px rgba(13,31,23,.14)">${t.sms[1]}</div></div>
      <svg class="abs" style="${m('left:330px')};top:470px;${ar ? 'transform:scaleX(-1)' : ''}" width="60" height="110" viewBox="0 0 60 110" fill="none" stroke="${INK}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M10 6 C 50 20, 54 60, 30 96"/><path d="M18 88 L30 98 L38 84"/></svg>
      ${tx(t.tx2, '#C9F0DA', `${m('left:106px')};top:590px;transform:rotate(${rot(-2)}deg)`)}
      ${phone(t, 'activity', 'left:70px;top:730px')}</div>`;
    case 3: return `<div class="shot" style="background:#E4E6F6">${head(t.s3)}
      ${phone(t, 'home', `${m('left:-40px')};top:420px;transform:rotate(${rot(-14)}deg);transform-origin:top ${ar ? 'right' : 'left'}`)}
      <div class="abs" style="${m('left:96px')};top:300px;transform:rotate(${rot(6)}deg)"><div style="width:330px;height:156px;padding:16px 18px;border-radius:28px;background:#fff;box-shadow:0 20px 44px rgba(13,31,23,.2);display:flex;flex-direction:column;justify-content:space-between">
        <div style="display:flex;align-items:center;justify-content:space-between"><span class="muted" style="font-size:13px;font-weight:700">${t.widgetToday}</span><img src="${f('app-icon.svg')}" style="width:28px;height:28px;border-radius:8px"></div>
        <span style="font-size:34px;font-weight:800">${money('18.00')}</span>
        <div style="display:flex;flex-direction:column;gap:6px"><div style="height:10px;border-radius:5px;background:#DCE5CC;overflow:hidden"><div style="width:35%;height:100%;background:#FFC93C;${ar ? 'margin-right:0;margin-left:auto' : ''}"></div></div><span class="muted" style="font-size:12px">${t.widgetBudget}</span></div></div></div>
      <div class="bub" style="${m('right:26px')};top:560px;width:70px;height:70px;background:#FFC93C;box-shadow:3px 4px 0 ${INK}"></div>
      <div class="bub" style="${m('right:70px')};top:700px;width:40px;height:40px;background:#C9F0DA"></div></div>`;
    case 4: return `<div class="shot" style="background:#F8E1E7">${head(t.s4)}
      <div class="bub" style="${m('left:-20px')};top:330px;width:70px;height:70px;background:#FFC93C;box-shadow:3px 4px 0 ${INK}"></div>
      <div class="bub" style="${m('right:-24px')};top:720px;width:90px;height:90px;background:#CFE6FA"></div>
      ${phone(t, 'bills', 'left:70px;top:300px')}
      <div class="abs" style="${m('left:118px')};top:470px;transform:rotate(${rot(-3)}deg)"><div class="tx" style="width:300px"><span class="tile" style="width:46px;height:46px;border-radius:14px;background:#FFC93C;display:flex;align-items:center;justify-content:center"><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="${INK}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/></svg></span><div style="flex:1;min-width:0;display:flex;flex-direction:column;gap:3px"><span style="font-size:15px;font-weight:700">${t.bell[0]}</span><span class="muted" style="font-size:12px">${t.bell[1]}</span></div></div></div></div>`;
    case 5: return `<div class="shot" style="background:#DCEBFA">${head(t.s5)}
      <div class="bub" style="${m('right:-20px')};top:320px;width:76px;height:76px;background:#C9F0DA"></div>
      <div class="bub" style="${m('left:20px')};top:760px;width:56px;height:56px;background:#FFC93C;box-shadow:3px 4px 0 ${INK}"></div>
      ${phone(t, 'insights', 'left:70px;top:300px')}
      <div class="abs" style="${m('left:150px')};top:640px;transform:rotate(${rot(-3)}deg)"><div class="tx" style="height:auto;width:270px;align-items:flex-start;flex-direction:column;gap:6px;background:#FFF6D9"><span style="font-size:13px;font-weight:800;color:#7A4A00">${t.tipT}</span><span style="font-size:14px;line-height:1.45">${t.tip}</span></div></div></div>`;
  }
}

function banner(lang) {
  const t = T[lang];
  const ar = lang === 'ar';
  const m = (s) => mir(ar, s);
  return `<div style="width:1280px;height:549px;position:relative;overflow:hidden;background:#E2F2DC">
    <div class="bub" style="${m('left:520px')};top:40px;width:70px;height:70px;background:#FFC93C;box-shadow:3px 4px 0 ${INK}"></div>
    <div class="bub" style="${m('left:120px')};top:440px;width:56px;height:56px;background:#CFE6FA"></div>
    <div class="bub" style="${m('right:40px')};top:420px;width:86px;height:86px;background:#F8E1E7"></div>
    <div class="abs" style="${m('left:200px')};top:130px;width:420px;display:flex;flex-direction:column;gap:18px;text-align:${ar ? 'right' : 'left'}">
      <img src="${f('app-icon.svg')}" style="width:72px;height:72px;border-radius:18px">
      <h1 style="font-size:56px">${t.banner[0]}</h1><p class="sub" style="font-size:18px;max-width:400px">${t.banner[1]}</p></div>
    ${phone(t, 'home', `${m('left:660px')};top:110px;transform:rotate(${ar ? 8 : -8}deg)`)}
    ${phone(t, 'bills', `${m('left:910px')};top:60px;transform:rotate(${ar ? -6 : 6}deg)`)}
    ${tx(t.tx1, '#FFE7A3', `${m('left:720px')};top:380px;transform:rotate(${ar ? 3 : -3}deg)`)}</div>`;
}

const page = (lang, body) => `<!doctype html><html lang="${lang}" dir="${lang === 'ar' ? 'rtl' : 'ltr'}"><head><meta charset="utf-8"><style>${css}</style></head><body>${body}</body></html>`;

(async () => {
  if (!fs.existsSync(path.join(SNAP, 'en_0.png'))) throw new Error(`No app screens in ${SNAP}: run the STORE_SHOTS test first (see the top of this file).`);
  const browser = await chromium.launch();
  for (const lang of ['en', 'ar']) {
    fs.mkdirSync(path.join(OUT, lang), { recursive: true });
    const ctx = await browser.newContext({ viewport: { width: 440, height: 956 }, deviceScaleFactor: 3 });
    const p = await ctx.newPage();
    for (let n = 1; n <= 5; n++) {
      const file = path.join(OUT, lang, `0${n}.html`);
      fs.writeFileSync(file, page(lang, shot(lang, n)));
      await p.goto('file://' + file);
      await p.evaluate(() => document.fonts.ready);
      await p.screenshot({ path: path.join(OUT, lang, `0${n}.png`), clip: { x: 0, y: 0, width: 440, height: 956 } });
      fs.unlinkSync(file);
    }
    const bctx = await browser.newContext({ viewport: { width: 3840, height: 1646 }, deviceScaleFactor: 1 });
    const bp = await bctx.newPage();
    const bfile = path.join(OUT, lang, 'header.html');
    fs.writeFileSync(bfile, page(lang, `<div style="zoom:3">${banner(lang)}</div>`));
    await bp.goto('file://' + bfile);
    await bp.evaluate(() => document.fonts.ready);
    await bp.screenshot({ path: path.join(OUT, lang, 'header-3840x1646.png'), clip: { x: 0, y: 0, width: 3840, height: 1646 } });
    fs.unlinkSync(bfile);
  }
  await browser.close();
})();
