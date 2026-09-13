-- User learning data: every table is "own rows only" for signed-in users and
-- invisible to anon. exercise_attempts is append-only.
begin;
select plan(38);

select has_table('public', 'daily_sessions', 'daily_sessions table exists');
select has_table('public', 'word_progress', 'word_progress table exists');
select has_table('public', 'exercise_attempts', 'exercise_attempts table exists');
select has_table('public', 'streak_repairs', 'streak_repairs table exists');

select is_empty(
  $$ select c.relname from pg_class c
     where c.oid in ('public.daily_sessions'::regclass, 'public.word_progress'::regclass,
                     'public.exercise_attempts'::regclass, 'public.streak_repairs'::regclass)
       and not c.relrowsecurity $$,
  'RLS is enabled on every user learning table'
);

-- Fixtures ------------------------------------------------------------------------------
select tests.create_user('ana@example.com') as ana_id \gset
select tests.create_user('beto@example.com') as beto_id \gset

insert into public.words (id, slug, lemma, part_of_speech, syllables, stressed_syllable, explanation,
                          example_sentence, register, pedantry_risk, sort_order, published)
values ('00000000-0000-4000-8000-0000000000aa', 'test-palabra', 'palabra', 'sustantivo', array['pa', 'la', 'bra'], 2,
        'Explicación.', 'Ejemplo.', 'neutral', 1, 9100, true);
insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
values ('00000000-0000-4000-9000-0000000000aa', '00000000-0000-4000-8000-0000000000aa', 'Una {{blank}}.', 'Pista.', 'Explicación.', 1);
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
values
  ('00000000-0000-4000-9000-0000000000aa', 'palabra', true, null, null, null, 1),
  ('00000000-0000-4000-9000-0000000000aa', 'paladar', false, 'paronym', 'Porque...', 'Fíjate...', 2),
  ('00000000-0000-4000-9000-0000000000aa', 'vocablo', false, 'register', 'Porque...', 'Fíjate...', 3);

-- Beto's rows, created as postgres.
insert into public.daily_sessions (user_id, local_date, minutes) values (:'beto_id', '2026-09-13', 10);
insert into public.word_progress (user_id, word_id, introduced_on) values (:'beto_id', '00000000-0000-4000-8000-0000000000aa', '2026-09-13');
insert into public.exercise_attempts (user_id, exercise_id, word_id, attempts, revealed, grade, local_date)
values (:'beto_id', '00000000-0000-4000-9000-0000000000aa', '00000000-0000-4000-8000-0000000000aa', 1, false, 'good', '2026-09-13');
insert into public.streak_repairs (user_id, repaired_date) values (:'beto_id', '2026-09-12');

-- Ana: insert own rows ---------------------------------------------------------------------
select tests.authenticate_as(:'ana_id');

select lives_ok(
  $$ insert into public.daily_sessions (local_date, minutes, planned_word_ids, review_word_ids)
     values ('2026-09-13', 10, array['00000000-0000-4000-8000-0000000000aa']::uuid[], '{}') $$,
  'a user can insert their own daily session (user_id defaults to auth.uid())'
);
select lives_ok(
  $$ insert into public.word_progress (word_id, introduced_on, next_due_on, ladder_step)
     values ('00000000-0000-4000-8000-0000000000aa', '2026-09-13', '2026-09-14', 0) $$,
  'a user can insert their own word progress'
);
select lives_ok(
  $$ insert into public.exercise_attempts (exercise_id, word_id, attempts, revealed, grade, local_date, duration_ms)
     values ('00000000-0000-4000-9000-0000000000aa', '00000000-0000-4000-8000-0000000000aa', 2, false, 'hard', '2026-09-13', 5400) $$,
  'a user can insert their own exercise attempt'
);
select lives_ok(
  $$ insert into public.streak_repairs (repaired_date) values ('2026-09-11') $$,
  'a user can insert their own streak repair'
);

-- Ana: cannot insert rows for Beto -----------------------------------------------------------
select throws_ok(
  format($$ insert into public.daily_sessions (user_id, local_date, minutes) values (%L, '2026-09-14', 10) $$, :'beto_id'),
  '42501', null, 'a user cannot insert a daily session for another user');
select throws_ok(
  format($$ insert into public.word_progress (user_id, word_id, introduced_on) values (%L, '00000000-0000-4000-8000-0000000000aa', '2026-09-14') $$, :'beto_id'),
  '42501', null, 'a user cannot insert word progress for another user');
select throws_ok(
  format($$ insert into public.exercise_attempts (user_id, exercise_id, word_id, attempts, revealed, grade, local_date)
            values (%L, '00000000-0000-4000-9000-0000000000aa', '00000000-0000-4000-8000-0000000000aa', 1, false, 'good', '2026-09-14') $$, :'beto_id'),
  '42501', null, 'a user cannot insert an exercise attempt for another user');
select throws_ok(
  format($$ insert into public.streak_repairs (user_id, repaired_date) values (%L, '2026-09-10') $$, :'beto_id'),
  '42501', null, 'a user cannot insert a streak repair for another user');

