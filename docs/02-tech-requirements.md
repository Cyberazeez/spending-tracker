# 02-tech-requirements

Versions below were read from pub.dev and the Flutter release feed on 2026-10-30. Re-check before pinning in `pubspec.yaml`; once pinned, no tool switching mid-project.

## Stack
| Layer | Choice | Why |
|---|---|---|
| Client | Flutter **3.47.9** (stable, released 2026-10-29), Dart from that SDK | Owner's decision; iOS-first with Cupertino widgets |
| State | `flutter_riverpod` 3.4.3 | Owner's decision; testable without widgets |
| Navigation | `go_router` 18.1.2 | Owner's decision; deep links for notifications and widget taps |
| Backend | Supabase: Postgres, Auth, Edge Functions (Deno/TypeScript), RLS | Owner's decision; one service covers DB, auth, cron, secrets |
| Client SDK | `supabase_flutter` 2.18.3 | Official |
| Charts | `fl_chart` 1.3.0 | Owner's decision |
| Biometric lock | `local_auth` 3.0.2 | Face ID / Touch ID |
| Notifications | `flutter_local_notifications` 22.3.3 | Due dates, budget alerts. APNs push later via Supabase function |
| Widget bridge | `home_widget` 0.10.0 (+ SwiftUI WidgetKit extension) | Needs paid Apple account and an App Group |
| Dates/numbers | `intl` 0.20.3 (+ `flutter_localizations`) | en/ar, Asia/Riyadh, 24h |
| Local cache | `shared_preferences` 2.5.6 | Small summaries only (month totals, next obligations for the widget) |
| CSV / share | `csv` 8.0.0, `file_picker` 13.3.0, `share_plus` 13.3.1 | Import/export, share-sheet |
| AI | Claude API: Haiku-class (`claude-haiku-5-5`) for parsing fallback and categorization, Sonnet-class (`claude-sonnet-5-5`) for weekly tips | Cheapest model that handles Arabic extraction; stronger model only for the weekly writeup. Verify pricing in the Claude docs at milestone 3 |

`supabase_flutter`, `home_widget`, `local_auth`, `flutter_local_notifications`, `go_router` and `flutter_riverpod` each require a recent Dart SDK (3.10 to 3.12), which Flutter 3.47 satisfies.

## Repo layout
```
app/                Flutter app (lib/, test/, ios/)
supabase/
  migrations/       SQL, timestamped, applied with the Supabase CLI
  functions/
    _shared/        normalize.ts (Arabic), money.ts, dates.ts, parsers/<sender>.ts
    ingest/ rotate-token/ categorize-batch/ insights-weekly/
  tests/
    fixtures/<sender>/*.json   redacted real SMS + expected parse
    db/                        pgTAP RLS tests
docs/  scripts/  codemagic.yaml  .github/workflows/ci.yml
```

## Environments
| Env | What | Notes |
|---|---|---|
| local | `supabase start` (needs Docker, on the Windows laptop) | Parser tests run with `deno test` and need no Docker, so cloud sessions can run them |
| prod | one Supabase project (new, in the owner's org "Cyberazeez's") | Single user, so no separate staging at first. A second free project can be added as staging if needed |

Supabase Free allows 2 active projects and pauses a project after about a week with no activity; Pro is from $25/month. As a single project this is free. The weekly insights cron and daily SMS keep it active; if the app is unused for a week it pauses and the first request wakes it (restore from the dashboard if it does not).

## Auth and secrets
- Supabase Auth, email and password. Signups disabled after the owner account exists. Session persisted by the SDK; Face ID lock sits on top (re-lock on background > 30 s).
- Ingest: 256-bit random token, sent as `X-Ingest-Token`. Only SHA-256 stored. Rotation via `rotate-token`. Rate limit 60 requests/min per token.
- Secrets live only in: Supabase Edge Function secrets (`ANTHROPIC_API_KEY`, `INGEST_PEPPER`; service role key is provided by the runtime), Codemagic encrypted variables (App Store Connect API key: key id, issuer id, .p8), and a gitignored `.env`. `.env.example` lists names only. Nothing sensitive in logs: log message ids and parse status, never bodies.

## CI/CD
- **GitHub Actions (Linux, free):** `flutter analyze`, `flutter test`, `deno test`, `deno lint`, `supabase db lint` / pgTAP when Docker is available. Runs on every PR.
- **Codemagic (macOS M2):** `codemagic.yaml` with a `ios-testflight` workflow, triggered manually or on tags only. Free plan: 500 macOS M2 minutes per month on a personal account, resets monthly, not available on a Team account, one concurrent build; extra minutes are billed (about $0.095/min) only if the owner enables billing ([Codemagic pricing docs](https://docs.codemagic.io/billing/pricing/)). Signing and TestFlight via an App Store Connect API key (`integrations.app_store_connect`). Keep builds lean: cache pub and Pods, skip tests on macOS (Linux already ran them).
- **Deploys:** Edge Functions and migrations deploy from CI on merge to `main` with `supabase functions deploy` and `supabase db push`, using a Supabase access token stored as a GitHub secret. iOS builds are manual through Codemagic.
- codemagic.io, docs.codemagic.io and supabase.com are not reachable from this cloud session's network, so Codemagic pricing was confirmed through search results, not by opening the pages. Re-check before the first macOS build.

## Apple Developer account (needed from milestone 6)
Needed values: bundle ID (proposal `com.cyberazeez.spendingtracker`), App Group ID (`group.com.cyberazeez.spendingtracker`), widget extension bundle ID, team ID, App Store Connect API key, TestFlight access. Steps for the owner will be written when that milestone starts.

## Cross-cutting rules
- Money is integer halalas everywhere (Dart `int`, TS `bigint`/`number` under 2^53, Postgres `bigint`). Parsing amounts uses string math, never floats.
- Time: store UTC, convert SMS local time with a fixed +03:00. Week starts Sunday. UI 24h.
- Arabic: one normalization spec (`supabase/functions/_shared/normalize.ts`) with a mirrored Dart function; both run against the same fixture list in tests.
- RTL: use `Directionality`-aware widgets, `EdgeInsetsDirectional`, and force LTR for amounts and card digits inside Arabic text.
- Digits: show Western digits (0-9) in both languages, matching the bank SMS.
- Offline: online-first. Offline you can open the app, see the last cached month summary and next obligations, and use quick-add (queued locally, sent when online). Not available offline: transaction search, filters beyond the cached page, insights refresh, token rotation, CSV import.
- Parsers are pure functions `(sender, body, receivedAt) -> ParseResult`, no I/O, so they are tested with fixtures only.
- AI guardrails: AI off by default; every call goes through one `callClaude()` wrapper that masks account numbers, IBANs, names and balances, checks the monthly cap from `ai_usage`, logs token counts, and fails closed (returns "not parsed" instead of guessing).
