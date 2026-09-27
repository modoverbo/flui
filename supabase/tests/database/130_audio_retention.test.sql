-- Audio retention selection (decision #430, revised #522, hardened by
-- security review finding F1): 90-day milestone expiry and 24 h-grace
-- orphan reconciliation. Both selection functions are pure reads -- the
-- audio-retention Edge Function (Deno tests) is what actually updates rows
-- and removes objects based on what these return.
--
-- Fixtures insert speaking_attempts rows WITHOUT created_at, then UPDATE
-- created_at afterward: 20260913121100_speaking_attempts_integrity.sql's
-- guard trigger now forces created_at to the server clock on every INSERT
-- (ignoring any client-supplied value), so a backdated created_at can only
-- ever be set via a later UPDATE (never client-reachable outside this
-- fixture setup, which runs as postgres and is not subject to the
-- authenticated-role column grants).
begin;
select plan(28);

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
select tests.create_user('retention-m90-1m@example.com') as m90minus1_id \gset
select tests.create_user('retention-m90@example.com') as m90_id \gset
select tests.create_user('retention-m91@example.com') as m91_id \gset
select tests.create_user('retention-nonmilestone@example.com') as nonmilestone_id \gset
select tests.create_user('retention-referenced@example.com') as referenced_id \gset
select tests.create_user('retention-pending@example.com') as pending_id \gset
select tests.create_user('retention-deleted90@example.com') as deleted90_id \gset
select tests.create_user('retention-failed90@example.com') as failed90_id \gset
select tests.create_user('retention-dup@example.com') as dup_id \gset
select tests.create_user('retention-dup-other@example.com') as other_dup_id \gset

