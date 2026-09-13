# ADR 0002: Supabase instead of Neon

- **Status:** Accepted
- **Date:** 2026-09-13
- **Evidence:** [research/mvp-frontend-only.md](../research/mvp-frontend-only.md)

## Context

The MVP must validate the idea with **$0 infrastructure except Vercel Pro** and **no custom
backend**. The founder's rule was to keep Neon unless it cannot work frontend-only for a Flutter app.

Findings (verified 2026-09-13):

- Neon Auth (managed Better Auth) is Beta and cookie-based. It does not support separate frontend
  and backend deployments, breaks on Safari/iOS (third-party cookie blocking) without a same-origin
  proxy, has no Dart SDK and no documented mobile path.
- Keeping Neon would require Neon Data API + Firebase Auth + a Cloudflare Worker: three vendors and a
  Beta Data API.
- Supabase offers Auth, Postgres with RLS and Edge Functions in one vendor, with the official
  `supabase_flutter` SDK for web and mobile, and a free plan without a commercial-use ban.

## Decision

Use **Supabase**:

- **Auth:** email/password now, Google later.
- **Postgres with RLS on every table**, accessed directly from the app through PostgREST.
- **One Edge Functions area** (`supabase/functions`) used only for Whop (checkout and webhook).

## Consequences

- No backend server to build or host; security is expressed as SQL (grants, RLS, security definer
  functions) and tested with pgTAP.
- Free-plan limits apply: 2 active projects, 500 MB database, 50,000 MAU, 500,000 function
  invocations, and **projects pause after 1 week of inactivity** (mitigated by
  `supabase-keepalive.yml`; upgrade to Pro once there are paying users).
- Vendor lock-in is moderate: the schema is plain Postgres, but Auth and RLS helpers
  (`auth.uid()`) are Supabase-specific.

## Alternatives considered

| Option | Why not |
|--------|---------|
| Neon + Neon Auth | Beta, cookie-based, no split deployments, Safari/iOS issues, no mobile |
| Neon Data API + Firebase Auth + Cloudflare Worker | Three vendors, Beta Data API, more moving parts |
| Neon + own API (Hono on Vercel Functions + Better Auth) | Violates "no custom backend" |
| Firebase only | Loses relational modeling and SQL-tested RLS |
