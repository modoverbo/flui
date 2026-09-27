-- speaking_attempts: append-only history of every analyzed speaking attempt.
-- Own rows only; insert additionally requires public.has_access() (#422: no
-- spend on non-paying users) and a fresh (none/pending) status with no
-- stored path yet; the guard trigger only allows pending->stored|failed,
-- failed->pending|stored, stored->deleted (forcing the path to null); none
-- and deleted are terminal. One milestone per (user, ISO week).
begin;
select plan(23);

select has_table('public', 'speaking_attempts', 'speaking_attempts table exists');
select is_empty(
  $$ select c.relname from pg_class c
     where c.oid = 'public.speaking_attempts'::regclass and not c.relrowsecurity $$,
  'RLS is enabled on speaking_attempts'
);

select tests.create_user('speaking-owner@example.com') as owner_id \gset
select tests.create_user('speaking-other@example.com') as other_id \gset
select tests.create_user('speaking-no-access@example.com') as no_access_id \gset
select tests.create_user('speaking-expired@example.com') as expired_id \gset

insert into public.entitlements (user_id, whop_membership_id, whop_plan_id, status, current_period_end, trial_ends_at)
values
  (:'owner_id', 'mem_speaking_owner', 'plan_test', 'active', now() + interval '10 days', null),
  (:'expired_id', 'mem_speaking_expired', 'plan_test', 'expired', now() - interval '1 day', null);

-- anon: no access at all -------------------------------------------------------------
select tests.authenticate_as_anon();
select throws_ok($$ select * from public.speaking_attempts $$, '42501', null, 'anon cannot read speaking_attempts');
select throws_ok(
  $$ insert into public.speaking_attempts (id, user_id, session_id, context, kind, local_date, transcript, duration_ms)
     values (gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), 'daily', 'first', current_date, 'Hola.', 1000) $$,
  '42501', null, 'anon cannot insert speaking_attempts');
select tests.clear_authentication();

