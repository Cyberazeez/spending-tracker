# Public sign-up: Apple and Google sign-in, forgot password, email confirmation, "account active again" email (design, 2026-11-05)

Owner decisions: no invite codes (AI is for paying customers only; see `docs/06-implementation-plan.md`), paid AI plans come last. This batch makes the app safe and normal to open to the public. **Nothing here is built yet; this is the plan for the owner to approve.**

## Why these four go together
- Apple requires **Sign in with Apple** in any app that offers another third-party sign-in (Google), so they ship together.
- Forgot password, email confirmation and the "account active again" email all need the same thing first: **a real email sender**. Supabase's built-in email service is limited to a handful of messages per hour for the whole project and is meant for testing only (third-party sources say about 2 per hour; verify in the dashboard), so one forgotten password at the wrong moment would block everyone.

## Order of work (each its own pull request, owner tests on TestFlight in between)
1. **Email sender** (no app change): custom SMTP in Supabase Auth, branded email templates (English and Arabic text in one message), redirect URLs allowed.
2. **Forgot password + email confirmation** (app + Supabase settings).
3. **"Account active again" email** (Edge Function).
4. **Apple and Google sign-in** (app, iOS project, Supabase providers).
5. Last, separately: paid AI plans.

## 1. Email sender
- Provider: any SMTP service (for example Resend, Postmark, Amazon SES) with a **sending address on a domain the owner controls** (SPF and DKIM set up, otherwise mail lands in spam). Credentials go in Supabase Auth > SMTP settings, never in git.
- Templates (confirm sign-up, reset password, change email) edited in the Supabase dashboard; subject and body bilingual.
- Allowed redirect URLs in Supabase: the app's deep link (below).

## 2. Forgot password and email confirmation
- **Deep link back into the app.** Register a URL scheme for the app (proposal: `spendingtracker://auth`). The emails link to Supabase, which redirects to this URL with the session; `supabase_flutter` picks it up and emits a `passwordRecovery` event.
- **Forgot password:** "Forgot password?" under Sign in -> email field -> `resetPasswordForEmail(redirectTo: spendingtracker://auth/reset)` -> the same neutral message whether or not the account exists (no account enumeration) -> the link opens the app on a **Set a new password** screen (new password twice, min 8, `updateUser`). Rate limited on the Supabase side; the app also disables the button for 60 s after a send.
- **Email confirmation:** turn "Confirm email" **on** in Supabase. Sign-up then shows "Check your email" (with Resend and Change email), and the confirm link opens the app signed in. Existing accounts are already confirmed (they signed up with confirmation off, Supabase marked them confirmed), so nobody is locked out. Unconfirmed accounts cannot use the app or the ingest/AI functions (the session does not exist until confirmed).
- Password change still asks for the current password (already on in Supabase).
- Tests: form validation, the neutral message, the recovery event routing to the new-password screen, error mapping. Not testable here: the real email round trip (needs a device and the sender).

## 3. "Account active again" email
- Trigger: `reactivate_my_account()` or a sign-in that cancels a pending deletion. Supabase Auth does not send this kind of message, so a small Edge Function `send-account-email` calls the email provider's HTTP API (key in a Supabase secret) with a bilingual template: "Your account is active again. If this was not you, change your password now."
- Also worth sending: "deletion requested" (with how to cancel) so a stolen session cannot silently schedule a deletion. Same function.
- Rate limited per user (reuses `bump_rate_limit`). Failure to send never blocks the reactivation.
- Tests: function unit tests with a fake provider (payload, language, no secrets logged, rate limit).

## 4. Apple and Google sign-in
- **Apple (native):** `sign_in_with_apple` package -> Apple ID token + nonce -> `signInWithIdToken(OAuthProvider.apple)`. Needs the **Sign in with Apple capability** on the app's App ID (Apple Developer account), the entitlement in the iOS project, and the bundle ID added in Supabase > Authentication > Providers > Apple. The native iOS flow needs no Services ID or client-secret key (those are for web/Android); verify against Supabase's current docs while building. Apple may hide the real email (private relay); that is fine.
- **Google (native):** `google_sign_in` package -> `signInWithIdToken(OAuthProvider.google)`. Needs a Google Cloud project with an **iOS OAuth client** (bundle ID) and a **Web OAuth client**; both client IDs go into Supabase > Providers > Google (comma separated) with "Skip nonce check" on for iOS, plus the reversed client ID as a URL scheme in the iOS project.
- **UI:** two buttons under the email form on Sign in and Sign up ("Continue with Apple", "Continue with Google"), Apple first. First social sign-in creates the account and seeds categories through the existing sign-up trigger; a name from Apple (given only on the first sign-in) is saved to the profile.
- **Same email, two methods:** Supabase links identities with the same verified email. Decision proposed: allow linking only when the email is verified by the provider; otherwise show "an account with this email exists, sign in with your password".
- Account deletion and the 30-day grace flow must work for social accounts (no password to re-enter: ask them to sign in again with the same method, then confirm). Needs a small change in `delete-account`.
- Tests: button visibility, error and cancel handling (user cancels the Apple/Google sheet is not an error), nonce generation, the delete flow without a password. Not testable here: the real Apple and Google sheets.

## What the owner has to provide or do
| # | What | Where |
|---|---|---|
| 1 | A **sending address on a domain you own** and an account with an email provider (I recommend Resend: free tier, simple SMTP and HTTP API). Tell me the provider and give me the SMTP details and API key **in the Supabase dashboard / secrets, not in chat**. | Domain DNS (SPF/DKIM), provider, Supabase |
| 2 | Turn on **Sign in with Apple** for the App ID `com.cyberazeez.spendingtracker`, then in Codemagic the signing profile is regenerated. | Apple Developer > Identifiers |
| 3 | Create the **Google Cloud project** with an iOS client (bundle ID) and a Web client; send me the two client IDs (they are not secret). | console.cloud.google.com |
| 4 | In Supabase: enable the Apple and Google providers (steps given when we get there), add the redirect URL, turn "Confirm email" on **only when I say** (after the sender works). | Supabase dashboard |

## Risks
- Turning "Confirm email" on before the sender works blocks every new sign-up. Order of work prevents this.
- A wrong DNS record sends mail to spam. Test with a real inbox before switching confirmation on.
- Apple review: Sign in with Apple, account deletion in the app (already built) and a privacy policy URL are all expected.
