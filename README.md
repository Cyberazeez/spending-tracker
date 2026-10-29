# claude-starter

Template for every new project: Claude Code setup, planning docs, security skills, CI and a PR-based release flow. Works the same in local and cloud sessions because everything lives in the repo.

## What's inside
| Path | What it does |
|---|---|
| `CLAUDE.md` | Project brief + the rules Claude follows (branches, PRs, ship-review, no secrets) |
| `docs/` | Six planning docs, filled in by the `spec-docs` skill |
| `.claude/skills/` | `spec-docs`, `ship-review`, `origin-lockdown`, `security-audit` (Cloudflare, MIT), two Strix skills (Apache-2.0) |
| `.claude/settings.json` | Advisor = Opus, blocks reading `.env`, runs `scripts/cloud-setup.sh` at session start |
| `scripts/cloud-setup.sh` | Installs dependencies in cloud sessions only (skips on your PC) |
| `.github/workflows/ci.yml` | Lint, test and build on every PR (Node and/or Python, auto-detected) |
| `.github/pull_request_template.md` | Checklist Claude fills in for every PR |
| `.github/dependabot.yml` | Weekly dependency update PRs (delete ecosystems you don't use) |

## Where each part works
| | Local (terminal / desktop Code tab) | Cloud session (claude.ai/code) | Project threads |
|---|---|---|---|
| `CLAUDE.md` | ✅ | ✅ | ✅ |
| `.claude/skills/` | ✅ | ✅ | ❌ enable the skills on your claude.ai account |
| `.claude/settings.json` (advisor, hooks, deny rules) | ✅ | ✅ | ❌ use Project settings + project instructions |
| CI, PR template, branch rules | ✅ | ✅ | ✅ (GitHub enforces them) |

So also upload the skills in `.claude/skills/` to claude.ai (Settings → Skills) once. Then they work everywhere.

## Start a new project
1. On GitHub, open this repo → **Use this template** → **Create a new repository** (keep it private).
2. Open it in a cloud session and say: *"Fill in CLAUDE.md for this project, then run spec-docs."*
3. Turn on branch protection (below) and connect your host for preview deploys.

## Add this to an existing project
In a session on that repo, say:
*"Copy CLAUDE.md, docs/, .claude/, scripts/cloud-setup.sh, .github/ and the .gitignore/.env.example rules from Cyberazeez/claude-starter into this repo without overwriting existing files. Merge settings and .gitignore instead of replacing. Fill CLAUDE.md from the existing code. Open a PR."*

## Release flow
`branch` → `PR` → CI + preview deploy + ship-review → you check the preview → **merge** → host deploys `main` to production.

Branch protection (one time per repo): **Settings → Rules → Rulesets → New branch ruleset** → target the default branch → enable *Restrict deletions*, *Block force pushes*, *Require a pull request before merging*, and *Require status checks to pass* with the `ci` check → **Create**.
