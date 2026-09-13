-- DEV ONLY. Never run against production. Not a migration and not part of seed.sql.
--
-- Grants a 7-day Whop-like trial to a local test user so the app can be used
-- without a real Whop checkout (Whop cannot deliver webhooks to localhost).
-- It writes `entitlements` as the database owner, exactly like the service role
-- used by the whop-webhook Edge Function; clients can never do this (see
-- supabase/tests/database/040_payments.test.sql).
--
-- Usage (local stack running, user already signed up in the app):
--   psql "postgresql://postgres:postgres@127.0.0.1:54422/postgres" \
--     -v email=you@example.com -f supabase/snippets/grant_dev_entitlement.sql
--
-- Without a local psql:
--   docker exec -i supabase_db_flui psql -U postgres -v email=you@example.com \
--     < supabase/snippets/grant_dev_entitlement.sql

\set ON_ERROR_STOP on

\if :{?email}
\else
  \echo 'Missing variable. Usage: psql <db-url> -v email=you@example.com -f supabase/snippets/grant_dev_entitlement.sql'
  \quit
\endif

insert into public.entitlements (
  user_id, whop_membership_id, whop_plan_id, status,
  current_period_end, trial_ends_at, cancel_at_period_end, last_event_at
)
select
  u.id,
  'mem_dev_' || replace(u.id::text, '-', ''),
  'plan_dev_local',
  'trialing',
  now() + interval '7 days',
  now() + interval '7 days',
  false,
  now()
from auth.users u
where u.email = :'email'
on conflict (user_id) do update
  set status = excluded.status,
      current_period_end = excluded.current_period_end,
      trial_ends_at = excluded.trial_ends_at,
      cancel_at_period_end = excluded.cancel_at_period_end,
      last_event_at = excluded.last_event_at
returning user_id, status, trial_ends_at;
