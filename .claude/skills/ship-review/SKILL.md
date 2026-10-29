---
name: ship-review
description: Adversarial multi-agent review before shipping or deploying. Use when the user says ship review, pre-ship check, ready to deploy, before I push to prod, or asks for agents to poke holes in the code.
---

# Ship review

Assume the code is NOT secure just because it looks fine. Run independent reviewers, make them challenge each other, fix, then review again.

## Round 1: independent reviewers (run in parallel as subagents)
Spawn 3 subagents. Give each only the diff/repo, not each other's output:
1. **Security**: auth, authorization, IDOR, injection, SSRF, secrets in client bundles, CORS, rate limits. Use the `security-audit` skill in guidance mode.
2. **Trust boundaries**: anything the client sends that the server trusts. Prime example: users editing their own usage limits, credits, plan, role, price, discount or order totals through a request body, local storage, or a DB row with weak row-level security.
3. **Correctness**: logic bugs, race conditions, missing error handling, payment/webhook idempotency.

## Round 2: challenge
Spawn a fresh subagent that tries to DISPROVE every finding from round 1 with evidence from the source. Keep only findings that survive. Flag anything uncertain as "unconfirmed".

## Fix
Fix surviving findings with the smallest change. Add a regression test for each.

## Round 3: re-review
Run a fresh reviewer on the fixes only. Repeat until nothing high or critical is left.

## Always check (models miss these)
- Server recomputes prices, totals, limits and permissions. Never trust client values.
- Supabase/Firebase: RLS on every table, and users can't update their own `role`, `credits`, `plan`, `is_admin` columns.
- Admin routes check the role server-side, not just hidden in the UI.
- No API keys or service-role keys in frontend code or git history.
- Webhooks verify signatures.
- Run Claude Code's built-in `/security-review` as well.

## Optional second model
If the user has another coding agent (Codex, etc.), suggest running the same review there and pasting its findings back for the challenge round.

## Output
A short table: finding | severity | status (fixed / unconfirmed / rejected) | file:line.
