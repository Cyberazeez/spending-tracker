# spending-tracker

> Claude reads this file at the start of every session, local or cloud.

## What this is
Single-user personal finance app for Azeez (Riyadh, iPhone, no Mac). Captures every purchase from bank SMS via iOS Shortcuts, categorizes it, tracks regular obligations (bills, horse housing, loan, credit card statement), shows where money goes, suggests savings and enforces budgets. SAR, Asia/Riyadh, week starts Sunday, 24-hour time, English and Arabic UI.

## Stack
- **Client:** Flutter (iOS-first, Cupertino), Riverpod, go_router, fl_chart. Folder `app/`.
- **Backend:** Supabase (Postgres + RLS, Auth email login, Edge Functions in Deno/TypeScript). Folder `supabase/`.
- **AI:** Claude API from Edge Functions only, optional switch, 5 USD/month cap.
- **iOS builds:** Codemagic (free personal plan, macOS minutes only for iOS milestones) to TestFlight. Linux CI on GitHub Actions.
- Exact versions and reasons: `docs/02-tech-requirements.md`.

## Commands (nothing exists yet; these are the planned ones)
- Flutter: `cd app && flutter pub get`, `flutter analyze`, `flutter test`
- Edge Functions: `cd supabase/functions && deno test --allow-read` and `deno lint`
- Supabase local: `supabase start`, `supabase db reset`, `supabase db lint` (needs Docker; not available in cloud sessions)
- Deploy: functions and migrations deploy from CI on merge to `main`. iOS builds are started by hand in Codemagic.

## How we work (rules for Claude)
1. **Read `docs/` first** (01 to 07). They are the source of truth. `docs/07-sms-catalog.md` lists every known SMS format.
2. **Never commit or push to `main`.** Work on a branch and open a pull request. In cloud sessions the harness assigns the branch name.
3. **Before opening a PR:** run the tests and the build, then run the `ship-review` skill. Fix anything high or critical.
4. **Fill in the PR template** (`.github/pull_request_template.md`) honestly, including what you could not test.
5. **Deploys only happen by merging to `main`.** Never deploy by hand or push build output.
6. **No secrets in code or git.** Real values go in Supabase function secrets, Codemagic variables or `.env` (gitignored). Add variable names to `.env.example`. Never print the ingest token, service role key, Claude API key or App Store Connect key.
7. Keep `docs/` up to date when a decision changes.
8. Small commits with clear messages (`feat: ...`, `fix: ...`, `docs: ...`).
9. **Do not build parsers without a real redacted fixture** in `supabase/tests/fixtures/<sender>/`. Never invent SMS formats.
10. **Privacy:** fixtures and test data contain no real names, phone numbers, IBANs or account numbers (last 4 only). Nothing like that is ever sent to the Claude API.
11. **Stop after each milestone** in `docs/06-implementation-plan.md`, summarize what works and what was not tested, and wait for Azeez's go.
12. Ask before creating paid resources (Supabase paid plan, Codemagic billing, Apple account items).

## Project notes
- Timezone is fixed UTC+3 (no DST). Bank SMS timestamps are Riyadh local time.
- Money is integer halalas. Never floats.
- Internal transfers (own accounts, wallet top-ups, credit card payoff) are excluded from spend and income.
- Salary: expected net deposit 14,100 SAR; anything above is flagged as an anomaly.
- Only SMS ingestion. No wallet notifications, email parsing or Open Banking.
- Sender IDs: `alinma`, `barq app`, `D360 Bank`, `STC Bank`, `SNB-AlAhli`, `AlRajhiBank`, `900`.
- Unrelated project in the same session: `weekly-lunch-bot`. Do not read, change or deploy it from here.
