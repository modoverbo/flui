-- has_access() truth table (Whop entitlement only), my_access() shape, and
-- hardening of SECURITY DEFINER functions.
begin;
select plan(27);

select has_function('public', 'has_access', array['uuid'], 'has_access(uuid) exists');
select has_function('public', 'my_access', 'my_access() exists');
select is((select prosecdef from pg_proc where oid = 'public.has_access(uuid)'::regprocedure), true, 'has_access is SECURITY DEFINER');
select is((select provolatile::text from pg_proc where oid = 'public.has_access(uuid)'::regprocedure), 's', 'has_access is STABLE');
select is_empty(
  $$ select p.oid::regprocedure::text
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.prosecdef
       and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%') $$,
  'every SECURITY DEFINER function in public pins its search_path'
);
select is_empty(
  $$ select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity $$,
  'every table in public has RLS enabled'
);

-- Fixtures: one user per scenario ------------------------------------------------------------------
select tests.create_user('no-entitlement@example.com') as no_entitlement \gset
select tests.create_user('trialing@example.com') as trialing \gset
select tests.create_user('trial-over@example.com') as trial_over \gset
select tests.create_user('active@example.com') as active \gset
select tests.create_user('active-open@example.com') as active_open \gset
select tests.create_user('canceled@example.com') as canceled \gset
select tests.create_user('expired@example.com') as expired \gset
select tests.create_user('past-due@example.com') as past_due \gset
select tests.create_user('period-over@example.com') as period_over \gset

insert into public.entitlements (user_id, whop_membership_id, whop_plan_id, status, current_period_end, trial_ends_at) values
  (:'trialing', 'mem_trialing', 'plan_test', 'trialing', now() + interval '7 days', now() + interval '7 days'),
  (:'trial_over', 'mem_trial_over', 'plan_test', 'trialing', now() - interval '1 second', now() - interval '1 second'),
  (:'active', 'mem_active', 'plan_test', 'active', now() + interval '10 days', now() - interval '20 days'),
  (:'active_open', 'mem_active_open', 'plan_test', 'active', null, null),
  (:'canceled', 'mem_canceled', 'plan_test', 'canceled', now() + interval '10 days', null),
  (:'expired', 'mem_expired', 'plan_test', 'expired', now() - interval '1 day', null),
  (:'past_due', 'mem_past_due', 'plan_test', 'past_due', now() + interval '2 days', null),
  (:'period_over', 'mem_period_over', 'plan_test', 'active', now() - interval '1 second', null);

-- Truth table (evaluated without a signed-in user, e.g. by the service role) ------------------------
select is(public.has_access(:'no_entitlement'), false, 'no entitlement -> no access (a signup alone grants nothing)');
select is(public.has_access(:'trialing'), true, 'Whop trialing entitlement within its period -> access');
select is(public.has_access(:'trial_over'), false, 'Whop trialing entitlement whose period ended -> no access');
select is(public.has_access(:'active'), true, 'active entitlement within its period -> access');
select is(public.has_access(:'active_open'), true, 'active entitlement without period end -> access');
select is(public.has_access(:'canceled'), false, 'canceled entitlement -> no access');
select is(public.has_access(:'expired'), false, 'expired entitlement -> no access');
select is(public.has_access(:'past_due'), false, 'past_due entitlement -> no access');
select is(public.has_access(:'period_over'), false, 'active entitlement whose period ended -> no access');
select is(public.has_access(null), false, 'no user -> no access');
select is(public.has_access(gen_random_uuid()), false, 'unknown user -> no access');

-- Signed-in callers ------------------------------------------------------------------------------------
select tests.authenticate_as(:'active');
select is(public.has_access(), true, 'has_access() defaults to the signed-in user');
select is(public.has_access(:'trialing'), false, 'a signed-in user cannot probe another user''s access');
select is(
  public.my_access()::jsonb,
  jsonb_build_object(
    'has_access', true,
    'entitlement_status', 'active',
    'current_period_end', (select current_period_end from public.entitlements where user_id = :'active'),
    'trial_ends_at', null
  ),
  'my_access() for an active subscriber hides the old trial end'
);
select tests.clear_authentication();

select tests.authenticate_as(:'trialing');
select is(
  public.my_access()::jsonb,
  jsonb_build_object(
    'has_access', true,
    'entitlement_status', 'trialing',
    'current_period_end', (select current_period_end from public.entitlements where user_id = :'trialing'),
    'trial_ends_at', (select trial_ends_at from public.entitlements where user_id = :'trialing')
  ),
  'my_access() for a trialing user exposes trial_ends_at'
);
select tests.clear_authentication();

update public.entitlements set trial_ends_at = null where user_id = :'trialing';
select tests.authenticate_as(:'trialing');
select is(
  (public.my_access() ->> 'trial_ends_at'),
  (select to_json(current_period_end) #>> '{}' from public.entitlements where user_id = :'trialing'),
  'my_access() falls back to current_period_end as trial end while trialing'
);
select tests.clear_authentication();

select tests.authenticate_as(:'no_entitlement');
select is(
  public.my_access()::jsonb,
  jsonb_build_object('has_access', false, 'entitlement_status', null, 'current_period_end', null, 'trial_ends_at', null),
  'my_access() without entitlement reports no access and null fields'
);
select tests.clear_authentication();

select tests.authenticate_as(:'canceled');
select is((public.my_access() ->> 'has_access')::boolean, false, 'my_access() reports no access for a canceled subscription');
select tests.clear_authentication();

-- anon ----------------------------------------------------------------------------------------------------
select tests.authenticate_as_anon();
select throws_ok($$ select public.has_access() $$, '42501', null, 'anon cannot execute has_access');
select throws_ok($$ select public.my_access() $$, '42501', null, 'anon cannot execute my_access');
select tests.clear_authentication();

select is(
  (select has_function_privilege('authenticated', 'public.handle_new_user()', 'execute')),
  false,
  'clients cannot execute the signup trigger function'
);

select * from finish();
rollback;
