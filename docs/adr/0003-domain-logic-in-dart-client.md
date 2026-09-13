# ADR 0003: Learning domain logic in the Dart client

- **Status:** Accepted
- **Date:** 2026-09-13

## Context

flui's core rules (session planning, grading, review scheduling, hint flow, mastery transitions,
streaks) must be easy to change and test while the product is validated. There is no custom backend
(ADR 0002). The rules could live in Postgres functions, in Edge Functions or in the app.

Two kinds of data have very different risk:

| Data | If a user tampers with it |
|------|---------------------------|
| Learning data (progress, attempts, sessions, streak repairs) | Only their own learning history is affected |
| Access (entitlements, plans, content visibility) | Revenue loss and paid content exposure |

## Decision

- Implement the learning rules in **pure Dart** in `app/lib/features/*/domain`, specified in
  [learning-method.md](../learning-method.md) and covered by unit tests.
- Persist their results in RLS-protected tables where each user can only read and write their own
  rows (`daily_sessions`, `word_progress`, `exercise_attempts`, `streak_repairs`).
- Keep **access server-protected**: `entitlements` is written only by the `whop-webhook` Edge
  Function (service role), and all content tables require `has_access()` in RLS.
- Keep only cheap integrity constraints in the database (value ranges, `revealed ⇒ again`,
  exactly one correct option per exercise).

## Consequences

- Fast iteration: rules change with an app release and are tested with plain `dart test`, no
  database needed.
- Offline-friendly: the planner and grading can run without a round trip.
- A modified client can fake its own progress or streak. Accepted: it harms only that user and grants
  no paid access.
- Answers (`is_correct`) are readable by users with access. Accepted for the same reason.
- Server-side analytics must treat learning data as self-reported.
- If a rule later needs to be authoritative (leaderboards, certificates, rewards), move that rule to
  a Postgres function or an Edge Function and restrict the related writes.

## Alternatives considered

- **Postgres functions (PL/pgSQL):** authoritative, but slower to iterate, harder to unit test and
  couples product experiments to migrations.
- **Edge Functions for every write:** authoritative, but adds latency, cold starts, a larger
  attack surface and effectively a custom backend.
