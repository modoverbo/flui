-- Content tables: readable only by signed-in users with access (Whop trialing/active
-- entitlement), never by anon, never writable by clients; one-correct-option invariant.
begin;
select plan(37);

-- Structure -----------------------------------------------------------------------
select has_table('public', 'words', 'words table exists');
select has_table('public', 'word_confusions', 'word_confusions table exists');
select has_table('public', 'exercises', 'exercises table exists');
select has_table('public', 'exercise_options', 'exercise_options table exists');
select has_table('public', 'readings', 'readings table exists');

select is_empty(
  $$ select c.relname
     from pg_class c
     where c.oid in ('public.words'::regclass, 'public.word_confusions'::regclass,
                     'public.exercises'::regclass, 'public.exercise_options'::regclass,
                     'public.readings'::regclass)
       and not c.relrowsecurity $$,
  'RLS is enabled on every content table'
);

-- Fixtures (created as postgres) ----------------------------------------------------
-- Two test words: published and unpublished.
insert into public.words (id, slug, lemma, part_of_speech, syllables, stressed_syllable, explanation,
                          example_sentence, register, pedantry_risk, sort_order, published)
values
  ('00000000-0000-4000-8000-000000000001', 'test-publicada', 'publicada', 'adjetivo', array['pu', 'bli', 'ca', 'da'], 3,
   'Explicación de prueba.', 'Ejemplo de prueba.', 'neutral', 1, 9001, true),
  ('00000000-0000-4000-8000-000000000002', 'test-borrador', 'borrador', 'sustantivo', array['bo', 'rra', 'dor'], 3,
   'Explicación de prueba.', 'Ejemplo de prueba.', 'neutral', 1, 9002, false);

insert into public.word_confusions (word_id, confused_with, difference, memory_trick)
select id, 'otra-' || slug, 'Diferencia de prueba.', 'Truco de prueba.' from public.words where slug like 'test-%';

insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
select ('00000000-0000-4000-9000-00000000000' || right(id::text, 1))::uuid, id,
       'Una frase con {{blank}} de prueba.', 'Pista general de prueba.', 'Explicación final de prueba.', 1
from public.words where slug like 'test-%';

insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select e.id, v.text, v.is_correct, v.distractor_type, v.why_not, v.hint_specific, v.position
from public.exercises e
join public.words w on w.id = e.word_id and w.slug like 'test-%'
cross join (values
  ('correcta', true, null, null, null, 1),
  ('parónimo', false, 'paronym', 'No encaja porque...', 'Fíjate en...', 2),
  ('registro', false, 'register', 'No encaja porque...', 'Fíjate en...', 3)
) as v(text, is_correct, distractor_type, why_not, hint_specific, position);

insert into public.readings (word_id, scene, conversation_type, title, body, before_phrase, after_phrase, position)
select id, 'trabajo', 'practica', 'Título', 'Cuerpo de prueba.', 'antes', 'después', 1
from public.words where slug like 'test-%';

select tests.create_user('no-entitlement@example.com') as no_entitlement_id \gset
select tests.create_user('trialing@example.com') as trialing_id \gset
select tests.create_user('member@example.com') as member_id \gset
select tests.create_user('expired@example.com') as expired_id \gset

insert into public.entitlements (user_id, whop_membership_id, whop_plan_id, status, current_period_end, trial_ends_at)
values
  (:'trialing_id', 'mem_test_trialing', 'plan_test', 'trialing', now() + interval '7 days', now() + interval '7 days'),
  (:'member_id', 'mem_test_member', 'plan_test', 'active', now() + interval '20 days', null),
  (:'expired_id', 'mem_test_expired', 'plan_test', 'expired', now() - interval '1 day', null);

-- anon: no content at all -------------------------------------------------------------
select tests.authenticate_as_anon();
select throws_ok($$ select * from public.words $$, '42501', null, 'anon cannot read words');
select throws_ok($$ select * from public.word_confusions $$, '42501', null, 'anon cannot read word_confusions');
select throws_ok($$ select * from public.exercises $$, '42501', null, 'anon cannot read exercises');
select throws_ok($$ select * from public.exercise_options $$, '42501', null, 'anon cannot read exercise_options');
select throws_ok($$ select * from public.readings $$, '42501', null, 'anon cannot read readings');
select tests.clear_authentication();

-- signed-in user without an entitlement: no content (paywall) ----------------------------
select tests.authenticate_as(:'no_entitlement_id');
select is((select count(*)::int from public.words where slug like 'test-%'), 0,
  'a signed-in user without entitlement cannot read words');
select is((select count(*)::int from public.word_confusions where word_id = '00000000-0000-4000-8000-000000000001'), 0,
  'a signed-in user without entitlement cannot read word_confusions');
select is((select count(*)::int from public.exercises where word_id = '00000000-0000-4000-8000-000000000001'), 0,
  'a signed-in user without entitlement cannot read exercises');
select is((select count(*)::int from public.exercise_options where exercise_id = '00000000-0000-4000-9000-000000000001'), 0,
  'a signed-in user without entitlement cannot read exercise_options');
