---
name: spec-docs
description: Write the six planning documents before building an app or website. Use when starting a new project, before vibe coding a site/app, or when the user says spec, PRD, plan the build, or project docs.
---

# Spec docs

Before writing app code, create these six files in `docs/`. Ask the user only what you can't infer; keep each doc short and concrete.

1. `docs/01-prd.md` (product requirements): who it's for, the problem, every feature as a user story with acceptance criteria, what's out of scope.
2. `docs/02-tech-requirements.md`: stack and versions, hosting, auth, payments, third-party services, environments, and *why* each was chosen. No switching tools halfway through.
3. `docs/03-app-flow.md`: every page/screen, what's on it, where each action leads, and the empty, loading and error states.
4. `docs/04-design-brief.md`: brand colors, type, spacing, tone, 2–3 reference sites, components library. Use `design-taste-frontend` if installed.
5. `docs/05-backend-schema.md`: tables/collections, fields and types, relations, who can read and write each (row-level rules), and what is never exposed to the client.
6. `docs/06-implementation-plan.md`: build order in small phases, each ending in something testable, and the riskiest parts done first.

## Rules
- Show the user the PRD and the schema before writing the rest. These two are where wrong assumptions hurt most.
- Keep the docs updated when decisions change; they are the source of truth for later sessions.
- Point CLAUDE.md at `docs/` so future sessions read them first.
