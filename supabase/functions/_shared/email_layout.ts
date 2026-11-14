/**
 * The Halala email layout (approved by the owner 2026-11-09, rebrand colours 2026-11-13): wordmark, English block, Arabic block (right to left),
 * footer with the support address. Static text only, never user input, so nothing here is escaped.
 * The same layout is built for the Supabase Auth mails by docs/email-design/build.mjs: keep the two in step.
 */
export interface EmailBlock {
  h: string;
  p: string[];
  note?: string;
}

const SUPPORT = "halala-support@rawafiddata.com";
const PRIVACY_URL = "https://halala.rawafiddata.com/privacy/";
const FONT = "-apple-system,'Segoe UI',Tahoma,'Geeza Pro',Arial,sans-serif";

const CSS = `
  body{margin:0;padding:0;background:#F0F5E6}
  a[x-apple-data-detectors]{color:inherit!important;text-decoration:none!important;font-size:inherit!important;font-family:inherit!important;font-weight:inherit!important;line-height:inherit!important}
  .card{background:#ffffff;border-radius:20px}
  .t{color:#0D1F17}.m{color:#45564B}
  @media (prefers-color-scheme:dark){
    body,.bg{background:#0D1F17!important}
    .card{background:#173326!important;border-color:#F0F5E6!important;box-shadow:4px 5px 0 #F0F5E6!important}
    .t{color:#F0F5E6!important}.m{color:#A9BBAF!important}
    .line{border-color:#2B4C3D!important}
    .acc{color:#3FD79B!important}
    .btn{background:#3FD79B!important;border-color:#F0F5E6!important;box-shadow:3px 4px 0 #F0F5E6!important}
  }`;

function block(c: EmailBlock, dir: "ltr" | "rtl"): string {
  const align = dir === "rtl" ? "right" : "left";
  const lh = dir === "rtl" ? "1.9" : "1.6";
  const ps = c.p.map((x) =>
    `<p class="t" style="margin:0 0 12px;font-size:16px;line-height:${lh};color:#0D1F17">${x}</p>`
  ).join("");
  const note = c.note
    ? `<p class="m" style="margin:16px 0 0;font-size:14px;line-height:${lh};color:#45564B">${c.note}</p>`
    : "";
  return `<tr><td dir="${dir}" style="text-align:${align};padding:8px 28px;font-family:${FONT}">
  <h1 class="t" style="margin:16px 0 12px;font-size:24px;line-height:1.3;color:#0D1F17">${c.h}</h1>${ps}${note}</td></tr>`;
}

export function emailHtml(en: EmailBlock, ar: EmailBlock): string {
  return `<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="format-detection" content="telephone=no,date=no,address=no,email=no"><meta name="color-scheme" content="light dark"><meta name="supported-color-schemes" content="light dark">
<title>${en.h}</title><style>${CSS}</style></head>
<body><table role="presentation" class="bg" width="100%" cellpadding="0" cellspacing="0" style="background:#F0F5E6"><tr><td align="center" style="padding:24px 12px">
<table role="presentation" class="card" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;background:#ffffff;border:2.5px solid #0D1F17;border-radius:20px;box-shadow:4px 5px 0 #0D1F17">
<tr><td align="center" style="padding:28px 28px 8px;font-family:${FONT}"><span class="acc" style="font-size:22px;font-weight:800;color:#00704A">Halala &nbsp;·&nbsp; هللة</span></td></tr>
${block(en, "ltr")}
<tr><td style="padding:8px 28px"><div class="line" style="border-top:2px solid #DCE5CC"></div></td></tr>
${block(ar, "rtl")}
<tr><td align="center" style="padding:20px 28px 28px;font-family:${FONT}">
<p class="m" style="margin:0 0 4px;font-size:13px;line-height:1.6;color:#45564B">This is an automated message, please do not reply.</p>
<p class="m" dir="rtl" style="margin:0 0 10px;font-size:13px;line-height:1.8;color:#45564B">هذه رسالة آلية، يرجى عدم الرد عليها.</p>
<p class="m" style="margin:0 0 4px;font-size:13px;line-height:1.6;color:#45564B">Questions? <a href="mailto:${SUPPORT}" class="acc" style="color:#00704A">${SUPPORT}</a></p>
<p class="m" dir="rtl" style="margin:0 0 10px;font-size:13px;line-height:1.8;color:#45564B">للاستفسار: <a href="mailto:${SUPPORT}" dir="ltr" class="acc" style="color:#00704A">${SUPPORT}</a></p>
<p class="m" style="margin:0;font-size:13px;line-height:1.6;color:#45564B"><a href="${PRIVACY_URL}" class="acc" style="color:#00704A">Privacy policy</a> &nbsp;|&nbsp; <a href="${PRIVACY_URL}ar/" class="acc" style="color:#00704A">سياسة الخصوصية</a></p>
</td></tr></table></td></tr></table></body></html>`;
}
