-- Minimises public.whop_webhook_events.payload (ADR 0004, decision 9).
--
-- The table is a service-role-only idempotency log that survives account deletion, yet it stored
-- each Whop event body verbatim, which can include the buyer's Whop identity (email, name, ...).
-- The whop-webhook function now stores only the fields needed to debug idempotency and ordering:
--   timestamp, membership_id, plan_id, status, app_user_id.
--
-- 1. Backfill: rewrite every stored row that is not already in that shape, dropping the rest.
-- 2. Guard: a CHECK keeps the payload to those keys (and tiny), so a regression in the function
--    fails loudly instead of quietly persisting PII again.
--
-- webhook_id, event_type, received_at and processed_at are untouched, so idempotency is unchanged.

update public.whop_webhook_events
set payload = jsonb_strip_nulls(jsonb_build_object(
  'timestamp', payload ->> 'timestamp',
  'membership_id', payload #>> '{data,id}',
  'plan_id', coalesce(payload #>> '{data,plan,id}', payload #>> '{data,plan_id}'),
  'status', payload #>> '{data,status}',
  'app_user_id', payload #>> '{data,metadata,app_user_id}'
))
where jsonb_typeof(payload) is distinct from 'object'
   or payload - array['timestamp', 'membership_id', 'plan_id', 'status', 'app_user_id'] <> '{}'::jsonb;

alter table public.whop_webhook_events
  add constraint whop_webhook_events_payload_minimized check (
    jsonb_typeof(payload) = 'object'
    and payload - array['timestamp', 'membership_id', 'plan_id', 'status', 'app_user_id'] = '{}'::jsonb
    and octet_length(payload::text) < 1024
  );

comment on column public.whop_webhook_events.payload is
  'Minimised Whop event: timestamp, membership_id, plan_id, status, app_user_id only. Never the raw body (buyer PII).';
