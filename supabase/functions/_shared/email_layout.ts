/**
 * The Halala email layout (approved by the owner 2026-11-09): wordmark, English block, Arabic block (right to left),
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
  body{margin:0;padding:0;background:#f4f1ea}
  .card{background:#ffffff;border-radius:16px}
  .t{color:#1d1d1b}.m{color:#66665f}
  @media (prefers-color-scheme:dark){
    body,.bg{background:#14161a!important}
    .card{background:#1c1f25!important}
    .t{color:#ecece6!important}.m{color:#9c9c94!important}
    .line{border-color:#2c3038!important}
    .acc{color:#4fc3a1!important}
  }`;

function block(c: EmailBlock, dir: "ltr" | "rtl"): string {
  const align = dir === "rtl" ? "right" : "left";
  const lh = dir === "rtl" ? "1.9" : "1.6";
  const ps = c.p.map((x) =>
    `<p class="t" style="margin:0 0 12px;font-size:16px;line-height:${lh};color:#1d1d1b">${x}</p>`
  ).join("");
  const note = c.note
    ? `<p class="m" style="margin:16px 0 0;font-size:14px;line-height:${lh};color:#66665f">${c.note}</p>`
    : "";
  return `<tr><td dir="${dir}" style="text-align:${align};padding:8px 28px;font-family:${FONT}">
  <h1 class="t" style="margin:16px 0 12px;font-size:24px;line-height:1.3;color:#1d1d1b">${c.h}</h1>${ps}${note}</td></tr>`;
}

export function emailHtml(en: EmailBlock, ar: EmailBlock): string {
  return `<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="light dark"><meta name="supported-color-schemes" content="light dark">
<title>${en.h}</title><style>${CSS}</style></head>
<body><table role="presentation" class="bg" width="100%" cellpadding="0" cellspacing="0" style="background:#f4f1ea"><tr><td align="center" style="padding:24px 12px">
<table role="presentation" class="card" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;background:#ffffff;border-radius:16px">
<tr><td align="center" style="padding:28px 28px 8px;font-family:${FONT}"><span class="acc" style="font-size:22px;font-weight:700;color:#1f6f5c">Halala &nbsp;·&nbsp; هللة</span></td></tr>
${block(en, "ltr")}
<tr><td style="padding:8px 28px"><div class="line" style="border-top:1px solid #e4e1d8"></div></td></tr>
${block(ar, "rtl")}
<tr><td align="center" style="padding:20px 28px 28px;font-family:${FONT}">
<p class="m" style="margin:0 0 4px;font-size:13px;line-height:1.6;color:#66665f">This is an automated message, please do not reply.</p>
<p class="m" dir="rtl" style="margin:0 0 10px;font-size:13px;line-height:1.8;color:#66665f">هذه رسالة آلية، يرجى عدم الرد عليها.</p>
<p class="m" style="margin:0 0 4px;font-size:13px;line-height:1.6;color:#66665f">Questions? <a href="mailto:${SUPPORT}" class="acc" style="color:#1f6f5c">${SUPPORT}</a></p>
<p class="m" dir="rtl" style="margin:0 0 10px;font-size:13px;line-height:1.8;color:#66665f">للاستفسار: <a href="mailto:${SUPPORT}" dir="ltr" class="acc" style="color:#1f6f5c">${SUPPORT}</a></p>
<p class="m" style="margin:0;font-size:13px;line-height:1.6;color:#66665f"><a href="${PRIVACY_URL}" class="acc" style="color:#1f6f5c">Privacy policy</a> &nbsp;|&nbsp; <a href="${PRIVACY_URL}ar/" class="acc" style="color:#1f6f5c">سياسة الخصوصية</a></p>
</td></tr></table></td></tr></table></body></html>`;
}
