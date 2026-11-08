# 09-app-store-listing: App Store text, privacy answers and screenshots

Status: DRAFT for the owner (2026-11-08). Nothing here is submitted. Items marked **OWNER** need a decision or a value only the owner has. Character limits were checked (counts in brackets). Arabic text was written by Claude: the owner should read it before submitting.

## 1. Decisions and values needed (OWNER)
| # | Item | Why | Suggestion |
|---|---|---|---|
| 1 | **App name** (30 max) | Must be unique on the App Store; "Spending Tracker" is generic and likely taken | Try "Spending Tracker", then "Spending Tracker: SAR" or a brand name. Arabic name below is separate and can differ |
| 2 | **iPad or iPhone only** | The Runner target is built for iPhone **and** iPad (`TARGETED_DEVICE_FAMILY = "1,2"`), so Apple requires iPad screenshots (13-inch, 2064x2752) and the layout must look right on iPad | iPhone only: set `TARGETED_DEVICE_FAMILY = 1` for Runner and drop the iPad orientations from `Info.plist`. Much less work for a phone-first app |
| 3 | **Privacy policy URL** | Required field. The English page is `docs/privacy/index.html`, the Arabic page is `docs/privacy/ar/index.html` (both served from GitHub Pages) | Send me the exact public URL of the English page, I will put it here and in the app |
| 4 | **Support URL and contact** | Required field | A page or mailto on your own domain, for example `https://rawafiddata.com/` plus `privacy@rawafiddata.com` (alias still to create) |
| 5 | **Reviewer account** | App Review needs to sign in | Create a dedicated email + password account with some sample data (Quick add a few purchases). Put it in section 6 |
| 6 | **Paid plan text** | The paid plan (AI) is not built yet. If the first release has no purchase, leave all price text out | Ship v1 without in-app purchase, add it in 1.1 with the subscription text from section 7 |
| 7 | **Copyright line** | Required field | "2026 <your name or company>" |
| 8 | **Category** | | Finance (primary). Secondary: Productivity |

## 2. In-app gap found while writing this (needs a code change)
`Account > Privacy` is still a placeholder ("More options will appear here soon.") and has **no link to the privacy policy**. Apple expects the policy to be reachable inside the app as well as in the listing. Fix once the URL (item 3) is known: add a "Privacy policy" row that opens it, in English and Arabic, plus a link on the sign-up screen. Not done yet because the exact URL is not decided.

## 3. English listing
- **Name** [16]: Spending Tracker  (see item 1)
- **Subtitle** [25]: See where your money goes
- **Promotional text** (can be changed without a new build) [155]: Bank SMS turned into clear spending, bills and budgets. Works in English and Arabic, built for Saudi banks, with a home screen widget and optional AI help.
- **Keywords** [95]: budget,expenses,spending,bills,SAR,Saudi,SMS,savings,money,finance,widget,Arabic,salary,tracker
- **Category**: Finance · **Age rating**: 4+ (see section 5)
- **Description** (4000 max):

> Spending Tracker shows where your money goes, using the bank messages you already receive.
>
> CAPTURE WITHOUT TYPING
> Set up a small iOS Shortcut once, and every bank SMS from a supported bank becomes a transaction: merchant, amount, card ending, date and time. Supported today: Al Rajhi, SNB, Alinma, barq, D360 and STC Bank. You can always add a purchase by hand too.
>
> KNOW WHAT IS REALLY SPENT
> Transfers between your own accounts, wallet top-ups and credit card payments are recognised and left out, so your spending and income are not counted twice. Everything is in Saudi riyals, with the week starting on Sunday and 24-hour time.
>
> BILLS AND REGULAR PAYMENTS
> Track bills, loan instalments and your card statement. The app shows what is due, marks it paid when the matching payment arrives, and reminds you before the due date.
>
> BUDGETS AND INSIGHTS
> Set a monthly budget and category limits, see where the month is heading against your last three months, and spot what is repeating every month.
>
> HOME SCREEN WIDGET
> See what you spent today and how much of your monthly budget is used, on the home screen and the lock screen.
>
> ENGLISH AND ARABIC
> Full Arabic interface with right-to-left layout, switchable at any time.
>
> PRIVATE BY DESIGN
> Your data sits in your own account and only you can read it. Lock the app with Face ID. No ads, no tracking, and your data is never sold. Delete your account at any time from inside the app.
>
> OPTIONAL AI HELP
> If you turn it on, AI can suggest categories, answer questions about your month and write savings tips. Card, account and phone details are removed before anything is sent, and AI is off until you switch it on.

