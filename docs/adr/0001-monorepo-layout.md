# ADR 0001: Monorepo with `app/`, `supabase/` and `docs/`

- **Status:** Accepted
- **Date:** 2026-09-13

## Context

flui has three deliverables that change together: a Flutter app, a Supabase project (schema, RLS,
seed, two Edge Functions) and product documentation. A single founder plus AI agents work on it, and
most features touch both the schema and the app (for example a new column plus the Dart code that
writes it).

## Decision

One Git repository with top-level folders by deliverable:

| Folder | Content | CI workflow |
|--------|---------|-------------|
| `app/` | Flutter app (web first) | `app-ci.yml`, `web-deploy.yml` |
| `supabase/` | CLI project: `config.toml`, `migrations/`, `seed.sql`, `tests/`, `functions/`, `snippets/` | `supabase-ci.yml` |
| `docs/` | Architecture, brand, learning method, ADRs, deployment, research | — |
| `.github/workflows/` | CI/CD and keep-alive | — |

Workflows use path filters so each part only builds when it changes. No JS workspace tooling
(Nx, Turborepo): the two stacks share no build graph.

## Consequences

- A schema change and the app code that depends on it ship in one pull request.
- Documentation and ADRs live next to the code they describe.
- Path filters must be kept in sync when folders move.
- Vercel's automatic monorepo detection does not apply; deployment is driven by GitHub Actions
  (see ADR 0005).

## Alternatives considered

- **Separate repositories for app and backend:** cleaner permissions, but cross-cutting changes need
  coordinated PRs and version pinning. Not worth it for a single small team.
- **`apps/` + `packages/` workspace layout:** useful for many JS packages; adds ceremony with no
  benefit for one Flutter app and one Supabase project.
