// Builds every Halala email from one layout. Run: node docs/email-design/build.mjs
// Output: templates/*.html (paste the Auth ones into Supabase > Authentication > Emails), subjects.json, preview.html
import { writeFileSync } from "node:fs";

const SUPPORT = "halala-support@rawafiddata.com";
const PRIVACY_URL = "https://halala.rawafiddata.com/privacy/";

const css = `
  body{margin:0;padding:0;background:#f4f1ea}
  a[x-apple-data-detectors]{color:inherit!important;text-decoration:none!important;font-size:inherit!important;font-family:inherit!important;font-weight:inherit!important;line-height:inherit!important}
  .card{background:#ffffff;border-radius:16px}
  .t{color:#1d1d1b}.m{color:#66665f}
  @media (prefers-color-scheme:dark){
    body,.bg{background:#14161a!important}
    .card{background:#1c1f25!important}
    .t{color:#ecece6!important}.m{color:#9c9c94!important}
    .line{border-color:#2c3038!important}
    .code{background:#14161a!important}
    .acc{color:#4fc3a1!important}
  }`;

function block(c, dir) {
  const align = dir === "rtl" ? "right" : "left";
  const font = "-apple-system,'Segoe UI',Tahoma,'Geeza Pro',Arial,sans-serif";
  const lh = dir === "rtl" ? "1.9" : "1.6";
  const ps = c.p.map((x) => `<p class="t" style="margin:0 0 12px;font-size:16px;line-height:${lh};color:#1d1d1b">${x}</p>`).join("");
  const code = c.code
    ? `<div class="code acc" style="margin:16px 0;padding:16px;background:#f4f1ea;border-radius:12px;text-align:center;font-size:28px;letter-spacing:6px;font-weight:700;color:#1f6f5c;font-family:'SF Mono',Menlo,Consolas,monospace" dir="ltr">${c.code}</div>`
    : "";
  const btn = c.button
    ? `<p style="margin:20px 0"><a href="${c.href}" style="display:inline-block;background:#1f6f5c;color:#ffffff;text-decoration:none;font-weight:600;font-size:16px;padding:14px 26px;border-radius:12px">${c.button}</a></p>`
    : "";
  const note = c.note
    ? `<p class="m" style="margin:16px 0 0;font-size:14px;line-height:${lh};color:#66665f">${c.note}</p>`
    : "";
  return `<tr><td dir="${dir}" style="text-align:${align};padding:8px 28px;font-family:${font}">
  <h1 class="t" style="margin:16px 0 12px;font-size:24px;line-height:1.3;color:#1d1d1b">${c.h}</h1>${ps}${code}${btn}${note}</td></tr>`;
}

function html(en, ar, { automated = true } = {}) {
  const font = "-apple-system,'Segoe UI',Tahoma,'Geeza Pro',Arial,sans-serif";
  return `<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="format-detection" content="telephone=no,date=no,address=no,email=no"><meta name="color-scheme" content="light dark"><meta name="supported-color-schemes" content="light dark">
<title>${en.h}</title><style>${css}</style></head>
<body><table role="presentation" class="bg" width="100%" cellpadding="0" cellspacing="0" style="background:#f4f1ea"><tr><td align="center" style="padding:24px 12px">
<table role="presentation" class="card" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;background:#ffffff;border-radius:16px">
<tr><td align="center" style="padding:28px 28px 8px;font-family:${font}"><span class="acc" style="font-size:22px;font-weight:700;color:#1f6f5c">Halala &nbsp;·&nbsp; هللة</span></td></tr>
${block(en, "ltr")}
<tr><td style="padding:8px 28px"><div class="line" style="border-top:1px solid #e4e1d8"></div></td></tr>
${block(ar, "rtl")}
<tr><td align="center" style="padding:20px 28px 28px;font-family:${font}">
${automated ? `<p class="m" style="margin:0 0 4px;font-size:13px;line-height:1.6;color:#66665f">This is an automated message, please do not reply.</p>
<p class="m" dir="rtl" style="margin:0 0 10px;font-size:13px;line-height:1.8;color:#66665f">هذه رسالة آلية، يرجى عدم الرد عليها.</p>` : ""}
<p class="m" style="margin:0 0 4px;font-size:13px;line-height:1.6;color:#66665f">Questions? <a href="mailto:${SUPPORT}" class="acc" style="color:#1f6f5c">${SUPPORT}</a></p>
<p class="m" dir="rtl" style="margin:0 0 10px;font-size:13px;line-height:1.8;color:#66665f">للاستفسار: <a href="mailto:${SUPPORT}" dir="ltr" class="acc" style="color:#1f6f5c">${SUPPORT}</a></p>
<p class="m" style="margin:0;font-size:13px;line-height:1.6;color:#66665f"><a href="${PRIVACY_URL}" class="acc" style="color:#1f6f5c">Privacy policy</a> &nbsp;|&nbsp; <a href="${PRIVACY_URL}ar/" class="acc" style="color:#1f6f5c">سياسة الخصوصية</a></p>
</td></tr></table></td></tr></table></body></html>`;
}