(Do not claim "all Saudi banks" or "bank-grade security": neither is true or provable. Keep the supported-bank list in step with `docs/07-sms-catalog.md`.)

## 4. Arabic listing
- **الاسم** [15]: متتبع المصروفات
- **العنوان الفرعي** [18]: اعرف أين يذهب مالك
- **النص الترويجي** [158]: رسائل البنك تتحول إلى مصروفات وفواتير وميزانيات واضحة. بالعربية والإنجليزية، مصمم للبنوك السعودية، مع ودجت للشاشة الرئيسية ومساعدة اختيارية بالذكاء الاصطناعي.
- **الكلمات المفتاحية** [71]: ميزانية,مصروفات,فواتير,ريال,السعودية,رسائل,توفير,مال,راتب,تتبع,ودجت,بنك
- **الوصف**:

> يعرض لك «متتبع المصروفات» أين يذهب مالك، اعتمادًا على رسائل البنك التي تصلك أصلًا.
>
> التقاط بلا كتابة
> أعدّ اختصارًا بسيطًا في iOS مرة واحدة، فتتحول كل رسالة من بنك مدعوم إلى عملية: المتجر والمبلغ وآخر أرقام البطاقة والتاريخ والوقت. البنوك المدعومة حاليًا: الراجحي، SNB، الإنماء، barq، D360، وSTC Bank. ويمكنك دائمًا إضافة عملية يدويًا.
>
> اعرف ما صُرف فعلًا
> يتعرّف التطبيق على التحويلات بين حساباتك وتعبئة المحافظ وسداد بطاقة الائتمان ويستبعدها، فلا يُحتسب الصرف أو الدخل مرتين. كل شيء بالريال السعودي، والأسبوع يبدأ من الأحد، والوقت بنظام 24 ساعة.
>
> الفواتير والالتزامات الدورية
> تابع الفواتير وأقساط التمويل وكشف بطاقتك. يعرض لك التطبيق المستحق، ويضع علامة «مدفوع» عند وصول الدفعة المطابقة، ويذكّرك قبل موعد الاستحقاق.
>
> ميزانيات وتحليلات
> حدّد ميزانية شهرية وحدودًا للتصنيفات، وتابع وجهة الشهر مقارنةً بآخر ثلاثة أشهر، وانتبه لما يتكرر كل شهر.
>
> ودجت للشاشة الرئيسية
> شاهد ما صرفته اليوم ونسبة ما استُهلك من ميزانيتك الشهرية، على الشاشة الرئيسية وشاشة القفل.
>
> بالعربية والإنجليزية
> واجهة عربية كاملة بتخطيط من اليمين إلى اليسار، ويمكنك التبديل بينها وبين الإنجليزية في أي وقت.
>
> خصوصية من التصميم
> بياناتك في حسابك أنت ولا يقرؤها غيرك. اقفل التطبيق ببصمة الوجه. لا إعلانات ولا تتبع، ولا نبيع بياناتك. ويمكنك حذف حسابك في أي وقت من داخل التطبيق.
>
> مساعدة اختيارية بالذكاء الاصطناعي
> إذا فعّلتها، يستطيع الذكاء الاصطناعي اقتراح التصنيفات والإجابة عن أسئلتك حول شهرك وكتابة نصائح للتوفير. تُزال تفاصيل البطاقات والحسابات والهاتف قبل إرسال أي شيء، والميزة متوقفة حتى تشغّلها.

## 5. App Privacy answers (App Store Connect "nutrition label")
Tracking: **No** (no advertising, no analytics SDK, no data broker). All items below are **linked to the user**, used for **App Functionality** only.