select is((select count(*)::int from public.readings where word_id = '00000000-0000-4000-8000-000000000001'), 0,
  'a signed-in user without entitlement cannot read readings');
select tests.clear_authentication();

-- signed-in user in a Whop trial: published content only ----------------------------------
select tests.authenticate_as(:'trialing_id');
select set_eq(
  $$ select slug from public.words where slug like 'test-%' $$,
  array['test-publicada'],
  'a trialing user reads published words, never unpublished ones'
);
select is((select count(*)::int from public.word_confusions c join public.words w on w.id = c.word_id where w.slug like 'test-%'), 1,
  'a trialing user reads confusions of published words only');
select is((select count(*)::int from public.exercises e join public.words w on w.id = e.word_id where w.slug like 'test-%'), 1,
  'a trialing user reads exercises of published words only');
select is((select count(*)::int from public.exercise_options o join public.exercises e on e.id = o.exercise_id
           join public.words w on w.id = e.word_id where w.slug like 'test-%'), 3,
  'a trialing user reads options of published words only');
select is((select count(*)::int from public.readings r join public.words w on w.id = r.word_id where w.slug like 'test-%'), 1,
  'a trialing user reads readings of published words only');
select tests.clear_authentication();

-- active subscriber reads; expired subscriber does not ----------------------------------------
select tests.authenticate_as(:'member_id');
select set_eq($$ select slug from public.words where slug like 'test-%' $$, array['test-publicada'],
  'an active subscriber reads published words');
select tests.clear_authentication();

select tests.authenticate_as(:'expired_id');
select is((select count(*)::int from public.words where slug like 'test-%'), 0,
  'an expired subscriber cannot read words');
select tests.clear_authentication();

-- access is revoked as soon as the entitlement is deactivated -----------------------------------
update public.entitlements set status = 'canceled' where user_id = :'trialing_id';
select tests.authenticate_as(:'trialing_id');
select is((select count(*)::int from public.exercise_options where exercise_id = '00000000-0000-4000-9000-000000000001'), 0,
  'a deactivated (canceled) trial loses access to content immediately');
select tests.clear_authentication();

select tests.authenticate_as(:'member_id');

-- Clients cannot write content ----------------------------------------------------------------
select throws_ok(
  $$ insert into public.words (slug, lemma, part_of_speech, syllables, stressed_syllable, explanation, example_sentence, register, pedantry_risk, sort_order)
     values ('x', 'x', 'verbo', array['x'], 1, 'x', 'x', 'neutral', 1, 1) $$,
  '42501', null, 'clients cannot insert words');
select throws_ok($$ update public.words set lemma = 'x' $$, '42501', null, 'clients cannot update words');
select throws_ok($$ delete from public.words $$, '42501', null, 'clients cannot delete words');
select throws_ok(
  $$ insert into public.word_confusions (word_id, confused_with, difference) values ('00000000-0000-4000-8000-000000000001', 'x', 'x') $$,
  '42501', null, 'clients cannot insert word_confusions');
select throws_ok(
  $$ insert into public.exercises (word_id, sentence, hint_general, explanation, position) values ('00000000-0000-4000-8000-000000000001', '{{blank}}', 'x', 'x', 9) $$,
  '42501', null, 'clients cannot insert exercises');
select throws_ok($$ update public.exercise_options set is_correct = true $$, '42501', null, 'clients cannot update exercise_options');
select throws_ok($$ delete from public.readings $$, '42501', null, 'clients cannot delete readings');
select tests.clear_authentication();

-- Content constraints and the one-correct-option invariant ------------------------------------
select throws_ok(
  $$ insert into public.exercises (word_id, sentence, hint_general, explanation, position)
     values ('00000000-0000-4000-8000-000000000001', 'Sin hueco.', 'Pista.', 'Explicación.', 7) $$,
  '23514', null, 'an exercise sentence must contain the {{blank}} token');

select throws_ok(
  $$ insert into public.exercise_options (exercise_id, text, is_correct, position)
     values ('00000000-0000-4000-9000-000000000001', 'sin explicación', false, 9) $$,
  '23514', null, 'a distractor requires distractor_type, why_not and hint_specific');

select throws_ok(
  $$ update public.exercise_options set is_correct = true, distractor_type = null, why_not = null, hint_specific = null
     where exercise_id = '00000000-0000-4000-9000-000000000001' and position = 2;
     set constraints all immediate $$,
  '23514', null, 'an exercise cannot have two correct options');

select throws_ok(
  $$ delete from public.exercise_options where exercise_id = '00000000-0000-4000-9000-000000000001' and is_correct;
     set constraints all immediate $$,
  '23514', null, 'an exercise cannot lose its correct option');

select throws_ok(
  $$ insert into public.exercises (word_id, sentence, hint_general, explanation, position)
     values ('00000000-0000-4000-8000-000000000001', 'Otra {{blank}} frase.', 'Pista.', 'Explicación.', 8);
     set constraints all immediate $$,
  '23514', null, 'an exercise cannot exist without its three options');

select lives_ok(
  $$ delete from public.words where slug = 'test-borrador';
     set constraints all immediate $$,
  'deleting a word cascades to its exercises and options without violating the invariant');

select * from finish();
rollback;
