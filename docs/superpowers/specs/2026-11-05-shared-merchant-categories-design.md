# Shared merchant categories ("learn once, help everyone") (design, 2026-11-05)

Status: **design only, nothing built.** Benefit for paying customers only (owner decision 2026-11-05).

## Goal
When one person marks a merchant (for example the text a bank shows for a fuel station such as "KFIA") as Fuel, other users who buy from the same merchant get Fuel automatically, with no AI call and no manual step.

## How it works
- **Contribute:** when a user manually categorises a purchase with a **default (system) category**, the pair `(merchant_norm, category key)` is added as **one vote per user per merchant** (the latest vote of that user replaces the earlier one). Nothing else is shared: no amount, date, card or account number, no user id exposed to other users. Custom categories a user invented are never shared. Transfers, `acct:` and `card:` rules, and merchants that look personal (names after transfer keywords, long digit runs) are never shared. AI-guessed rules do not count as votes.
- **Promote:** a merchant becomes a **community rule** only when at least 3 distinct users agree and at least 80% of the votes name the same category. A split vote stays unpromoted. A small admin table lets the owner pin or block a merchant (poisoning, wrong data).
- **Apply:** in `categorize()` a promoted community rule sits **below every personal rule** (a user's own choice always wins) and above "uncategorised". It is written as `merchant_rules.source = 'community'`, `status = 'auto_unconfirmed'`, so the app shows it as a suggestion the user can change in one tap, and a change becomes that user's own rule and a vote. Only paying accounts (`ai_allowed`-style entitlement flag, server side) get community rules applied.
- **Where it runs:** plain SQL at ingest and in a nightly refresh job. No model call, no Anthropic cost, works offline from the AI cap.

## Abuse and privacy
- One vote per user per merchant; only email-confirmed accounts older than 7 days vote; per-user vote rate limit.
- Votes live in a table that clients cannot read (RLS: no client access, service role only); only the promoted `(merchant_norm, category key)` list is readable by the apply function.
- Consent: a switch in Account > Privacy "Help improve categories (shares merchant names and categories only)". Proposed default **on** for everyone, shown in the privacy note and the store listing; turning it off removes the user's votes. Free users contribute, paying users benefit.
- Kill switch: server flag to stop promoting or applying.

## Tackle plan
1. Decide consent default and thresholds (open decisions below).
2. Migration: `merchant_votes` (user_id, merchant_norm, category_key, updated_at, unique per user+merchant), `community_rules` (merchant_norm, category_key, votes, agree_pct, status, pinned/blocked), RLS closed to clients, key column on system categories if missing.
3. Vote hook: manual recategorisation and the "update past ones" flow call a `record_vote` function (SQL, security definer, filters out the never-share cases).
4. Promotion job (`pg_cron`, nightly) and the apply step inside `categorize()` below personal rules; entitlement check.
5. App: suggestion chip "Suggested: Fuel" on community-categorised rows, Privacy switch, strings en/ar.
6. Tests: RLS (no client reads), threshold and conflict cases, personal rule beats community, custom categories never leave, switch off removes votes, free account gets no community rule.
7. Backfill option: apply a newly promoted rule to a paying user's uncategorised rows (never to rows set manually).

## Decisions (owner, 2026-11-05)
- **Consent default: on for everyone**, with an off switch in Account > Privacy (turning it off removes that user's votes) and a clear privacy note.
- **Thresholds:** at least 3 distinct users and at least 80% agreement; accounts must be email-confirmed and at least 7 days old to vote.
- Still open: whether free users see community suggestions as hints (proposed: no).
