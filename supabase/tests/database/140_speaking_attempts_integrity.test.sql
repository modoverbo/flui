-- speaking_attempts write-side integrity (security review finding F1, on
-- top of U21/decision #522): the guard trigger now also forces created_at
-- to the server clock on insert and rejects any audio_path that is not the
-- row's own canonical <user_id>/<id>.<ext> path, on both insert and update.
-- This closes a confused-deputy path where an authenticated user could
-- backdate their own row and later point its audio_path at ANOTHER user's
-- object, then have the service-role audio-retention sweep delete it as
-- "expired".
begin;
select plan(11);

select tests.create_user('integrity-owner@example.com') as owner_id \gset
select tests.create_user('integrity-victim@example.com') as victim_id \gset

insert into public.entitlements (user_id, whop_membership_id, whop_plan_id, status, current_period_end, trial_ends_at)
values
  (:'owner_id', 'mem_integrity_owner', 'plan_test', 'active', now() + interval '10 days', null),
  (:'victim_id', 'mem_integrity_victim', 'plan_test', 'active', now() + interval '10 days', null);

-- A victim row holding a real stored object, so its path is a plausible forgery target.
insert into public.speaking_attempts
  (id, user_id, session_id, context, kind, local_date, transcript, duration_ms, audio_status, audio_path)
values (
  '00000000-0000-4000-f000-000000000001', :'victim_id', gen_random_uuid(), 'diagnosis', 'first', current_date,
  'Preséntate en pocas frases, sin prisa.', 15000, 'stored',
  :'victim_id' || '/00000000-0000-4000-f000-000000000001.wav'
);

select tests.authenticate_as(:'owner_id');

-- created_at is always the server clock, ignoring a wildly backdated client value ----
select lives_ok(
  format(
    $$ insert into public.speaking_attempts
         (id, user_id, session_id, context, kind, local_date, transcript, duration_ms, audio_status, created_at)
       values ('00000000-0000-4000-f000-000000000002', %L, gen_random_uuid(), 'lab', 'repeat', current_date,
               'Repetí el mismo argumento con más precisión.', 12000, 'pending', '2000-01-01T00:00:00Z') $$,
    :'owner_id'
  ),
  'owner inserts an attempt with a backdated created_at'
);
select ok(
  (select created_at from public.speaking_attempts where id = '00000000-0000-4000-f000-000000000002') > now() - interval '1 minute',
  'created_at is forced to the server clock; the backdated client value is ignored'
);

-- the legitimate own-path flow still works: pending -> stored with the caller's own canonical path --
select lives_ok(
  format(
    $$ update public.speaking_attempts
         set audio_status = 'stored', audio_path = %L
       where id = '00000000-0000-4000-f000-000000000002' $$,
    :'owner_id' || '/00000000-0000-4000-f000-000000000002.wav'
  ),
  'the caller''s own canonical audio_path is accepted on pending -> stored'
);

-- the confused-deputy attack: pointing audio_path at ANOTHER user's real canonical path is rejected --
select lives_ok(
  format(
    $$ insert into public.speaking_attempts
         (id, user_id, session_id, context, kind, local_date, transcript, duration_ms, audio_status)
       values ('00000000-0000-4000-f000-000000000003', %L, gen_random_uuid(), 'lab', 'repeat', current_date,
               'Otro intento propio, listo para el ataque.', 12000, 'pending') $$,
    :'owner_id'
  ),
  'setup: owner inserts a second pending attempt'
);
select throws_ok(
  format(
    $$ update public.speaking_attempts
         set audio_status = 'stored', audio_path = %L
       where id = '00000000-0000-4000-f000-000000000003' $$,
    :'victim_id' || '/00000000-0000-4000-f000-000000000001.wav'
  ),
  '23514', null,
  'pointing audio_path at another user''s real canonical path is rejected (confused-deputy attack)'
);

-- shape violation: own user_id/own id but a disallowed extension --------------------
select lives_ok(
  format(
    $$ insert into public.speaking_attempts
         (id, user_id, session_id, context, kind, local_date, transcript, duration_ms, audio_status)
       values ('00000000-0000-4000-f000-000000000004', %L, gen_random_uuid(), 'lab', 'repeat', current_date,
               'Tercer intento propio.', 12000, 'pending') $$,
    :'owner_id'
  ),
  'setup: owner inserts a third pending attempt'
);
select throws_ok(
  format(
    $$ update public.speaking_attempts
         set audio_status = 'stored', audio_path = %L
       where id = '00000000-0000-4000-f000-000000000004' $$,
    :'owner_id' || '/00000000-0000-4000-f000-000000000004.mp3'
  ),
  '23514', null,
  'a disallowed extension on an otherwise-own path is rejected'
);

-- shape violation: own id as the filename stem, but a foreign folder ----------------
select lives_ok(
  format(
    $$ insert into public.speaking_attempts
         (id, user_id, session_id, context, kind, local_date, transcript, duration_ms, audio_status)
       values ('00000000-0000-4000-f000-000000000005', %L, gen_random_uuid(), 'lab', 'repeat', current_date,
               'Cuarto intento propio.', 12000, 'pending') $$,
    :'owner_id'
  ),
  'setup: owner inserts a fourth pending attempt'
);
select throws_ok(
  format(
    $$ update public.speaking_attempts
         set audio_status = 'stored', audio_path = %L
       where id = '00000000-0000-4000-f000-000000000005' $$,
    :'victim_id' || '/00000000-0000-4000-f000-000000000005.wav'
  ),
  '23514', null,
  'the caller''s own id in a foreign folder is rejected (folder must equal the caller''s own user_id)'
);

-- existing transition rules are preserved: none -> stored is still rejected ---------
select lives_ok(
  format(
    $$ insert into public.speaking_attempts
         (id, user_id, session_id, context, kind, local_date, transcript, duration_ms)
       values ('00000000-0000-4000-f000-000000000006', %L, gen_random_uuid(), 'lab', 'repeat', current_date,
               'Quinto intento propio, sin audio.', 12000) $$,
    :'owner_id'
  ),
  'setup: owner inserts a fifth attempt with default (none) audio_status'
);
select throws_ok(
  $$ update public.speaking_attempts set audio_status = 'stored' where id = '00000000-0000-4000-f000-000000000006' $$,
  '23514', null,
  'none -> stored is still rejected (existing transition rules unchanged)'
);

select tests.clear_authentication();

select * from finish();
rollback;
