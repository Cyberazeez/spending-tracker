/**
 * Account emails Supabase Auth does not send itself (it only sends confirm / reset / change-email mails). Sent through
 * the provider's HTTP API; the API key is a Supabase secret and is never logged. Every mail is bilingual (English,
 * then Arabic) because the account has no stored language.
 */
export type AccountEmailKind = "reactivated" | "deletion_requested";

export const FROM_DEFAULT = "Halala <halala-noreply@rawafiddata.com>";
const RESEND_URL = "https://api.resend.com/emails";

interface Copy {
  subject: string;
  lines: string[];
}

const COPY: Record<AccountEmailKind, { en: Copy; ar: Copy }> = {
  reactivated: {
    en: {
      subject: "Your account is active again",
      lines: [
        "You signed in, so the deletion of your account is cancelled and your data is kept.",
        "If this was not you, change your password now (Sign in > Forgot password?).",
      ],
    },
    ar: {
      subject: "حسابك نشط مرة أخرى",
      lines: [
        "لقد سجّلت الدخول، لذلك أُلغي حذف حسابك وبقيت بياناتك محفوظة.",
        "إذا لم تكن أنت، غيّر كلمة المرور الآن (تسجيل الدخول > نسيت كلمة المرور؟).",
      ],
    },
  },
  deletion_requested: {
    en: {
      subject: "Your account will be deleted in 30 days",
      lines: [
        "Someone asked to delete your account. It will be deleted for good in 30 days.",
        "To cancel, just sign in again before then. If this was not you, sign in now and change your password.",
      ],
    },
    ar: {
      subject: "سيُحذف حسابك بعد 30 يومًا",
      lines: [
        "طُلب حذف حسابك، وسيُحذف نهائيًا بعد 30 يومًا.",
        "للإلغاء، سجّل الدخول مرة أخرى قبل ذلك. إذا لم تكن أنت، سجّل الدخول الآن وغيّر كلمة المرور.",
      ],
    },
  },
};

export function renderAccountEmail(
  kind: AccountEmailKind,
): { subject: string; text: string; html: string } {
  const { en, ar } = COPY[kind];
  const text = [en.subject, "", ...en.lines, "", "---", "", ar.subject, "", ...ar.lines].join("\n");
  const block = (c: Copy, dir: "ltr" | "rtl") =>
    `<div dir="${dir}" style="text-align:${
      dir === "rtl" ? "right" : "left"
    }"><h2>${c.subject}</h2>${c.lines.map((l) => `<p>${l}</p>`).join("")}</div>`;
  return {
    subject: `${en.subject} / ${ar.subject}`,
    text,
    html: `${block(en, "ltr")}<hr>${block(ar, "rtl")}`,
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
