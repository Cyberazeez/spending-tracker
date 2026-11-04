# Family sign-up, stage B: invite codes and the sign-up screen (design, 2026-11-04).

> **Decision 2026-11-04 (owner):** for the closed family test no invite codes are built. Only TestFlight invitees have the app, so the app gets a plain sign-up screen (name, email, password) using Supabase Auth directly; the owner turns on "Allow new users to sign up" and turns off "Confirm email" in the dashboard. The rest of this document (codes, `signup` function, Invite family screen) is the design for the public release and is **not built**.

Decided earlier: invite-only, email + password. Stage A (clean seeds, per-user AI cap) is live. Supabase Auth's own
"allow new users to sign up" stays **off**; the only door is the `signup` function below.

## Flow
1. The owner opens **More > Account > Invite family**, types who it is for (a label, e.g. "Sara"), taps Create. A code like `K7QM-4TXD` is shown once with a Share button (iOS share sheet). It works once and expires after 7 days.
2. The relative installs the TestFlight build, taps **Create account** on the login screen, enters name, email, password (twice) and the code.
3. The app calls `signup`. On success the app signs in with the same email and password and lands on a welcome screen (stage C).

## Server
- **Table `invites`**: `id`, `created_by`, `label` (max 40), `code_hash` (sha256, unique; the code itself is never stored), `created_at`, `expires_at`, `used_at`, `used_by`, `revoked_at`. RLS: a user reads and revokes only invites they created; **insert only through the function** `create_invite(label)` (security invoker is not enough, it must check the right to invite).
- **Who may invite**: new column `settings.can_invite boolean not null default false` (not client-writable, like the AI cap), set to true by hand for the owner only. Relatives cannot invite others.
- **`create_invite(p_label)`** (authenticated, checks `can_invite`): makes a random 8-character code from an unambiguous alphabet (no 0/O/1/I), stores its hash and expiry, returns the code once.
- **Edge function `signup`** (no JWT, `verify_jwt = false`): body `{email, password, name, code}`.
  1. Validate shape: email format, password 8 to 72 characters, name up to 60, code format.
  2. Rate limit before anything else: per IP (5 a minute, 30 a day) and per code attempts (10 wrong tries lock that IP for the day). Uses `bump_rate_limit` with a fixed system id and a hashed IP bucket.
  3. **Claim the code atomically** (`update invites set used_at = now() where code_hash = $1 and used_at is null and revoked_at is null and expires_at > now() returning id`). Nothing found means one generic answer `invalid_code`, so nobody can tell "used" from "never existed" from "expired".
  4. Create the user with the admin API (`email_confirm: true`, the invite is the proof of the email owner; `user_metadata.name`). The stage A trigger seeds the clean account.
  5. Set `invites.used_by`. If creating the user fails, **release the claim** (`used_at = null`) so the code is not burnt by a typo; duplicate email returns `email_taken`.
  6. Returns `{ok: true}` only; no user id, no token. The app then signs in normally.
- Errors the app can show: `invalid_code`, `email_taken`, `weak_password`, `invalid_email`, `rate_limited`, `server_error`.

## App
- **Login screen**: a "Create account" text button under Sign in (new look).
- **Sign-up screen** (pushed page, swipe back works): name, email, password, repeat password, invite code (auto-uppercase, dash after 4), one accent button. Same error style as login. Arabic and English, 2x text tested.
- **Invite family screen** (More > Account, shown only when `settings.can_invite`): Create invite (label), code shown once with Copy and Share, list of invites with status (waiting, used by name, expired, revoked) and Revoke for waiting ones. The code is never shown again; a lost code is revoked and replaced.
- The invite list reads `invites` through RLS; the name of who used it comes from a small view that exposes only `display name`, never email.

## Tests
- Deno: `signup` handler with fake deps (valid flow, wrong/used/expired/revoked code all give the same answer, claim released on failed user creation, rate limits, password and email rules, no user data in the response).
- DB (local): invites RLS (creator only), `create_invite` refused without `can_invite`, code hash unique, expired code not claimable.
- Flutter: sign-up form validation and error mapping, Invite family screen (hidden without the right, create shows code once, revoke), login link, RTL and 2x text.

## Deploy order after merge (each on the owner's go)
1. Apply the migration; the owner runs one statement to set `can_invite = true` for himself (I will do it on his go).
2. Deploy `signup` (verify_jwt off).
3. Confirm Supabase Auth "allow new users to sign up" is still off (dashboard, owner checks).
4. TestFlight build; test with one family member's invite, then delete the test account (account deletion lands in stage C, so until then remove it in the dashboard).

## Not in this stage
Welcome checklist and first-run account setup (stage C), account deletion (stage C), Sign in with Apple / Google (later, public release).

## Open points for the owner (defaults in brackets)
- Invite validity [7 days].
- Name required at sign-up [yes].
- Can the owner see who signed up with which code [yes: label and first name only, never email or data].
