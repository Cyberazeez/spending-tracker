# spending-tracker

Personal finance app for iPhone. Bank SMS reach the app through an iOS Shortcuts automation (the in-app "Add bank message" action), get parsed and categorized, and feed spending, bills, budgets, insights and widgets. SAR, Asia/Riyadh, English and Arabic. Flutter (Cupertino, Riverpod) + Supabase (Postgres with RLS, Edge Functions in Deno). Planning docs are in `docs/` (start with `01-prd.md`); `CLAUDE.md` holds the working rules.

## Status
Live on TestFlight for the owner and a small closed group of invited family testers. Built so far: SMS capture and parsing for Alinma, Barq, D360, STC, SNB and Al Rajhi; categories with AI suggestions (optional, capped); bills and instalments grouped by billing cycle; credit card statements; budgets and insights; home-screen widgets; bill reminders; account deletion with a 30-day grace period; a step-by-step Shortcuts guide inside the app. Not built yet (public release): Apple/Google sign-in, forgot password, email confirmation, paid AI plans (AI only for paying customers; no invite codes). After release: CSV import/export. See `docs/06-implementation-plan.md`.

## Layout
| Path | What |
|---|---|
| `app/` | Flutter app (iOS first; `lib/features/*`, design layer in `lib/ui/`, strings in `lib/l10n/` en + ar) |
| `app/ios/` | Runner, the Shortcuts action (App Intent) and the widget extension (Swift) |
| `supabase/migrations/` | SQL schema, RLS policies, seed defaults |
| `supabase/functions/` | Edge Functions: `ingest`, `rotate-token`, `categorize-batch`, `insights-tips`, `ai-chat`, `delete-account`, `widget-summary`, shared parsers and helpers |
| `supabase/tests/` | RLS isolation test with a local Postgres runner, redacted SMS fixtures |
| `docs/` | PRD, tech choices, app flow, design brief, backend schema, plan, SMS catalog |
| `codemagic.yaml` | iOS build to TestFlight (started by hand in Codemagic) |

## Checks (same as CI)
```bash
cd app && flutter pub get && flutter analyze && flutter test
cd supabase/functions && deno lint && deno test --allow-read
bash supabase/tests/db/run_local.sh     # needs a local Postgres server
```
Flutter is pinned to 3.47.9; package versions are in `docs/02-tech-requirements.md`. Do not run `deno fmt` on the whole functions folder.

## Working rules (short)
- Never commit to `main`; work on a branch and open a pull request. CI must be green.
- No secrets in git. Variable names only in `.env.example`; real values live in Supabase function secrets, Codemagic variables or `.env` (gitignored).
- Money is integer halalas. Fixtures and test data contain no real names, phone numbers, IBANs or full account numbers.
- No SMS parser without a real redacted fixture in `supabase/tests/fixtures/<sender>/`.

## Releasing
- **App**: merge to `main`, then start the iOS build in Codemagic by hand; it uploads to TestFlight.
- **Database**: new files in `supabase/migrations/` are applied to the Supabase project by hand after the owner's go.
- **Edge Functions**: deployed by hand (bundle each function, then deploy with the Supabase connector or CLI). `ingest` and `widget-summary` are deployed without JWT verification (callers use their own tokens); the others verify the user's JWT. After deploying, check the version number in the Supabase dashboard.
- The Supabase project is `spending-tracker` (ref `evepfssanoffnwtqjmyq`, region ap-south-1). Migration versions on the remote differ from the file names because they were applied with the connector.

## Setting up SMS capture
In the app: More > SMS capture > "Show me how, step by step" (it also opens once for a new account). In short: Shortcuts > Automation > + > Message, filter "Message contains SAR" (add copies for Arabic or SR messages), Run Immediately on, action "Add bank message" with Message and Sender filled. `docs/08-setup-guide.md` describes the one-automation-per-sender variant.

## Public release checklist
Findings from the 2026-11-05 ship-review that were accepted for the closed test are listed under "Before publishing" in `docs/06-implementation-plan.md` (AI defaults and open sign-up, quotas, token expiry, per-IP limits and more).
