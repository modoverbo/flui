-- whop_webhook_events keeps only a minimised payload (ADR 0004, decision 9): a CHECK rejects
-- anything but the debugging fields, and the migration's backfill scrubs already stored raw bodies.
begin;
select plan(9);

select has_check('public', 'whop_webhook_events', 'the table has a check constraint');
select is(
  (select count(*)::int from pg_constraint
    where conrelid = 'public.whop_webhook_events'::regclass
      and conname = 'whop_webhook_events_payload_minimized'),
  1,
  'the payload minimisation check exists'
);

select lives_ok(
  $$ insert into public.whop_webhook_events (webhook_id, event_type, payload) values
       ('msg_min_1', 'membership.activated',
        '{"timestamp":"2026-09-13T11:59:00Z","membership_id":"mem_1","plan_id":"plan_monthly","status":"trialing","app_user_id":"5b7f6a3e-2d1c-4b9a-8f0e-1a2b3c4d5e6f"}') $$,
  'a minimised payload is accepted'
);
select lives_ok(
  $$ insert into public.whop_webhook_events (webhook_id, event_type, payload) values ('msg_min_2', 'payment.succeeded', '{}') $$,
  'an empty payload is accepted (events with nothing to keep)'
);
select throws_ok(
  $$ insert into public.whop_webhook_events (webhook_id, event_type, payload) values
       ('msg_raw_1', 'membership.activated',
        '{"type":"membership.activated","data":{"id":"mem_1","user":{"email":"buyer@example.com","name":"Ana"}}}') $$,
  '23514', null,
  'a raw Whop body (buyer identity) is rejected'
);
select throws_ok(
  $$ insert into public.whop_webhook_events (webhook_id, event_type, payload) values
       ('msg_raw_2', 'membership.activated', '{"membership_id":"mem_1","email":"buyer@example.com"}') $$,
  '23514', null,
  'an extra top-level key next to allowed ones is rejected'
);
select throws_ok(
  $$ insert into public.whop_webhook_events (webhook_id, event_type, payload) values ('msg_raw_3', 'x', '[]') $$,
  '23514', null,
  'a non-object payload is rejected'
);

-- Backfill: replay the migration's UPDATE against a legacy raw row (constraint lifted inside this
-- rolled-back transaction, as it did not exist when that row was written).
alter table public.whop_webhook_events drop constraint whop_webhook_events_payload_minimized;
insert into public.whop_webhook_events (webhook_id, event_type, payload) values
  ('msg_legacy_1', 'membership.activated',
   '{"id":"msg_legacy_1","type":"membership.activated","timestamp":"2026-09-13T11:59:00Z",
     "data":{"id":"mem_legacy","status":"trialing","plan":{"id":"plan_monthly","title":"Flui"},
             "metadata":{"app_user_id":"5b7f6a3e-2d1c-4b9a-8f0e-1a2b3c4d5e6f"},
             "user":{"email":"buyer@example.com","name":"Ana Buyer"}}}'),
  ('msg_legacy_2', 'membership.deactivated',
   '{"type":"membership.deactivated","data":{"id":"mem_v","plan_id":"plan_yearly","email":"buyer@example.com"}}');

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

select is(
  (select payload from public.whop_webhook_events where webhook_id = 'msg_legacy_1'),
  '{"timestamp":"2026-09-13T11:59:00Z","membership_id":"mem_legacy","plan_id":"plan_monthly","status":"trialing","app_user_id":"5b7f6a3e-2d1c-4b9a-8f0e-1a2b3c4d5e6f"}'::jsonb,
  'backfill keeps only the debugging fields of a legacy row and drops the buyer identity'
);
select is(
  (select payload from public.whop_webhook_events where webhook_id = 'msg_legacy_2'),
  '{"membership_id":"mem_v","plan_id":"plan_yearly"}'::jsonb,
  'backfill handles the versioned layout and drops absent fields'
);

select * from finish();
rollback;