-- A diagnosis baseline, stored, deliberately ancient: never expires (D21/#430).
insert into public.speaking_attempts
  (id, user_id, session_id, context, kind, local_date, transcript, duration_ms, audio_status, audio_path, milestone_week)
values (
  '00000000-0000-4000-e000-000000000001', :'baseline_id', gen_random_uuid(), 'diagnosis', 'first', current_date,
  'Preséntate en pocas frases, sin prisa.', 15000, 'stored', :'baseline_id' || '/00000000-0000-4000-e000-000000000001.wav',
  null
);
update public.speaking_attempts set created_at = now() - interval '3650 days'
  where id = '00000000-0000-4000-e000-000000000001';

-- A weekly milestone stored 90 days minus 1 minute ago: not yet expired
-- (security review finding F5 -- a mutant that shrinks the 90-day threshold
-- by even a few hours must be caught; the old 89-day fixture left a whole
-- day of slack where such a mutant would still report "not expired").
insert into public.speaking_attempts
  (id, user_id, session_id, context, kind, local_date, transcript, duration_ms, audio_status, audio_path, milestone_week)
values (
  '00000000-0000-4000-e000-000000000002', :'m90minus1_id', gen_random_uuid(), 'daily', 'first', current_date,
  'Hoy hablé sobre mi rutina matutina con calma.', 15000, 'stored', :'m90minus1_id' || '/00000000-0000-4000-e000-000000000002.wav',
  date_trunc('week', current_date)::date
);
update public.speaking_attempts set created_at = now() - interval '90 days' + interval '1 minute'
  where id = '00000000-0000-4000-e000-000000000002';

-- A weekly milestone stored exactly 90 days ago: still not expired (the
-- selection uses a strict `<`, not `<=` -- F5's exact-boundary case).
insert into public.speaking_attempts
  (id, user_id, session_id, context, kind, local_date, transcript, duration_ms, audio_status, audio_path, milestone_week)
values (
  '00000000-0000-4000-e000-000000000006', :'m90_id', gen_random_uuid(), 'daily', 'first', current_date,
  'Hoy hablé sobre mi trabajo con calma.', 15000, 'stored', :'m90_id' || '/00000000-0000-4000-e000-000000000006.wav',
  date_trunc('week', current_date)::date
);
update public.speaking_attempts set created_at = now() - interval '90 days'
  where id = '00000000-0000-4000-e000-000000000006';

-- A weekly milestone stored 91 days ago: expired.
insert into public.speaking_attempts
  (id, user_id, session_id, context, kind, local_date, transcript, duration_ms, audio_status, audio_path, milestone_week)
values (
  '00000000-0000-4000-e000-000000000003', :'m91_id', gen_random_uuid(), 'lab', 'first', current_date,
  'Repetí el mismo argumento con más precisión.', 15000, 'stored', :'m91_id' || '/00000000-0000-4000-e000-000000000003.wav',
  date_trunc('week', current_date)::date
);
update public.speaking_attempts set created_at = now() - interval '91 days'
  where id = '00000000-0000-4000-e000-000000000003';

-- A stored, non-milestone (lab repeat) attempt, ancient: milestone_week is
-- null so it is never an expiry candidate, and its object stays referenced.
insert into public.speaking_attempts
  (id, user_id, session_id, context, kind, local_date, transcript, duration_ms, audio_status, audio_path, milestone_week)
values (
  '00000000-0000-4000-e000-000000000004', :'referenced_id', gen_random_uuid(), 'lab', 'repeat', current_date,
  'Repetí el mismo argumento con más precisión.', 12000, 'stored', :'referenced_id' || '/00000000-0000-4000-e000-000000000004.wav',
  null
);
update public.speaking_attempts set created_at = now() - interval '400 days'
  where id = '00000000-0000-4000-e000-000000000004';
insert into storage.objects (bucket_id, name, created_at)
values ('speaking-audio', :'referenced_id' || '/00000000-0000-4000-e000-000000000004.wav', now() - interval '400 days');

-- Two more objects in the SAME referenced folder that are NOT the exact
-- referenced audio_path (security review finding F2 -- a folder-match or a
-- prefix/LIKE-match mutant in select_orphaned_speaking_audio would wrongly
-- treat these as protected; only exact equality protects an object):
-- a different attempt id in the same folder, and a "backup"-shaped suffix
-- of the exact referenced path.
insert into storage.objects (bucket_id, name, created_at)
values
  ('speaking-audio', :'referenced_id' || '/00000000-0000-4000-e000-00000000dd05.wav', now() - interval '400 days'),
  ('speaking-audio', :'referenced_id' || '/00000000-0000-4000-e000-000000000004.wav.bak', now() - interval '400 days');

-- A pending row whose object is older than the 24 h grace period: nothing
-- protects this object (audio_status is not 'stored'), so it is an orphan.
insert into public.speaking_attempts
  (id, user_id, session_id, context, kind, local_date, transcript, duration_ms, audio_status, milestone_week)
values (
  '00000000-0000-4000-e000-000000000005', :'pending_id', gen_random_uuid(), 'daily', 'first', current_date,
  'Hoy hablé sobre mi trabajo con calma.', 15000, 'pending', null
);
update public.speaking_attempts set created_at = now() - interval '2 days'
  where id = '00000000-0000-4000-e000-000000000005';
insert into storage.objects (bucket_id, name, created_at)
values ('speaking-audio', :'pending_id' || '/00000000-0000-4000-e000-000000000005.wav', now() - interval '25 hours');

-- security review finding F3: audio_status = 'stored' and the 90-day rule
-- must both still be enforced even when a row is otherwise expiry-shaped
-- (milestone_week set, ancient, non-diagnosis) -- a mutant dropping the
-- `audio_status = 'stored'` filter would wrongly select these.
insert into public.speaking_attempts
  (id, user_id, session_id, context, kind, local_date, transcript, duration_ms, audio_status, milestone_week)
values (
  '00000000-0000-4000-e000-000000000007', :'deleted90_id', gen_random_uuid(), 'daily', 'first', current_date,
  'Este intento ya fue borrado.', 15000, 'deleted', date_trunc('week', current_date)::date
);
update public.speaking_attempts set created_at = now() - interval '120 days'
  where id = '00000000-0000-4000-e000-000000000007';
insert into public.speaking_attempts
  (id, user_id, session_id, context, kind, local_date, transcript, duration_ms, audio_status, milestone_week)
values (
  '00000000-0000-4000-e000-000000000008', :'failed90_id', gen_random_uuid(), 'daily', 'first', current_date,
  'A este intento le falló la subida de audio.', 15000, 'failed', date_trunc('week', current_date)::date
);
update public.speaking_attempts set created_at = now() - interval '120 days'
  where id = '00000000-0000-4000-e000-000000000008';

-- Unreferenced objects with no matching speaking_attempts row at all, on
-- each side of the 24 h grace boundary. "23 hours" is replaced by "24 hours
-- minus 1 minute" and an exact-24h boundary row is added (security review
-- finding F5, same rationale as the 90-day boundary above).
insert into storage.objects (bucket_id, name, created_at)
values
  ('speaking-audio', :'nonmilestone_id' || '/00000000-0000-4000-e000-00000000aa23.wav', now() - interval '24 hours' + interval '1 minute'),
  ('speaking-audio', :'nonmilestone_id' || '/00000000-0000-4000-e000-00000000aa24.wav', now() - interval '24 hours'),
  ('speaking-audio', :'nonmilestone_id' || '/00000000-0000-4000-e000-00000000aa25.wav', now() - interval '25 hours');

-- An object in a different bucket, very old: neither function ever looks outside speaking-audio.
insert into storage.buckets (id, name, public) values ('other-bucket', 'other-bucket', false) on conflict (id) do nothing;
insert into storage.objects (bucket_id, name, created_at)
values ('other-bucket', :'nonmilestone_id' || '/should-be-ignored.wav', now() - interval '999 days');

-- Legacy-shaped duplicate (security review finding F1, defense in depth):
-- simulates data written before 20260913121100_speaking_attempts_integrity.sql's
-- trigger existed, where two 'stored' rows could point at the exact same
-- audio_path. Only reachable by bypassing triggers, exactly as legacy data
-- would have been written under the pre-fix policy.
set local session_replication_role = replica;
insert into public.speaking_attempts
  (id, user_id, session_id, context, kind, local_date, transcript, duration_ms, audio_status, audio_path, milestone_week, created_at)
values (
  '00000000-0000-4000-e000-00000000000c', :'dup_id', gen_random_uuid(), 'daily', 'first', current_date,
  'Fixture de duplicado legado.', 15000, 'stored', :'other_dup_id' || '/00000000-0000-4000-e000-00000000000d.wav',
  date_trunc('week', current_date)::date, now() - interval '95 days'
);
insert into public.speaking_attempts
  (id, user_id, session_id, context, kind, local_date, transcript, duration_ms, audio_status, audio_path, milestone_week, created_at)
values (
  '00000000-0000-4000-e000-00000000000d', :'other_dup_id', gen_random_uuid(), 'daily', 'first', current_date,
  'Fixture que sigue referenciando el mismo objeto.', 15000, 'stored', :'other_dup_id' || '/00000000-0000-4000-e000-00000000000d.wav',
  date_trunc('week', current_date)::date, now()
);
set local session_replication_role = default;

-- select_expired_milestone_audio ----------------------------------------------------------------
select tests.authenticate_as_service_role();

select is_empty(
  format($$ select * from public.select_expired_milestone_audio(500) where attempt_id = %L $$, '00000000-0000-4000-e000-000000000001'),
  'the diagnosis baseline is never selected as expired milestone audio, however old'
);
select is_empty(
  format($$ select * from public.select_expired_milestone_audio(500) where attempt_id = %L $$, '00000000-0000-4000-e000-000000000002'),
  'a milestone stored 90 days minus 1 minute ago is not yet expired'
);
select is_empty(
  format($$ select * from public.select_expired_milestone_audio(500) where attempt_id = %L $$, '00000000-0000-4000-e000-000000000006'),
  'a milestone stored exactly 90 days ago is not yet expired (strict less-than, not less-or-equal)'
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
select is_empty(
  format($$ select * from public.select_expired_milestone_audio(500) where attempt_id = %L $$, '00000000-0000-4000-e000-000000000007'),
  'an ancient milestone whose audio_status is deleted (not stored) is never selected'
);
select is_empty(
  format($$ select * from public.select_expired_milestone_audio(500) where attempt_id = %L $$, '00000000-0000-4000-e000-000000000008'),
  'an ancient milestone whose audio_status is failed (not stored) is never selected'
);
select is_empty(
  format($$ select * from public.select_expired_milestone_audio(500) where attempt_id = %L $$, '00000000-0000-4000-e000-00000000000c'),
  'an expired milestone whose audio_path is also referenced by another stored row is never selected (defense in depth for legacy data)'
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
     where object_name = :'referenced_id' || '/00000000-0000-4000-e000-00000000dd05.wav'),
  1,
  'a different attempt id in the same referenced folder is still selected as an orphan (exact match, not a folder match)'
);
select is(
  (select count(*)::int from public.select_orphaned_speaking_audio(500)
     where object_name = :'referenced_id' || '/00000000-0000-4000-e000-000000000004.wav.bak'),
  1,
  'a ".bak"-suffixed sibling of the exact referenced path is still selected as an orphan (exact match, not a prefix/LIKE match)'
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
  'an unreferenced object 24h minus 1 minute old is not yet selected'
);
select is_empty(
  format(
    $$ select * from public.select_orphaned_speaking_audio(500) where object_name = %L $$,
    :'nonmilestone_id' || '/00000000-0000-4000-e000-00000000aa24.wav'
  ),
  'an unreferenced object exactly 24h old is not yet selected (strict less-than, not less-or-equal)'
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
