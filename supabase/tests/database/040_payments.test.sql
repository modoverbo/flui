-- Payments: plans are public (active only), entitlements are read-own-only and
-- written by the service role, webhook events are invisible to clients.
begin;
select plan(25);

select has_table('public', 'subscription_plans', 'subscription_plans table exists');
select has_table('public', 'entitlements', 'entitlements table exists');
select has_table('public', 'whop_webhook_events', 'whop_webhook_events table exists');

select is_empty(
  $$ select c.relname from pg_class c
     where c.oid in ('public.subscription_plans'::regclass, 'public.entitlements'::regclass,
                     'public.whop_webhook_events'::regclass)
       and not c.relrowsecurity $$,
  'RLS is enabled on every payments table'
);

-- Fixtures -----------------------------------------------------------------------------------
select tests.create_user('ana@example.com') as ana_id \gset
select tests.create_user('beto@example.com') as beto_id \gset

insert into public.subscription_plans (id, whop_plan_id, billing_period_days, price_cents, currency, label, sort_order, active)
values
  ('test_active', 'plan_test_active', 30, 500, 'USD', 'Plan de prueba', 98, true),
  ('test_retired', 'plan_test_retired', 365, 9900, 'USD', 'Plan retirado', 99, false);

insert into public.entitlements (user_id, whop_membership_id, whop_plan_id, status, current_period_end)
values
  (:'ana_id', 'mem_test_ana', 'plan_test', 'active', now() + interval '30 days'),
  (:'beto_id', 'mem_test_beto', 'plan_test', 'trialing', now() + interval '3 days');

insert into public.whop_webhook_events (webhook_id, event_type, payload)
values ('msg_test_1', 'membership.activated', '{}'::jsonb);

-- Plans --------------------------------------------------------------------------------------------
select tests.authenticate_as_anon();
select is((select count(*)::int from public.subscription_plans where id = 'test_active'), 1, 'anon can read active plans');
select is((select count(*)::int from public.subscription_plans where id = 'test_retired'), 0, 'anon cannot read inactive plans');
select throws_ok($$ insert into public.subscription_plans (id, whop_plan_id, billing_period_days, price_cents, currency, label)
                    values ('free', 'plan_x', 30, 0, 'USD', 'Gratis') $$, '42501', null, 'anon cannot insert plans');
select throws_ok($$ select * from public.entitlements $$, '42501', null, 'anon cannot read entitlements');
select throws_ok($$ select * from public.whop_webhook_events $$, '42501', null, 'anon cannot read webhook events');
select tests.clear_authentication();

select tests.authenticate_as(:'ana_id');
select is((select count(*)::int from public.subscription_plans where id = 'test_active'), 1, 'signed-in users can read active plans');
select throws_ok($$ update public.subscription_plans set price_cents = 1 $$, '42501', null, 'clients cannot update plans');
select throws_ok($$ delete from public.subscription_plans $$, '42501', null, 'clients cannot delete plans');

-- Entitlements ---------------------------------------------------------------------------------------
select results_eq($$ select user_id from public.entitlements $$, format($$ values (%L::uuid) $$, :'ana_id'),
  'a user only reads their own entitlement');
select throws_ok(
  format($$ insert into public.entitlements (user_id, whop_membership_id, whop_plan_id, status) values (%L, 'mem_fake', 'plan_x', 'active') $$, gen_random_uuid()),
  '42501', null, 'clients cannot insert entitlements');
select throws_ok($$ update public.entitlements set status = 'active', current_period_end = null $$, '42501', null,
  'clients cannot update entitlements');
select throws_ok($$ delete from public.entitlements $$, '42501', null, 'clients cannot delete entitlements');

-- Webhook events --------------------------------------------------------------------------------------
select throws_ok($$ select * from public.whop_webhook_events $$, '42501', null, 'signed-in users cannot read webhook events');
select throws_ok($$ insert into public.whop_webhook_events (webhook_id, event_type, payload) values ('msg_fake', 'x', '{}') $$,
  '42501', null, 'signed-in users cannot insert webhook events');
select tests.clear_authentication();

-- Service role (Edge Functions) -------------------------------------------------------------------------
select tests.authenticate_as_service_role();
select lives_ok(
  format($$ insert into public.entitlements (user_id, whop_membership_id, whop_plan_id, status, current_period_end)
            values (%L, 'mem_test_ana_2', 'plan_test', 'canceled', now())
            on conflict (user_id) do update set whop_membership_id = excluded.whop_membership_id, status = excluded.status $$, :'ana_id'),
  'the service role can upsert entitlements');
select lives_ok(
  $$ insert into public.whop_webhook_events (webhook_id, event_type, payload) values ('msg_test_2', 'payment.succeeded', '{}') $$,
  'the service role can store webhook events');
select tests.clear_authentication();

select is((select status from public.entitlements where user_id = :'ana_id'), 'canceled', 'the service role write was persisted');
select has_column('public', 'entitlements', 'trial_ends_at', 'entitlements stores the Whop trial end');

select throws_ok(
  format($$ insert into public.entitlements (user_id, whop_membership_id, whop_plan_id, status) values (%L, 'mem_x', 'plan_x', 'active') $$, :'beto_id'),
  '23505', null, 'one entitlement row per user');
select throws_ok(
  $$ update public.entitlements set status = 'paused' $$,
  '23514', null, 'entitlement status must be a known value');
select throws_ok(
  $$ insert into public.subscription_plans (id, whop_plan_id, billing_period_days, price_cents, currency, label) values ('bad', 'plan_x', 0, 100, 'USD', 'x') $$,
  '23514', null, 'billing_period_days must be positive');

select * from finish();
rollback;
