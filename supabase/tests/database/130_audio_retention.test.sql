-- Audio retention selection (decision #430, revised #522): 90-day milestone
-- expiry and 24 h-grace orphan reconciliation. Both selection functions are
-- pure reads -- the audio-retention Edge Function (Deno tests) is what
-- actually updates rows and removes objects based on what these return.
begin;
select plan(21);

select has_function(
  'public', 'select_expired_milestone_audio', array['integer'],
  'select_expired_milestone_audio(integer) exists'
);
select has_function(
  'public', 'select_orphaned_speaking_audio', array['integer'],
  'select_orphaned_speaking_audio(integer) exists'
);
select is(
  (select prosecdef from pg_proc where oid = 'public.select_expired_milestone_audio(integer)'::regprocedure),
  true, 'select_expired_milestone_audio is SECURITY DEFINER'
);
select is(
  (select prosecdef from pg_proc where oid = 'public.select_orphaned_speaking_audio(integer)'::regprocedure),
  true, 'select_orphaned_speaking_audio is SECURITY DEFINER'
);
select is_empty(
  $$ select p.oid::regprocedure::text
     from pg_proc p
     where p.oid = 'public.select_expired_milestone_audio(integer)'::regprocedure
       and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%') $$,
  'select_expired_milestone_audio pins its search_path'
);
select is_empty(
  $$ select p.oid::regprocedure::text
     from pg_proc p
     where p.oid = 'public.select_orphaned_speaking_audio(integer)'::regprocedure
       and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%') $$,
  'select_orphaned_speaking_audio pins its search_path'
);

-- Fixtures -------------------------------------------------------------------------------------
select tests.create_user('retention-baseline@example.com') as baseline_id \gset
select tests.create_user('retention-m89@example.com') as m89_id \gset
select tests.create_user('retention-m91@example.com') as m91_id \gset
select tests.create_user('retention-nonmilestone@example.com') as nonmilestone_id \gset
select tests.create_user('retention-referenced@example.com') as referenced_id \gset
select tests.create_user('retention-pending@example.com') as pending_id \gset

-- A diagnosis baseline, stored, deliberately ancient: never expires (D21/#430).
insert into public.speaking_attempts
  (id, user_id, session_id, context, kind, local_date, transcript, duration_ms, audio_status, audio_path, milestone_week, created_at)
values (
  '00000000-0000-4000-e000-000000000001', :'baseline_id', gen_random_uuid(), 'diagnosis', 'first', current_date,
  'Preséntate en pocas frases, sin prisa.', 15000, 'stored', :'baseline_id' || '/00000000-0000-4000-e000-000000000001.wav',
  null, now() - interval '3650 days'
);

-- A weekly milestone stored 89 days ago: not yet expired.
insert into public.speaking_attempts
  (id, user_id, session_id, context, kind, local_date, transcript, duration_ms, audio_status, audio_path, milestone_week, created_at)
values (
  '00000000-0000-4000-e000-000000000002', :'m89_id', gen_random_uuid(), 'daily', 'first', current_date,
  'Hoy hablé sobre mi rutina matutina con calma.', 15000, 'stored', :'m89_id' || '/00000000-0000-4000-e000-000000000002.wav',
  date_trunc('week', current_date)::date, now() - interval '89 days'
);

-- A weekly milestone stored 91 days ago: expired.
insert into public.speaking_attempts
  (id, user_id, session_id, context, kind, local_date, transcript, duration_ms, audio_status, audio_path, milestone_week, created_at)
values (
  '00000000-0000-4000-e000-000000000003', :'m91_id', gen_random_uuid(), 'lab', 'first', current_date,
  'Repetí el mismo argumento con más precisión.', 15000, 'stored', :'m91_id' || '/00000000-0000-4000-e000-000000000003.wav',
  date_trunc('week', current_date)::date, now() - interval '91 days'
);

-- A stored, non-milestone (lab repeat) attempt, ancient: milestone_week is
-- null so it is never an expiry candidate, and its object stays referenced.
insert into public.speaking_attempts
  (id, user_id, session_id, context, kind, local_date, transcript, duration_ms, audio_status, audio_path, milestone_week, created_at)
values (
  '00000000-0000-4000-e000-000000000004', :'referenced_id', gen_random_uuid(), 'lab', 'repeat', current_date,
  'Repetí el mismo argumento con más precisión.', 12000, 'stored', :'referenced_id' || '/00000000-0000-4000-e000-000000000004.wav',
  null, now() - interval '400 days'
);
insert into storage.objects (bucket_id, name, created_at)
values ('speaking-audio', :'referenced_id' || '/00000000-0000-4000-e000-000000000004.wav', now() - interval '400 days');

-- A pending row whose object is older than the 24 h grace period: nothing
-- protects this object (audio_status is not 'stored'), so it is an orphan.
insert into public.speaking_attempts
  (id, user_id, session_id, context, kind, local_date, transcript, duration_ms, audio_status, milestone_week, created_at)
values (
  '00000000-0000-4000-e000-000000000005', :'pending_id', gen_random_uuid(), 'daily', 'first', current_date,
  'Hoy hablé sobre mi trabajo con calma.', 15000, 'pending', null, now() - interval '2 days'
);
insert into storage.objects (bucket_id, name, created_at)
values ('speaking-audio', :'pending_id' || '/00000000-0000-4000-e000-000000000005.wav', now() - interval '25 hours');

-- Unreferenced objects with no matching speaking_attempts row at all, on each side of the 24 h grace boundary.
insert into storage.objects (bucket_id, name, created_at)
values
  ('speaking-audio', :'nonmilestone_id' || '/00000000-0000-4000-e000-00000000aa23.wav', now() - interval '23 hours'),
  ('speaking-audio', :'nonmilestone_id' || '/00000000-0000-4000-e000-00000000aa25.wav', now() - interval '25 hours');

-- An object in a different bucket, very old: neither function ever looks outside speaking-audio.
insert into storage.buckets (id, name, public) values ('other-bucket', 'other-bucket', false) on conflict (id) do nothing;
insert into storage.objects (bucket_id, name, created_at)
values ('other-bucket', :'nonmilestone_id' || '/should-be-ignored.wav', now() - interval '999 days');

-- select_expired_milestone_audio ----------------------------------------------------------------
select tests.authenticate_as_service_role();

select is_empty(
  format($$ select * from public.select_expired_milestone_audio(500) where attempt_id = %L $$, '00000000-0000-4000-e000-000000000001'),
  'the diagnosis baseline is never selected as expired milestone audio, however old'
);
select is_empty(
  format($$ select * from public.select_expired_milestone_audio(500) where attempt_id = %L $$, '00000000-0000-4000-e000-000000000002'),
  'a milestone stored 89 days ago is not yet expired'
);
select results_eq(
  format(
    $$ select attempt_id, user_id, audio_path from public.select_expired_milestone_audio(500) where attempt_id = %L $$,
    '00000000-0000-4000-e000-000000000003'
  ),
  format(
    $$ values (%L::uuid, %L::uuid, %L::text) $$,
    '00000000-0000-4000-e000-000000000003', :'m91_id', :'m91_id' || '/00000000-0000-4000-e000-000000000003.wav'
  ),
  'a milestone stored 91 days ago is selected as expired, with its user and audio path'
);
select is_empty(
  format($$ select * from public.select_expired_milestone_audio(500) where attempt_id = %L $$, '00000000-0000-4000-e000-000000000004'),
  'a non-milestone stored attempt (milestone_week null) is never selected as expired milestone audio'
);
select is(
  (select count(*)::int from public.select_expired_milestone_audio(0)),
  0,
  'p_batch_size bounds the expired-milestone result set (0 returns nothing even though a match exists)'
);

-- select_orphaned_speaking_audio ------------------------------------------------------------------
select is_empty(
  format(
    $$ select * from public.select_orphaned_speaking_audio(500) where object_name = %L $$,
    :'referenced_id' || '/00000000-0000-4000-e000-000000000004.wav'
  ),
  'a storage object referenced by an audio_status = stored row is never selected as an orphan'
);
select is(
  (select count(*)::int from public.select_orphaned_speaking_audio(500)
     where object_name = :'pending_id' || '/00000000-0000-4000-e000-000000000005.wav'),
  1,
  'a storage object whose row is pending (not stored) and older than 24h is selected as an orphan'
);
select is_empty(
  format(
    $$ select * from public.select_orphaned_speaking_audio(500) where object_name = %L $$,
    :'nonmilestone_id' || '/00000000-0000-4000-e000-00000000aa23.wav'
  ),
  'an unreferenced object younger than the 24h grace period is not yet selected'
);
select is(
  (select count(*)::int from public.select_orphaned_speaking_audio(500)
     where object_name = :'nonmilestone_id' || '/00000000-0000-4000-e000-00000000aa25.wav'),
  1,
  'an unreferenced object older than the 24h grace period is selected as an orphan'
);
select is_empty(
  format(
    $$ select * from public.select_orphaned_speaking_audio(500) where object_name = %L $$,
    :'nonmilestone_id' || '/should-be-ignored.wav'
  ),
  'objects in other buckets are never selected, even when very old'
);
select is(
  (select count(*)::int from public.select_orphaned_speaking_audio(0)),
  0,
  'p_batch_size bounds the orphan result set (0 returns nothing even though matches exist)'
);
select tests.clear_authentication();

-- Not directly executable by authenticated or anon clients -------------------------------------
select tests.authenticate_as(:'baseline_id');
select throws_ok(
  $$ select * from public.select_expired_milestone_audio(500) $$,
  '42501', null, 'authenticated cannot execute select_expired_milestone_audio'
);
select throws_ok(
  $$ select * from public.select_orphaned_speaking_audio(500) $$,
  '42501', null, 'authenticated cannot execute select_orphaned_speaking_audio'
);
select tests.clear_authentication();

select tests.authenticate_as_anon();
select throws_ok(
  $$ select * from public.select_expired_milestone_audio(500) $$,
  '42501', null, 'anon cannot execute select_expired_milestone_audio'
);
select throws_ok(
  $$ select * from public.select_orphaned_speaking_audio(500) $$,
  '42501', null, 'anon cannot execute select_orphaned_speaking_audio'
);
select tests.clear_authentication();

select * from finish();
rollback;
