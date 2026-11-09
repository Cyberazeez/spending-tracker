/**
 * Account emails Supabase Auth does not send itself (it only sends confirm / reset / change-email mails). Sent through
 * the provider's HTTP API; the API key is a Supabase secret and is never logged. Every mail is bilingual (English,
 * then Arabic) because the account has no stored language.
 */
export type AccountEmailKind = "reactivated" | "deletion_requested";

export const FROM_DEFAULT = "Halala <halala-noreply@rawafiddata.com>";
const RESEND_URL = "https://api.resend.com/emails";

import { type EmailBlock, emailHtml } from "./email_layout.ts";

interface Copy extends EmailBlock {
  subject: string;
}

const COPY: Record<AccountEmailKind, { en: Copy; ar: Copy }> = {
  reactivated: {
    en: {
      subject: "Your account is active again",
      h: "Your account is active again",
      p: ["You signed in, so the deletion of your account is cancelled and your data is kept."],
      note: "If this wasn't you, change your password now (Sign in > Forgot password).",
    },
    ar: {
      subject: "حسابك نشط مرة أخرى",
      h: "حسابك نشط مرة أخرى",
      p: ["لقد سجّلت الدخول، لذلك أُلغي حذف حسابك وبقيت بياناتك محفوظة."],
      note: "إذا لم تكن أنت، غيّر كلمة المرور الآن (تسجيل الدخول > نسيت كلمة المرور).",
    },
  },
  deletion_requested: {
    en: {
      subject: "Your account will be deleted in 30 days",
      h: "Your account will be deleted in 30 days",
      p: [
        "Someone asked to delete your Halala account. It will be deleted for good in 30 days, together with your data.",
        "To cancel, just sign in again before then.",
      ],
      note: "If this wasn't you, sign in now and change your password.",
    },
    ar: {
      subject: "سيُحذف حسابك بعد 30 يومًا",
      h: "سيُحذف حسابك بعد 30 يومًا",
      p: [
        "طُلب حذف حسابك في هللة، وسيُحذف نهائيًا مع بياناتك بعد 30 يومًا.",
        "للإلغاء، سجّل الدخول مرة أخرى قبل ذلك.",
      ],
      note: "إذا لم تكن أنت، سجّل الدخول الآن وغيّر كلمة المرور.",
    },
  },
};

export function renderAccountEmail(
  kind: AccountEmailKind,
): { subject: string; text: string; html: string } {
  const { en, ar } = COPY[kind];
  const text = [
    en.h,
    "",
    ...en.p,
    "",
    en.note ?? "",
    "",
    "---",
    "",
    ar.h,
    "",
    ...ar.p,
    "",
    ar.note ?? "",
  ]
    .join("\n");
  return {
    subject: `${en.subject} · ${ar.subject}`,
    text,
    html: emailHtml(en, ar),
  };
}

/** Sends one mail. Returns false on any failure (callers never block on it); logs no address and no key. */
export async function sendAccountEmail(
  deps: { fetch: typeof fetch; apiKey: string | undefined; from: string },
  to: string,
  kind: AccountEmailKind,
): Promise<boolean> {
  if (!deps.apiKey) return false;
  const mail = renderAccountEmail(kind);
  try {
    const res = await deps.fetch(RESEND_URL, {
      method: "POST",
      headers: { authorization: `Bearer ${deps.apiKey}`, "content-type": "application/json" },
      body: JSON.stringify({ from: deps.from, to: [to], ...mail }),
    });
    if (!res.ok) console.error("account_email_failed", kind, res.status);
    return res.ok;
  } catch {
    console.error("account_email_failed", kind, "network");
    return false;
  }
}