// href placeholders are Supabase template variables for the Auth mails.
const URL_ = "{{ .ConfirmationURL }}";
const E = {
  reset_password: {
    where: "Supabase > Authentication > Emails > Templates > Reset password",
    subject: "Reset your Halala password · إعادة تعيين كلمة مرور هللة",
    en: { h: "Reset your password", p: ["We received a request to reset the password of your Halala account.", "Tap the button below to choose a new password."], button: "Choose a new password", href: URL_, note: "If you didn't ask for this, ignore this email. Your password will not change." },
    ar: { h: "إعادة تعيين كلمة المرور", p: ["وصلنا طلب لإعادة تعيين كلمة مرور حسابك في هللة.", "اضغط الزر أدناه لاختيار كلمة مرور جديدة."], button: "اختيار كلمة مرور جديدة", href: URL_, note: "إذا لم تطلب ذلك، تجاهل هذه الرسالة. لن تتغير كلمة مرورك." },
  },
  confirm_signup: {
    where: "Supabase > Authentication > Emails > Templates > Confirm sign up (email confirmation is on)",
    subject: "Confirm your email · تأكيد بريدك الإلكتروني",
    en: { h: "Confirm your email", p: ["Welcome to Halala. Confirm your email address to finish creating your account."], button: "Confirm email", href: URL_, note: "If you didn't create an account, ignore this email." },
    ar: { h: "تأكيد بريدك الإلكتروني", p: ["أهلًا بك في هللة. أكّد بريدك الإلكتروني لإكمال إنشاء حسابك."], button: "تأكيد البريد", href: URL_, note: "إذا لم تنشئ حسابًا، تجاهل هذه الرسالة." },
  },
  change_email: {
    where: "Supabase > Authentication > Emails > Templates > Change email address",
    subject: "Confirm your new email · تأكيد بريدك الجديد",
    en: { h: "Confirm your new email", p: ["You asked to change the email of your Halala account to <b>{{ .NewEmail }}</b>."], button: "Confirm new email", href: URL_, note: "If you didn't ask for this, don't tap the button and change your password right away." },
    ar: { h: "تأكيد بريدك الجديد", p: ["طلبت تغيير بريد حسابك في هللة إلى <b dir=\"ltr\">{{ .NewEmail }}</b>."], button: "تأكيد البريد الجديد", href: URL_, note: "إذا لم تطلب ذلك، لا تضغط الزر وغيّر كلمة مرورك فورًا." },
  },
  reauthentication: {
    where: "Supabase > Authentication > Emails > Templates > Reauthentication",
    subject: "Your Halala confirmation code · رمز التأكيد في هللة",
    en: { h: "Your confirmation code", p: ["Enter this code in the app to confirm it's you."], code: "{{ .Token }}", note: "Never share this code. Halala will never ask you for it." },
    ar: { h: "رمز التأكيد", p: ["أدخل الرمز الظاهر أعلاه في التطبيق لتأكيد أنك أنت."], note: "لا تشارك هذا الرمز مع أحد. لن يطلبه منك هللة أبدًا." },
  },
  password_changed: {
    where: "Supabase > Authentication > Emails > Templates > Password changed (security notification)",
    subject: "Your Halala password was changed · تم تغيير كلمة مرور هللة",
    en: { h: "Your password was changed", p: ["The password of your Halala account was just changed."], note: "If this was you, there is nothing to do. If not, tap Forgot password on the sign-in screen to reset it now, and write to us." },
    ar: { h: "تم تغيير كلمة المرور", p: ["تم تغيير كلمة مرور حسابك في هللة للتو."], note: "إذا كنت أنت من فعل ذلك فلا حاجة لأي إجراء. وإن لم تكن أنت، اضغط «نسيت كلمة المرور» في شاشة الدخول لإعادة تعيينها الآن، وراسلنا." },
  },
  email_changed: {
    where: "Supabase > Authentication > Emails > Templates > Email address changed (security notification, sent to the old address)",
    subject: "Your Halala email was changed · تم تغيير بريد هللة",
    en: { h: "Your email was changed", p: ["The email address of your Halala account was changed from <b>{{ .OldEmail }}</b> to <b>{{ .Email }}</b>."], note: "If this wasn't you, reset your password now and write to us." },
    ar: { h: "تم تغيير البريد الإلكتروني", p: ["تم تغيير بريد حسابك في هللة من <b dir=\"ltr\">{{ .OldEmail }}</b> إلى <b dir=\"ltr\">{{ .Email }}</b>."], note: "إذا لم تكن أنت، أعد تعيين كلمة مرورك الآن وراسلنا." },
  },
  account_deletion: {
    where: "Edge Function delete-account (supabase/functions/_shared/account_email.ts)",
    subject: "Your account will be deleted in 30 days · سيُحذف حسابك بعد 30 يومًا",
    en: { h: "Your account will be deleted in 30 days", p: ["Someone asked to delete your Halala account. It will be deleted for good in 30 days, together with your data.", "To cancel, just sign in again before then."], note: "If this wasn't you, sign in now and change your password." },
    ar: { h: "سيُحذف حسابك بعد 30 يومًا", p: ["طُلب حذف حسابك في هللة، وسيُحذف نهائيًا مع بياناتك بعد 30 يومًا.", "للإلغاء، سجّل الدخول مرة أخرى قبل ذلك."], note: "إذا لم تكن أنت، سجّل الدخول الآن وغيّر كلمة المرور." },
  },
  account_reactivated: {
    where: "Edge Function send-account-email (supabase/functions/_shared/account_email.ts)",
    subject: "Your account is active again · حسابك نشط مرة أخرى",
    en: { h: "Your account is active again", p: ["You signed in, so the deletion of your account is cancelled and your data is kept."], note: "If this wasn't you, change your password now (Sign in > Forgot password)." },
    ar: { h: "حسابك نشط مرة أخرى", p: ["لقد سجّلت الدخول، لذلك أُلغي حذف حسابك وبقيت بياناتك محفوظة."], note: "إذا لم تكن أنت، غيّر كلمة المرور الآن (تسجيل الدخول > نسيت كلمة المرور)." },
  },
};

const subjects = {};
let preview = `<!DOCTYPE html><meta charset="utf-8"><title>Halala emails</title><style>body{font-family:system-ui;background:#e9e6de;margin:0;padding:24px}h2{margin:32px 0 4px}p.w{margin:0 0 8px;color:#555;font-size:13px}iframe{width:620px;height:760px;border:0;background:#fff}.row{display:flex;flex-wrap:wrap;gap:24px}</style><div class="row">`;
for (const [k, v] of Object.entries(E)) {
  const out = html(v.en, v.ar);
  writeFileSync(new URL(`templates/${k}.html`, import.meta.url), out);
  subjects[k] = { subject: v.subject, where: v.where };
  preview += `<div><h2>${k}</h2><p class="w">${v.subject}<br>${v.where}</p><iframe srcdoc="${out.replace(/&/g, "&amp;").replace(/"/g, "&quot;")}"></iframe></div>`;
}
writeFileSync(new URL("subjects.json", import.meta.url), JSON.stringify(subjects, null, 2) + "\n");
writeFileSync(new URL("preview.html", import.meta.url), preview + "</div>");
console.log(Object.keys(E).length, "emails built");
