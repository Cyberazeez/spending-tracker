# Halala email design (draft for owner review, 2026-11-09)

One bilingual layout for every automatic email: wordmark "Halala · هللة", English block, Arabic block (right to left), a green button or code box, a short "if this was not you" line, and a footer with the support address and privacy link. Light and dark mode. Nothing here is live yet.

Source: `build.mjs` (one layout, all texts). Run `node docs/email-design/build.mjs` to rebuild `templates/*.html`, `subjects.json` and `preview.html` (open it in a browser to see all eight).

## The emails
| File | Sent when | Sent by | Where it goes live |
|---|---|---|---|
| `reset_password` | Forgot password | Supabase Auth | Authentication > Emails > Templates |
| `confirm_signup` | New account (only if email confirmation is switched on; today it is off) | Supabase Auth | same |
| `change_email` | Email change requested (goes to the new address) | Supabase Auth | same |
| `reauthentication` | A sensitive change asks for a code | Supabase Auth | same |
| `password_changed` | Password changed (security notice) | Supabase Auth | same (Security notifications) |
| `email_changed` | Email changed (security notice to the old address) | Supabase Auth | same |
| `account_deletion` | Delete my account | Edge Function `delete-account` | code: `_shared/account_email.ts` |
| `account_reactivated` | Signed in again within 30 days | Edge Function `send-account-email` | code: `_shared/account_email.ts` |

Not used by the app, so left alone: Invite user, Magic link.

## To go live (needs the owner's go)
1. Auth emails: in Supabase paste each file's HTML into its template and the subject from `subjects.json`. The placeholders (`{{ .ConfirmationURL }}`, `{{ .Token }}`, `{{ .NewEmail }}`, `{{ .Email }}`, `{{ .OldEmail }}`) are Supabase's; check the exact names against the hint under each template box when pasting.
2. Function emails: change `renderAccountEmail` to use the same layout (a small PR, deployed by the merge).
3. Send one of each to a test inbox and look at it in Gmail and Apple Mail, light and dark.

## Support replies (manual, not automatic)
Replies to `halala-support@rawafiddata.com` are written by hand. Suggested opening and sign-off, English then Arabic:

> Hi {name},
> Thanks for writing to Halala. {answer}
> If anything is unclear, just reply to this email.
> Halala support

> مرحبًا {الاسم}،
> شكرًا لتواصلك مع هللة. {الإجابة}
> إذا كان أي شيء غير واضح، يكفي أن ترد على هذه الرسالة.
> دعم هللة