-- access gate (#422): a signed-in user without access, or with an expired
-- entitlement, cannot insert an attempt at all, even an otherwise-valid one --
select tests.authenticate_as(:'no_access_id');
select throws_ok(
  format($$ insert into public.speaking_attempts (id, user_id, session_id, context, kind, local_date, transcript, duration_ms)
            values (gen_random_uuid(), %L, gen_random_uuid(), 'diagnosis', 'first', current_date,
                    'Preséntate en pocas frases, sin prisa.', 15000) $$, :'no_access_id'),
  '42501', null, 'a signed-in user without an entitlement cannot insert speaking_attempts'
);
select tests.clear_authentication();

select tests.authenticate_as(:'expired_id');
select throws_ok(
  format($$ insert into public.speaking_attempts (id, user_id, session_id, context, kind, local_date, transcript, duration_ms)
            values (gen_random_uuid(), %L, gen_random_uuid(), 'diagnosis', 'first', current_date,
                    'Preséntate en pocas frases, sin prisa.', 15000) $$, :'expired_id'),
  '42501', null, 'a signed-in user with an expired entitlement cannot insert speaking_attempts'
);
select tests.clear_authentication();

-- owner: RLS insert check rejects a non-fresh row ------------------------------------
select tests.authenticate_as(:'owner_id');
-- 23514, not 42501: 20260913121100_speaking_attempts_integrity.sql's guard
-- trigger (security review finding F1) now validates audio_path shape on
-- INSERT too, and BEFORE ROW triggers always run before RLS's WITH CHECK is
-- evaluated -- 'owner_id/x.wav' is rejected as non-canonical (it can never
-- equal '<owner_id>/<freshly generated id>.wav') before RLS's own
-- "audio_path is null" requirement is ever reached. The insert is still
-- rejected either way; only the surfaced error code changed.
select throws_ok(
  format($$ insert into public.speaking_attempts (id, user_id, session_id, context, kind, local_date, transcript, duration_ms, audio_path)
            values (gen_random_uuid(), %L, gen_random_uuid(), 'daily', 'first', current_date,
                    'Hoy hablé sobre mi rutina matutina con calma.', 15000, %L || '/x.wav') $$, :'owner_id', :'owner_id'),
  '23514', null, 'insert is rejected when audio_path is already set');
select throws_ok(
  format($$ insert into public.speaking_attempts (id, user_id, session_id, context, kind, local_date, transcript, duration_ms, audio_status)
            values (gen_random_uuid(), %L, gen_random_uuid(), 'daily', 'first', current_date,
                    'Hoy hablé sobre mi rutina matutina con calma.', 15000, 'stored') $$, :'owner_id'),
  '42501', null, 'insert is rejected when audio_status is not none/pending');

-- owner: two legitimate inserts -------------------------------------------------------
select lives_ok(
  format($$ insert into public.speaking_attempts
              (id, user_id, session_id, context, kind, local_date, transcript, duration_ms, audio_status, milestone_week)
            values ('00000000-0000-4000-b000-000000000001', %L, gen_random_uuid(), 'daily', 'first', current_date,
                    'Hoy hablé sobre mi rutina matutina con calma.', 15000, 'pending', date_trunc('week', current_date)::date) $$,
         :'owner_id'),
  'owner inserts a fresh milestone-eligible attempt'
);
select lives_ok(
  format($$ insert into public.speaking_attempts
              (id, user_id, session_id, context, kind, local_date, transcript, duration_ms, audio_status)
            values ('00000000-0000-4000-b000-000000000002', %L, gen_random_uuid(), 'lab', 'repeat', current_date,
                    'Repetí el mismo argumento con más precisión.', 12000, 'none') $$, :'owner_id'),
  'owner inserts a second attempt with no stored audio'
);
select throws_ok(
  format($$ insert into public.speaking_attempts
              (id, user_id, session_id, context, kind, local_date, transcript, duration_ms, audio_status, milestone_week)
            values (gen_random_uuid(), %L, gen_random_uuid(), 'daily', 'first', current_date,
                    'Otro intento de la misma semana.', 9000, 'pending', date_trunc('week', current_date)::date) $$,
         :'owner_id'),
  '23505', null, 'a second milestone the same ISO week for the same user is rejected'
);

-- guard trigger: only the documented audio_status transitions are allowed -----------
select lives_ok(
  $$ update public.speaking_attempts
       set audio_status = 'stored', audio_path = (select user_id from public.speaking_attempts where id = '00000000-0000-4000-b000-000000000001') || '/00000000-0000-4000-b000-000000000001.wav'
     where id = '00000000-0000-4000-b000-000000000001' $$,
  'pending -> stored is allowed with an audio_path'
);
select throws_ok(
  $$ update public.speaking_attempts set audio_status = 'stored' where id = '00000000-0000-4000-b000-000000000002' $$,
  '23514', null, 'none -> stored is rejected (none is terminal)'
);
select lives_ok(
  $$ update public.speaking_attempts set audio_status = 'deleted' where id = '00000000-0000-4000-b000-000000000001' $$,
  'stored -> deleted is allowed'
);
select is(
  (select audio_path from public.speaking_attempts where id = '00000000-0000-4000-b000-000000000001'),
  null,
  'stored -> deleted forces audio_path back to null'
);
select throws_ok(
  $$ update public.speaking_attempts set audio_status = 'pending' where id = '00000000-0000-4000-b000-000000000001' $$,
  '23514', null, 'deleted -> pending is rejected (deleted is terminal)'
);

-- column privileges: only audio_status/audio_path/audio_mime are client-writable ----
select throws_ok(
  $$ update public.speaking_attempts set transcript = 'alterado' where id = '00000000-0000-4000-b000-000000000002' $$,
  '42501', null, 'clients cannot update transcript'
);
select throws_ok(
  $$ delete from public.speaking_attempts where id = '00000000-0000-4000-b000-000000000002' $$,
  '42501', null, 'clients cannot delete speaking_attempts (append-only)'
);
select tests.clear_authentication();

-- another user sees none of the owner's rows -----------------------------------------
select tests.authenticate_as(:'other_id');
select is(
  (select count(*)::int from public.speaking_attempts where user_id = :'owner_id'::uuid),
  0,
  'another signed-in user cannot see the owner''s attempts'
);
select tests.clear_authentication();

-- Structural checks (as postgres, bypasses RLS) --------------------------------------
select throws_ok(
  $$ insert into public.speaking_attempts (id, user_id, session_id, context, kind, local_date, transcript, duration_ms, milestone_week)
     values (gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), 'word', 'first', current_date,
             'Contexto inválido para hito.', 5000, date_trunc('week', current_date)::date) $$,
  '23514', null, 'milestone_week requires context in (daily, lab)'
);
select throws_ok(
  $$ insert into public.speaking_attempts (id, user_id, session_id, context, kind, local_date, transcript, duration_ms, milestone_week)
     values (gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), 'daily', 'repeat', current_date,
             'Kind inválido para hito.', 5000, date_trunc('week', current_date)::date) $$,
  '23514', null, 'milestone_week requires kind = first'
);
select throws_ok(
  $$ insert into public.speaking_attempts (id, user_id, session_id, context, kind, local_date, transcript, duration_ms, milestone_week)
     values (gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), 'daily', 'first', current_date,
             'Semana no empieza en lunes.', 5000, date_trunc('week', current_date)::date + 1) $$,
  '23514', null, 'milestone_week must be a Monday'
);
select throws_ok(
  $$ insert into public.speaking_attempts (id, user_id, session_id, context, kind, local_date, transcript, duration_ms, audio_status)
     values (gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), 'daily', 'first', current_date,
             'Estado incoherente con la ruta.', 5000, 'stored') $$,
  '23514', null, 'audio_status = stored requires a non-null audio_path'
);

select * from finish();
rollback;
