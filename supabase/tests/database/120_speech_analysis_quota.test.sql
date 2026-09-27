-- Daily paid speech-analysis quota: an atomic per-user-per-UTC-day counter,
-- claimed only through claim_speech_analysis (service_role); never readable
-- or writable directly by clients.
begin;
select plan(20);

select has_table('public', 'speech_analysis_usage', 'speech_analysis_usage table exists');
select has_function(
  'public', 'claim_speech_analysis', array['uuid', 'integer'],
  'claim_speech_analysis(uuid, integer) exists'
);
select is(
  (select prosecdef from pg_proc where oid = 'public.claim_speech_analysis(uuid, integer)'::regprocedure),
  true, 'claim_speech_analysis is SECURITY DEFINER'
);
select is_empty(
  $$ select p.oid::regprocedure::text
     from pg_proc p
     where p.oid = 'public.claim_speech_analysis(uuid, integer)'::regprocedure
       and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%') $$,
  'claim_speech_analysis pins its search_path'
);
select is_empty(
  $$ select c.relname from pg_class c
     where c.oid = 'public.speech_analysis_usage'::regclass and not c.relrowsecurity $$,
  'RLS is enabled on speech_analysis_usage'
);

-- Fixtures -------------------------------------------------------------------------------------
select tests.create_user('quota-a@example.com') as user_a \gset
select tests.create_user('quota-b@example.com') as user_b \gset
select tests.create_user('quota-c@example.com') as user_c \gset
select tests.create_user('quota-d@example.com') as user_d \gset

-- Under the limit is allowed, atomically, per user ---------------------------------------------
select tests.authenticate_as_service_role();
select is(public.claim_speech_analysis(:'user_a', 3), true, 'call 1 of 3 is allowed');
select is(public.claim_speech_analysis(:'user_a', 3), true, 'call 2 of 3 is allowed');
select is(public.claim_speech_analysis(:'user_a', 3), true, 'call 3 of 3 is allowed');
select is(public.claim_speech_analysis(:'user_a', 3), false, 'the 4th call the same UTC day is denied');
select is(public.claim_speech_analysis(:'user_a', 3), false, 'denial is stable, not a one-shot fluke');
select is(
  (select analyses from public.speech_analysis_usage
     where user_id = :'user_a' and usage_date = (now() at time zone 'utc')::date),
  3, 'the denied calls never incremented the counter past the limit'
);

-- Other users are independent -------------------------------------------------------------------
select is(public.claim_speech_analysis(:'user_b', 3), true, 'a different user has their own independent counter');
select is(
  (select analyses from public.speech_analysis_usage
     where user_id = :'user_b' and usage_date = (now() at time zone 'utc')::date),
  1, 'user_b''s counter is unaffected by user_a reaching their limit'
);

-- Resets on UTC date change ---------------------------------------------------------------------
insert into public.speech_analysis_usage (user_id, usage_date, analyses)
values (:'user_c', ((now() at time zone 'utc')::date - 1), 60);
select is(
  public.claim_speech_analysis(:'user_c', 3), true,
  'yesterday''s exhausted quota (60/60) does not carry over: today is a fresh row'
);
select is(
  (select analyses from public.speech_analysis_usage
     where user_id = :'user_c' and usage_date = ((now() at time zone 'utc')::date - 1)),
  60, 'yesterday''s row is left untouched by today''s claim'
);

-- Default daily limit (60) applies when p_daily_limit is omitted --------------------------------
select is(public.claim_speech_analysis(:'user_d'), true, 'p_daily_limit defaults to 60 when omitted');
select tests.clear_authentication();

-- Not directly callable or writable by authenticated clients ------------------------------------
select tests.authenticate_as(:'user_a');
select throws_ok(
  $$ select public.claim_speech_analysis(gen_random_uuid(), 60) $$,
  '42501', null, 'authenticated cannot execute claim_speech_analysis'
);
select throws_ok(
  format(
    $$ insert into public.speech_analysis_usage (user_id, usage_date, analyses) values (%L, current_date, 999) $$,
    :'user_a'
  ),
  '42501', null, 'authenticated cannot write speech_analysis_usage directly'
);
select throws_ok(
  $$ select * from public.speech_analysis_usage $$,
  '42501', null, 'authenticated cannot read speech_analysis_usage directly'
);
select tests.clear_authentication();

select tests.authenticate_as_anon();
select throws_ok(
  $$ select public.claim_speech_analysis(gen_random_uuid(), 60) $$,
  '42501', null, 'anon cannot execute claim_speech_analysis'
);
select tests.clear_authentication();

select * from finish();
rollback;
