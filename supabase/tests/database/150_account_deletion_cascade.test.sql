-- U22c: full account-deletion cascade verification (decision #434).
--
-- `admin.auth.admin.deleteUser(uid)` (the last step of the account-delete
-- Edge Function, U22b -- see apply-progress `sdd/flui-eloquence-gym-refactor/
-- apply-progress/u22b`) deletes the `auth.users` row directly. Every
-- user-owned row anywhere in `public` must disappear through a cascading
-- foreign key from that delete -- there is no other cleanup step for
-- database rows once `deleteUser` runs.
--
-- This file has two jobs:
--   1. Prove the cascade actually empties every user-owned table for the
--      deleted user, and leaves another user's rows untouched.
--   2. Make itself fail if a FUTURE table is added with a user-owning
--      column but no cascading FK to auth.users -- the first assertion
--      enumerates the exact set of public tables with such an FK via
--      pg_constraint/information_schema, so a new user-owned table is either
--      given a cascading FK (and added to the expected list below) or this
--      test starts failing the moment it exists.
--
-- Filename note: the tasks doc (obs #433, U22c.1) names this file
-- `130_account_deletion_cascade.test.sql`; `130` was already taken by
-- `130_audio_retention.test.sql` by the time this unit was implemented, so
-- this run uses the next free number, `150`, per this run's explicit
-- instructions.
--
-- Storage is explicitly OUT of scope for the cascade itself: deleting the
-- auth user does NOT delete the user's speaking-audio storage objects --
-- `storage.objects` carries no foreign key to `auth.users` at all (see
-- assertion 3 below, which proves that absence rather than merely asserting
-- it in a comment). Ownership of a storage object is encoded only in its
-- path, `<uid>/<id>.<ext>`. Removing those objects is `account-delete`'s own
-- explicit responsibility (U22b's `listAllObjectPaths`/`removeAllObjects`),
-- executed BEFORE `deleteUser` is ever called, and is already covered by
-- `account-delete/handler_test.ts`'s own suite (19 cases) -- not re-tested
-- here, since a DB-level pgTAP test cannot exercise Storage-API object
-- removal against a bucket excluded from this project's CI service list.
--
-- `public.whop_webhook_events` is intentionally NOT in the cascade list: it
-- carries no `user_id` column and no FK to `auth.users` at all (checked by
-- assertion 1's exhaustive enumeration below -- it simply does not appear).
-- It is a service-role-only idempotency/audit log of verified Whop webhook
-- deliveries, keyed by `webhook_id`. Its `payload` column stores a
-- minimised Whop event (`_shared/whop_events.ts` `minimizeWhopPayload`: this
-- app's user id from `metadata.app_user_id` plus Whop's membership/plan ids,
-- status and timestamp; never the buyer's identity), but as opaque JSON, not a
-- first-class column -- there is no FK to add.
-- This is a deliberate retention decision (idempotency requires remembering
-- which webhook ids were already processed, indefinitely, independent of
-- whether the subscriber account still exists), not a gap: `whop-webhook`'s
-- own handler already treats a webhook for a deleted user as a safe 200
-- no-op (FK violation on `entitlements.user_id` -> `"unknown_user"` ->
-- `{status:"ignored"}`, per apply-progress #908's investigation), so a
-- lingering `app_user_id` inside an old payload can never resurrect a row
-- for the deleted account.
begin;
select plan(22);

-- Fixtures ------------------------------------------------------------------
select tests.create_user('deletion-owner@example.com') as owner_id \gset
select tests.create_user('deletion-other@example.com') as other_id \gset

insert into public.words (id, slug, lemma, part_of_speech, syllables, stressed_syllable, explanation,
                          example_sentence, register, pedantry_risk, sort_order, published)
values ('00000000-0000-4000-8000-0000000000cc', 'test-borrado', 'borrado', 'sustantivo',
        array['bo', 'rra', 'do'], 2, 'Explicación.', 'Ejemplo.', 'neutral', 1, 9200, true);

insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
values ('00000000-0000-4000-9000-0000000000cc', '00000000-0000-4000-8000-0000000000cc',
        'Una {{blank}}.', 'Pista.', 'Explicación.', 1);
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
values
  ('00000000-0000-4000-9000-0000000000cc', 'borrado', true, null, null, null, 1),
  ('00000000-0000-4000-9000-0000000000cc', 'borrada', false, 'paronym', 'Porque...', 'Fíjate...', 2),
  ('00000000-0000-4000-9000-0000000000cc', 'boceto', false, 'register', 'Porque...', 'Fíjate...', 3);

-- profiles is seeded by the on_auth_user_created trigger already (no manual insert).

insert into public.entitlements (user_id, whop_membership_id, whop_plan_id, status, current_period_end, trial_ends_at)
values
  (:'owner_id', 'mem_delete_owner', 'plan_test', 'active', now() + interval '10 days', null),
  (:'other_id', 'mem_delete_other', 'plan_test', 'active', now() + interval '10 days', null);

insert into public.daily_sessions (user_id, local_date, minutes)
values (:'owner_id', '2026-09-20', 10), (:'other_id', '2026-09-20', 15);

insert into public.word_progress (user_id, word_id, introduced_on)
values (:'owner_id', '00000000-0000-4000-8000-0000000000cc', '2026-09-20'),
       (:'other_id', '00000000-0000-4000-8000-0000000000cc', '2026-09-20');

insert into public.exercise_attempts (user_id, exercise_id, word_id, attempts, revealed, grade, local_date)
values (:'owner_id', '00000000-0000-4000-9000-0000000000cc', '00000000-0000-4000-8000-0000000000cc', 1, false, 'good', '2026-09-20'),
       (:'other_id', '00000000-0000-4000-9000-0000000000cc', '00000000-0000-4000-8000-0000000000cc', 1, false, 'good', '2026-09-20');

insert into public.streak_repairs (user_id, repaired_date)
values (:'owner_id', '2026-09-19'), (:'other_id', '2026-09-19');

insert into public.speaking_attempts (id, user_id, session_id, context, kind, local_date, transcript, duration_ms)
values
  (gen_random_uuid(), :'owner_id', gen_random_uuid(), 'lab', 'first', '2026-09-20', 'Un intento de prueba.', 5000),
  (gen_random_uuid(), :'other_id', gen_random_uuid(), 'lab', 'first', '2026-09-20', 'Otro intento de prueba.', 5000);

insert into public.skill_profiles (id, user_id, kind, top_area, second_area, top_behavior, second_behavior, strengths)
values
  (gen_random_uuid(), :'owner_id', 'baseline', 'thinking', 'language', 'main_point_late', 'vague_word', '["clear_main_point"]'::jsonb),
  (gen_random_uuid(), :'other_id', 'baseline', 'thinking', 'language', 'main_point_late', 'vague_word', '["clear_main_point"]'::jsonb);

insert into public.speech_analysis_usage (user_id, usage_date, analyses)
values (:'owner_id', current_date, 3), (:'other_id', current_date, 3);

-- Assertion 1: the exact set of public tables with a FK reaching auth.users --
-- adding a new user-owned table without a cascading FK here is the failure
-- mode this test exists to catch.
select results_eq(
  $$ select c.relname
     from pg_constraint con
     join pg_class c on c.oid = con.conrelid
     join pg_namespace n on n.oid = c.relnamespace
     where con.contype = 'f'
       and con.confrelid = 'auth.users'::regclass
       and n.nspname = 'public'
     order by 1 $$,
  $$ select table_name from (values
       ('daily_sessions'::name), ('entitlements'::name), ('exercise_attempts'::name), ('profiles'::name),
       ('skill_profiles'::name), ('speaking_attempts'::name), ('speech_analysis_usage'::name),
       ('streak_repairs'::name), ('word_progress'::name)
     ) as expected(table_name)
     order by 1 $$,
  'every public table with a FK reaching auth.users is exactly this list -- a new user-owned table must be added here (with a cascading FK) or this test fails'
);

-- Assertion 2: every one of those FKs is ON DELETE CASCADE, not restrict/set null/no action.
select is_empty(
  $$ select c.relname
     from pg_constraint con
     join pg_class c on c.oid = con.conrelid
     join pg_namespace n on n.oid = c.relnamespace
     where con.contype = 'f'
       and con.confrelid = 'auth.users'::regclass
       and n.nspname = 'public'
       and con.confdeltype <> 'c' $$,
  'every public FK to auth.users declares ON DELETE CASCADE (none is restrict/set null/no action)'
);

-- Assertion 3: storage.objects has NO FK to auth.users (documents, rather than
-- assumes, why the auth-user delete cannot and does not clean up storage).
select is_empty(
  $$ select 1
     from pg_constraint con
     join pg_class c on c.oid = con.conrelid
     join pg_namespace n on n.oid = c.relnamespace
     where con.contype = 'f'
       and con.confrelid = 'auth.users'::regclass
       and n.nspname = 'storage'
       and c.relname = 'objects' $$,
  'storage.objects has no FK to auth.users -- speaking-audio objects are NOT removed by this cascade; account-delete (U22b) removes them explicitly before deleteUser runs'
);

-- Deleting the auth user is the entire trigger for this cascade (same effect
-- as admin.auth.admin.deleteUser). Wrapped in lives_ok rather than a bare
-- statement so a missing/blocking cascade (e.g. an accidental ON DELETE
-- RESTRICT) fails this one assertion cleanly instead of aborting the file.
select lives_ok(
  format($$ delete from auth.users where id = %L $$, :'owner_id'),
  'deleting the account succeeds -- nothing blocks the cascade'
);

-- Assertions 5-22: every user-owned table is empty for the deleted user and
-- untouched for the other user, checked table by table so a single missing
-- cascade points at exactly the table that broke.
select is((select count(*)::int from public.profiles where id = :'owner_id'), 0,
  'profiles: deleted user''s row is gone');
select is((select count(*)::int from public.profiles where id = :'other_id'), 1,
  'profiles: other user''s row is intact');

select is((select count(*)::int from public.entitlements where user_id = :'owner_id'), 0,
  'entitlements: deleted user''s row is gone');
select is((select count(*)::int from public.entitlements where user_id = :'other_id'), 1,
  'entitlements: other user''s row is intact');

select is((select count(*)::int from public.daily_sessions where user_id = :'owner_id'), 0,
  'daily_sessions: deleted user''s row is gone');
select is((select count(*)::int from public.daily_sessions where user_id = :'other_id'), 1,
  'daily_sessions: other user''s row is intact');

select is((select count(*)::int from public.word_progress where user_id = :'owner_id'), 0,
  'word_progress: deleted user''s row is gone');
select is((select count(*)::int from public.word_progress where user_id = :'other_id'), 1,
  'word_progress: other user''s row is intact');

select is((select count(*)::int from public.exercise_attempts where user_id = :'owner_id'), 0,
  'exercise_attempts: deleted user''s row is gone');
select is((select count(*)::int from public.exercise_attempts where user_id = :'other_id'), 1,
  'exercise_attempts: other user''s row is intact');

select is((select count(*)::int from public.streak_repairs where user_id = :'owner_id'), 0,
  'streak_repairs: deleted user''s row is gone');
select is((select count(*)::int from public.streak_repairs where user_id = :'other_id'), 1,
  'streak_repairs: other user''s row is intact');

select is((select count(*)::int from public.speaking_attempts where user_id = :'owner_id'), 0,
  'speaking_attempts: deleted user''s row is gone');
select is((select count(*)::int from public.speaking_attempts where user_id = :'other_id'), 1,
  'speaking_attempts: other user''s row is intact');

select is((select count(*)::int from public.skill_profiles where user_id = :'owner_id'), 0,
  'skill_profiles: deleted user''s row is gone');
select is((select count(*)::int from public.skill_profiles where user_id = :'other_id'), 1,
  'skill_profiles: other user''s row is intact');

select is((select count(*)::int from public.speech_analysis_usage where user_id = :'owner_id'), 0,
  'speech_analysis_usage: deleted user''s row is gone');
select is((select count(*)::int from public.speech_analysis_usage where user_id = :'other_id'), 1,
  'speech_analysis_usage: other user''s row is intact');

select * from finish();
rollback;
