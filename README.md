# spending-tracker

Single-user personal finance app: bank SMS arrive through an iOS Shortcut, get parsed and categorized, and feed obligations, budgets and insights. Flutter (iOS-first) + Supabase. Planning docs are in `docs/` (start with `01-prd.md`); `CLAUDE.md` holds the working rules.

## Layout
| Path | What |
|---|---|
| `app/` | Flutter app (Cupertino, Riverpod, go_router, en/ar) |
| `supabase/migrations/` | SQL schema, RLS policies, seed defaults |
| `supabase/functions/` | Edge Functions (Deno): `ingest`, `rotate-token`, shared helpers |
| `supabase/tests/db/` | RLS isolation test and a local Postgres runner |
| `scripts/` | `get-ingest-token.ps1` (Windows) |
| `codemagic.yaml` | iOS build to TestFlight (not run yet) |

## Checks (same as CI)
```bash
cd app && flutter pub get && flutter analyze && flutter test
cd supabase/functions && deno lint && deno test
bash supabase/tests/db/run_local.sh     # needs a local Postgres server (apt install postgresql)
```
Flutter is pinned to 3.47.9; versions of every package are listed in `docs/02-tech-requirements.md`.

## Environment variables
Names only, see `.env.example`. The app needs none to run: the project URL and publishable key are public and default in `app/lib/config.dart`.

## Supabase project
Deploying with the CLI: `supabase functions deploy ingest --no-verify-jwt` (the Shortcut cannot send a JWT; `supabase/config.toml` sets this too).

Project `spending-tracker` (ref `evepfssanoffnwtqjmyq`, region ap-south-1). Migrations in this folder were applied with the Supabase connector, so their remote version numbers differ from the file names. Before wiring `supabase db push` into CI, run `supabase migration repair` to align the history.

## Parsers and fixtures
Each bank has a parser in `supabase/functions/_shared/parsers/` and real, redacted fixtures in `supabase/tests/fixtures/<sender>/` (`docs/07-sms-catalog.md` lists every template). Adding a format = add a fixture first, then make it pass. Unknown formats are never guessed: they stay in the app's *Needs review* list.

## Milestone 1 setup (owner steps)
1. **Create your user.** Supabase dashboard, project `spending-tracker`: Authentication, Users, *Add user*, tick auto confirm. Defaults (categories, own accounts, settings) are created automatically.
2. **Turn off sign-ups.** Authentication, Sign In / Providers, switch off *Allow new users to sign up* and anonymous sign-ins. (`supabase/config.toml` records the same settings for CLI deploys.)
3. **Get an ingest token.** On Windows run `powershell -ExecutionPolicy Bypass -File scripts\get-ingest-token.ps1`. Copy the token it prints (shown once; running it again replaces it).
4. **Shortcuts test on your iPhone** (this is the riskiest assumption in the project). Shortcuts app, Automation, `+`, *Message*:
   - Sender / message filter: try choosing the sender `alinma`. If iOS will not let you pick an alphanumeric sender, use *Message Contains* with a word every alinma SMS has (for example `SAR`) and tell me.
   - Run Immediately, and turn *Notify When Run* off.
   - Action *Get Contents of URL*: URL `https://evepfssanoffnwtqjmyq.supabase.co/functions/v1/ingest`, Method `POST`, Headers `X-Ingest-Token` = your token, Request Body `JSON` with `sender` (Shortcut Input, Sender), `body` (Shortcut Input, Content) and `received_at` (Current Date, ISO 8601).
   - Wait for a real SMS from that bank, or send yourself a test.
   - Only the `X-Ingest-Token` header is needed (no Authorization header). Replacing the token later breaks every Shortcut until you paste the new one in, and a Shortcut with *Notify When Run* off fails silently. If the app's *last message received* looks stale, check the Shortcut first.
5. **Tell me:** did it run without a prompt? what does the sender show as? Check the result in the app (More, Ingest token shows *last message received*) or in the dashboard table `raw_messages`.

The message bodies stored at this stage are unparsed (`needs_review`). One-time codes are stored as `[redacted]`.
