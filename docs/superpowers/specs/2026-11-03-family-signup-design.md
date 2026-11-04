# Family sign-up (design, 2026-11-03). Not built yet.

Goal (owner): let family members create their own accounts so the app can be shared for testing.

## What is single-user today (found by reading the code)
| Area | Today | Problem for a new user |
|---|---|---|
| Sign-up | Disabled in Supabase Auth; no sign-up screen | Nothing to build on the server side except enabling it safely |
| Seeds | `handle_new_user` triggers run `seed_defaults` and `seed_obligations` for **every** new auth user | A relative would get the owner's 17 bank accounts (last 4 digits), the owner's obligations (STC lines, horse housing, Murabahah, card 8119) and owner-specific categories (Horse, House Card) and merchant rules |
| AI cap | `ai_monthly_cap_halalas` is checked against the sum of **all** users' `ai_usage` | One relative could use up the owner's 5 USD |
| Parsers | Built for the owner's banks and SMS formats | Other banks land in Needs review (works, but looks empty) |
| Isolation | RLS on every table; `rls_test.sql` already proves user A cannot see user B; every function takes the user from the JWT / token | Good base. Needs a re-audit when sign-up opens |
| Account deletion | None | Apple requires in-app account deletion once the app lets people create accounts |

## Decisions (owner, 2026-11-03)
- Invite-only for family testing. Email + password for now.
- **Later, when the app goes public:** open sign-up with SSO (Sign in with Apple and Google). Keep this in mind: user creation stays in one place (the auth user + the safe seed from Stage A), and the sign-up screen is built so a provider button can be added next to the email form without redoing the seed, onboarding or account deletion. Apple's rule: once Google sign-in exists, Sign in with Apple must be offered too.

## Options that were considered
1. **Who can sign up.** Recommended: **invite-only**. The owner creates an invite code in the app (More > Invite family), the relative enters it on the sign-up screen. Open sign-up would let anyone with the TestFlight link create an account and spend the AI budget.
2. **Sign-in method.** Recommended: keep **email + password** (what exists). Sign in with Apple needs extra Apple/Supabase configuration and is not required while there is no other third-party login. Can be added later.

## Design (if invite-only + email/password)
**Stage A: make new accounts safe (server, one migration, owner approves the prompt)**
- Split the seeds: `seed_defaults` creates only generic things (settings, a neutral category list without Horse / House Card, generic merchant rules). The owner's accounts, obligations and owner-specific rules move to `seed_owner_extras`, which is run once for the existing owner row and never by the trigger. Existing data is untouched.
- AI: the cap becomes **per user** (`ai_monthly_cap_halalas` against that user's own usage) and AI stays off for new users until switched on; the owner's global ceiling stays as a second, hard limit.
- `rls_test.sql`: new cases (a fresh user has no accounts/obligations, cannot read the owner's rows, per-user AI cap).

**Stage B: invites and sign-up**
- Table `invites` (code hash, created_by, expires_at, used_by, used_at; RLS: only the creator reads their own). A code is single-use and expires in 7 days.
- Edge function `signup` (no JWT, rate limited per IP / per code): validates the code, creates the user with the Supabase admin API (email already confirmed, the invite is the proof), marks the code used, returns nothing sensitive. Signup stays **disabled** in Supabase Auth, so the function is the only door.
- App: "Create account" on the login screen (email, password, invite code); More > Invite family (owner only: create / list / revoke codes, share the code by the iOS share sheet).

**Stage C: first-run for a new user**
- Welcome checklist on Home when there are no transactions: 1) add your own accounts (bank + last 4 digits, so transfers between your own accounts are not counted as spending), 2) set up SMS capture (existing screen), 3) optional: monthly budget.
- Empty states already exist; check them for a user with no data.
- **Delete my account** in More (function removes the user and all rows; confirmation step).

**Stage D: test with a second account** before inviting anyone: create one with a code, check it sees none of the owner's data on the phone, delete it.

## TestFlight for the family
Internal testers must be added as users in App Store Connect (free, up to 100, no review). External testers via a public link need Beta App Review each build. Recommended: internal testers.

## Risks
- Parsers do not know their banks: their messages go to Needs review. Fine for testing; real support means redacted samples per bank (rule 9).
- Privacy: relatives' financial data lives in the owner's Supabase project. The owner can read it in the dashboard. Tell them, or keep the invite group to people who accept that.
- Cost: Supabase free plan limits (users, DB size, function calls) are fine for a handful of users.

## Order and deploys
Each stage is its own PR. Stage A migration is applied after merge, only on the owner's "go", before any app build that depends on it. Stages B and C need function deploys (hand deploy, owner "go").

## Status
- Stage A built 2026-11-04 (migration `20261104100000_signup_safe_seeds.sql`, per-user AI cap in both AI functions, RLS test with a third user). Decision to confirm with the owner: the all-users AI ceiling (default 5,700 halalas, about 15 USD a month; secret `AI_GLOBAL_CAP_HALALAS`).

- Stage C built 2026-11-04: welcome card, Bank accounts screen, Delete my account (`delete-account` function). Stage B invite codes were replaced by open sign-up for the closed test (see the stage B spec).