| Apple category | Collected? | What it is here |
|---|---|---|
| Contact Info: Email address, Name | Yes | Account sign-up (Apple relay address if hidden) |
| Financial Info: Other financial info | Yes | Transactions, bills, salary, budgets, last four digits of cards/accounts |
| Purchases: Purchase history | Yes | The same purchases the user records or captures |
| User Content: Other user content | Yes | Stored text of bank SMS sent by the user's Shortcut |
| Identifiers: User ID | Yes | Account id, capture and widget tokens |
| Location, Contacts, Photos, Health, Browsing, Search, Diagnostics, Usage Data, Advertising data | No | Not collected |

Data processors to keep in step with the policy: Supabase (Mumbai), Resend (email), Apple (sign-in), Anthropic (optional AI; only when the user turns it on). Age rating questionnaire: no objectionable content, no gambling, no unrestricted web access → **4+**. Export compliance: `ITSAppUsesNonExemptEncryption = false` is already set (HTTPS only). Account deletion: in the app (Account > Privacy > Delete my account), satisfies the review rule on deletion; Sign in with Apple is offered next to email + password.

## 6. Notes for App Review (paste into "Notes")
> Spending Tracker records the user's spending from bank SMS. The SMS capture is optional: a user sets up an iOS Shortcut that forwards bank messages to the app; all features also work with purchases added by hand (Quick add). To review without a bank, sign in with the demo account below and use Quick add to create a purchase.
> Demo account: email <OWNER: create it> / password <OWNER: set it>. It has sample data.
> Sign in with Apple is also offered. Account deletion is under Account > Privacy > Delete my account.
> AI features are optional, off by default, and send only redacted text to Anthropic's API; they are not needed to review the app.
> The app does not read SMS directly; it receives only messages the user's own Shortcut sends.

## 7. Subscription text (only when the paid plan is built; not needed for v1)
Apple requires, next to the buy button and in the description: the plan name, length, price, that it auto-renews, how to cancel (iOS Settings > Apple ID > Subscriptions), links to the privacy policy and Apple's standard Terms of Use (EULA) or the app's own terms. Price and quota are still open (suggested 9.99 SAR/month, about 3 SAR AI allowance); the Apple Paid Apps agreement, bank and tax details must be done first.

## 8. Screenshot plan
Sizes: iPhone 6.9-inch **1320x2868** (required; Apple scales it for smaller iPhones). iPad 13-inch 2064x2752 only if item 2 keeps iPad. Take them in English and in Arabic (set the app language, same screens). Use the dedicated demo account with plausible fake data, **never** real merchants, names, balances or card endings.

| # | Screen | Caption (EN / AR) |
|---|---|---|
| 1 | Home: spent today, month ring, budget | "See where your money goes" / "اعرف أين يذهب مالك" |
| 2 | Activity list with categories | "Every bank SMS, captured" / "كل رسالة بنك، تُلتقط تلقائيًا" |
| 3 | Bills screen with due dates and paid pills | "Never miss a bill" / "لا تفوّتك فاتورة" |
| 4 | Insights: month vs last three months | "Understand your month" / "افهم شهرك" |
| 5 | Budgets with category bars | "Stay inside your budget" / "ابقَ ضمن ميزانيتك" |
| 6 | Home screen with the widget (small + medium) | "Your budget at a glance" / "ميزانيتك بنظرة" |
| 7 | Arabic RTL home | "Full Arabic, right to left" / "عربي كامل من اليمين لليسار" |

Capture method: run the app on the TestFlight build with the demo account and take screenshots on a 6.9-inch iPhone (the owner's phone is smaller, so capture on the closest size available, or use the simulator route in Codemagic later). Keep captions short, put the device frame optional, and no text smaller than 28 px on the 1320 px width.

## 9. Submission checklist
1. Decide items 1-8 above.
2. Add the privacy-policy row to the app (section 2) and rebuild.
3. Create the reviewer account and sample data.
4. Fill App Privacy (section 5), age rating, category, URLs, copyright.
5. Upload screenshots for each language, paste both listings (Arabic as a second localization).
6. Select the TestFlight build, answer export compliance, submit for review.