-- Ana: reads only her own rows -----------------------------------------------------------------
select results_eq($$ select user_id from public.daily_sessions $$, format($$ values (%L::uuid) $$, :'ana_id'),
  'a user only reads their own daily sessions');
select results_eq($$ select user_id from public.word_progress $$, format($$ values (%L::uuid) $$, :'ana_id'),
  'a user only reads their own word progress');
select results_eq($$ select user_id from public.exercise_attempts $$, format($$ values (%L::uuid) $$, :'ana_id'),
  'a user only reads their own exercise attempts');
select results_eq($$ select user_id from public.streak_repairs $$, format($$ values (%L::uuid) $$, :'ana_id'),
  'a user only reads their own streak repairs');

-- Ana: updates ------------------------------------------------------------------------------------
select lives_ok(
  $$ update public.daily_sessions set minutes = 20, completed_at = now() where local_date = '2026-09-13' $$,
  'a user can update their own daily session');
select lives_ok(
  $$ update public.word_progress set state = 'practica', ladder_step = 1, last_grade = 'good',
       first_try_success_days = array['2026-09-13']::date[], last_reviewed_at = now()
     where word_id = '00000000-0000-4000-8000-0000000000aa' $$,
  'a user can update their own word progress');

update public.daily_sessions set minutes = 60 where user_id = :'beto_id';
update public.word_progress set state = 'tuya' where user_id = :'beto_id';

select throws_ok(
  format($$ update public.daily_sessions set user_id = %L where local_date = '2026-09-13' $$, :'beto_id'),
  '42501', null, 'a user cannot move a daily session to another user');
select throws_ok(
  format($$ update public.word_progress set user_id = %L $$, :'beto_id'),
  '42501', null, 'a user cannot move word progress to another user');

select throws_ok($$ update public.exercise_attempts set grade = 'good' $$, '42501', null,
  'exercise attempts cannot be updated');
select throws_ok($$ delete from public.exercise_attempts $$, '42501', null,
  'exercise attempts cannot be deleted');
select throws_ok($$ delete from public.daily_sessions $$, '42501', null,
  'daily sessions cannot be deleted by clients');
select throws_ok($$ delete from public.word_progress $$, '42501', null,
  'word progress cannot be deleted by clients');

-- Check constraints ----------------------------------------------------------------------------------
select throws_ok(
  $$ insert into public.daily_sessions (local_date, minutes) values ('2026-09-20', 3) $$,
  '23514', null, 'daily session minutes must be between 5 and 60');
select throws_ok(
  $$ update public.word_progress set state = 'dominada' $$,
  '23514', null, 'word progress state must be nueva, practica or tuya');
select throws_ok(
  $$ insert into public.exercise_attempts (exercise_id, word_id, attempts, revealed, grade, local_date)
     values ('00000000-0000-4000-9000-0000000000aa', '00000000-0000-4000-8000-0000000000aa', 4, false, 'good', '2026-09-13') $$,
  '23514', null, 'exercise attempts must be between 1 and 3');
select throws_ok(
  $$ insert into public.exercise_attempts (exercise_id, word_id, attempts, revealed, grade, local_date)
     values ('00000000-0000-4000-9000-0000000000aa', '00000000-0000-4000-8000-0000000000aa', 3, true, 'good', '2026-09-13') $$,
  '23514', null, 'a revealed answer is always graded again');

select tests.clear_authentication();

select is((select minutes::int from public.daily_sessions where user_id = :'beto_id'), 10,
  'a user cannot update another user''s daily session');
select is((select state from public.word_progress where user_id = :'beto_id'), 'nueva',
  'a user cannot update another user''s word progress');
select is((select minutes::int from public.daily_sessions where user_id = :'ana_id'), 20,
  'the own daily session update was persisted');
select ok((select updated_at is not null from public.word_progress where user_id = :'ana_id'),
  'word_progress.updated_at is maintained');

-- anon: nothing ------------------------------------------------------------------------------------------
select tests.authenticate_as_anon();
select throws_ok($$ select * from public.daily_sessions $$, '42501', null, 'anon cannot read daily sessions');
select throws_ok($$ select * from public.word_progress $$, '42501', null, 'anon cannot read word progress');
select throws_ok($$ select * from public.exercise_attempts $$, '42501', null, 'anon cannot read exercise attempts');
select throws_ok($$ select * from public.streak_repairs $$, '42501', null, 'anon cannot read streak repairs');
select tests.clear_authentication();

-- Cascade on account deletion -------------------------------------------------------------------------------
delete from auth.users where id = :'beto_id';
select is(
  (select count(*)::int from public.daily_sessions where user_id = :'beto_id')
  + (select count(*)::int from public.word_progress where user_id = :'beto_id')
  + (select count(*)::int from public.exercise_attempts where user_id = :'beto_id')
  + (select count(*)::int from public.streak_repairs where user_id = :'beto_id'),
  0,
  'deleting an account removes all of its learning data'
);

select * from finish();
rollback;
