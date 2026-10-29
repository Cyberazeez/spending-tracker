# PROJECT_NAME

> Fill in the sections marked TODO when you start the project. Claude reads this file at the start of every session, local or cloud.

## What this is
TODO: one or two lines on what the project does and who it's for.

## Stack
TODO: framework, database, auth, payments, hosting.

## Commands
- Install: TODO (e.g. `npm ci`)
- Dev server: TODO (e.g. `npm run dev`)
- Tests: TODO (e.g. `npm test`)
- Build: TODO (e.g. `npm run build`)

## How we work (rules for Claude)
1. **Read `docs/` first.** If the docs there are still empty templates, run the `spec-docs` skill before writing app code.
2. **Never commit or push to `main`.** Work on a branch named `feat/<short-name>` or `fix/<short-name>`, then open a pull request.
3. **Before opening a PR:** run the tests and the build, then run the `ship-review` skill. Fix anything high or critical.
4. **Fill in the PR template** (`.github/pull_request_template.md`) honestly, including what you could not test.
5. **Deploys only happen by merging to `main`.** Never deploy by hand or push build output.
6. **No secrets in code or git.** Real values go in `.env` (gitignored) or the hosting dashboard; add the variable name to `.env.example`.
7. Keep `docs/` up to date when a decision changes. They are the source of truth for future sessions.
8. Small commits with clear messages (`feat: ...`, `fix: ...`, `docs: ...`).

## Project notes
TODO: anything specific (brand rules, client requests, gotchas).
