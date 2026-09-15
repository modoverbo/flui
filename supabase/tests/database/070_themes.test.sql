-- Themes: the taxonomy is readable by any signed-in user, the word-theme links
-- follow the visibility of their word, clients never write either, and the
-- per-kind option invariant keeps cloze at 3 options while contraste takes 2.
begin;
select plan(38);

-- Structure -----------------------------------------------------------------------
select has_table('public', 'themes', 'themes table exists');
select has_table('public', 'word_themes', 'word_themes table exists');
select has_column('public', 'words', 'semantic_set_id', 'words.semantic_set_id exists');
select has_column('public', 'daily_sessions', 'theme_id', 'daily_sessions.theme_id exists');
select has_column('public', 'exercises', 'secondary_word_id', 'exercises.secondary_word_id exists');

select is_empty(
  $$ select c.relname
     from pg_class c
     where c.oid in ('public.themes'::regclass, 'public.word_themes'::regclass)
       and not c.relrowsecurity $$,
  'RLS is enabled on themes and word_themes'
);

-- Fixtures (created as postgres) ----------------------------------------------------
insert into public.themes (id, slug, family, name, tagline, jtbd, content_type, status, sort_order, published)
values
  ('00000000-0000-4000-7000-000000000001', 'test-tema-live', 'trabajo', 'Tema live', 'Una línea.',
   'Quiero probar el tema.', 'word_driven', 'live', 9001, true),
  ('00000000-0000-4000-7000-000000000002', 'test-tema-soon', 'social', 'Tema soon', 'Otra línea.',
   'Quiero probar el tema que aún no está.', 'mixed', 'soon', 9002, true),
  ('00000000-0000-4000-7000-000000000003', 'test-tema-borrador', 'emocion', 'Tema borrador', 'Sin publicar.',
   'Quiero probar el tema sin publicar.', 'expression_driven', 'live', 9003, false);

insert into public.words (id, slug, lemma, part_of_speech, syllables, stressed_syllable, explanation,
                          example_sentence, register, pedantry_risk, sort_order, published, semantic_set_id)
values
  ('00000000-0000-4000-6000-000000000001', 'test-tema-publicada', 'publicada', 'adjetivo', array['pu', 'bli', 'ca', 'da'], 3,
   'Explicación de prueba.', 'Ejemplo de prueba.', 'neutral', 1, 9101, true, 'conjunto-de-prueba'),
  ('00000000-0000-4000-6000-000000000002', 'test-tema-borradora', 'borradora', 'sustantivo', array['bo', 'rra', 'do', 'ra'], 3,
   'Explicación de prueba.', 'Ejemplo de prueba.', 'neutral', 1, 9102, false, 'conjunto-de-prueba'),
  ('00000000-0000-4000-6000-000000000003', 'test-tema-contraria', 'contraria', 'adjetivo', array['con', 'tra', 'ria'], 2,
   'Explicación de prueba.', 'Ejemplo de prueba.', 'neutral', 1, 9103, true, null);

insert into public.word_themes (word_id, theme_id, relevance, sort_order)
values
  ('00000000-0000-4000-6000-000000000001', '00000000-0000-4000-7000-000000000001', 3, 9101),
  ('00000000-0000-4000-6000-000000000002', '00000000-0000-4000-7000-000000000001', 2, 9102);

select tests.create_user('themes-no-entitlement@example.com') as no_entitlement_id \gset
select tests.create_user('themes-trialing@example.com') as trialing_id \gset

insert into public.entitlements (user_id, whop_membership_id, whop_plan_id, status, current_period_end, trial_ends_at)
values (:'trialing_id', 'mem_test_themes', 'plan_test', 'trialing', now() + interval '7 days', now() + interval '7 days');

-- anon reads nothing -----------------------------------------------------------------
select tests.authenticate_as_anon();
select throws_ok($$ select * from public.themes $$, '42501', null, 'anon cannot read themes');
select throws_ok($$ select * from public.word_themes $$, '42501', null, 'anon cannot read word_themes');
select tests.clear_authentication();

-- The taxonomy is the shape of the offer: readable before the trial starts ------------
select tests.authenticate_as(:'no_entitlement_id');
select set_eq(
  $$ select slug from public.themes where slug like 'test-tema-%' $$,
  array['test-tema-live', 'test-tema-soon'],
  'a signed-in user without entitlement reads published themes, never unpublished ones'
);
select is(
  (select count(*)::int from public.word_themes wt where wt.theme_id = '00000000-0000-4000-7000-000000000001'),
  0,
  'word_themes stay invisible while the parent word is invisible'
);
select tests.clear_authentication();

-- word_themes follows the parent word --------------------------------------------------
select tests.authenticate_as(:'trialing_id');
select results_eq(
  $$ select w.slug from public.word_themes wt join public.words w on w.id = wt.word_id
     where wt.theme_id = '00000000-0000-4000-7000-000000000001' $$,
  array['test-tema-publicada'],
  'a user with access reads word_themes of published words only'
);
select is(
  (select relevance::int from public.word_themes
    where word_id = '00000000-0000-4000-6000-000000000001'
      and theme_id = '00000000-0000-4000-7000-000000000001'),
  3,
  'relevance comes back with the link'
);
select is(
  (select semantic_set_id from public.words where slug = 'test-tema-publicada'),
  'conjunto-de-prueba',
  'semantic_set_id is readable with the word'
);

-- Clients cannot write the taxonomy ------------------------------------------------------
select throws_ok(
  $$ insert into public.themes (slug, family, name, tagline, jtbd, content_type, sort_order)
     values ('x', 'trabajo', 'x', 'x', 'x', 'mixed', 1) $$,
  '42501', null, 'clients cannot insert themes');
select throws_ok($$ update public.themes set name = 'x' $$, '42501', null, 'clients cannot update themes');
select throws_ok($$ delete from public.themes $$, '42501', null, 'clients cannot delete themes');
select throws_ok(
  $$ insert into public.word_themes (word_id, theme_id)
     values ('00000000-0000-4000-6000-000000000001', '00000000-0000-4000-7000-000000000001') $$,
  '42501', null, 'clients cannot insert word_themes');
select throws_ok($$ delete from public.word_themes $$, '42501', null, 'clients cannot delete word_themes');
select throws_ok(
  $$ update public.words set semantic_set_id = 'otro' $$,
  '42501', null, 'clients cannot rewrite a semantic set');

-- A user owns the theme of their own day ---------------------------------------------------
select lives_ok(
  $$ insert into public.daily_sessions (local_date, minutes, theme_id)
     values (current_date, 10, '00000000-0000-4000-7000-000000000001') $$,
  'a user saves the theme chosen for their own day');
select is(
  (select count(*)::int from public.daily_sessions where theme_id = '00000000-0000-4000-7000-000000000001'),
  1,
  'the chosen theme comes back with the session'
);
select throws_ok(
  $$ insert into public.daily_sessions (local_date, minutes, theme_id)
     values (current_date + 1, 10, '00000000-0000-4000-7000-000000000099') $$,
  '23503', null, 'a session cannot point at a theme that does not exist');
select tests.clear_authentication();

-- Exercise kinds ------------------------------------------------------------------------------
-- From here on the deferred invariant is checked at the end of each statement, so every
-- exercise is inserted together with its options in ONE statement.
set constraints all immediate;

select lives_ok($$
  with exercise as (
    insert into public.exercises (id, word_id, kind, sentence, hint_general, explanation, position)
    values ('00000000-0000-4000-5000-000000000001', '00000000-0000-4000-6000-000000000001', 'registro',
            'Una frase con {{blank}} de registro.', 'Pista.', 'Explicación.', 11)
    returning id
  )
  insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
  select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
  from exercise cross join (values
    ('correcta', true, null, null, null, 1),
    ('formal', false, 'register', 'No encaja.', 'Fíjate.', 2),
    ('coloquial', false, 'register', 'No encaja.', 'Fíjate.', 3)
  ) as o (text, is_correct, distractor_type, why_not, hint_specific, position)
$$, 'a registro item keeps the 3 options and 1 correct answer of a cloze');

select lives_ok($$
  with exercise as (
    insert into public.exercises (id, word_id, kind, sentence, hint_general, explanation, position)
    values ('00000000-0000-4000-5000-000000000002', '00000000-0000-4000-6000-000000000001', 'reemplazo',
            'Antes decías {{blank}} de relleno.', 'Pista.', 'Explicación.', 12)
    returning id
  )
  insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
  select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
  from exercise cross join (values
    ('correcta', true, null, null, null, 1),
    ('vaga', false, 'near_synonym', 'No encaja.', 'Fíjate.', 2),
    ('otra', false, 'paronym', 'No encaja.', 'Fíjate.', 3)
  ) as o (text, is_correct, distractor_type, why_not, hint_specific, position)
$$, 'a reemplazo item keeps the 3 options and 1 correct answer of a cloze');

select lives_ok($$
  with exercise as (
    insert into public.exercises (id, word_id, secondary_word_id, kind, sentence, hint_general, explanation, position)
    values ('00000000-0000-4000-5000-000000000003', '00000000-0000-4000-6000-000000000001',
            '00000000-0000-4000-6000-000000000003', 'contraste',
            'A o B: la frase pide {{blank}}.', 'Pista.', 'Explicación.', 13)
    returning id
  )
  insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
  select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
  from exercise cross join (values
    ('publicada', true, null, null, null, 1),
    ('contraria', false, 'near_synonym', 'No encaja.', 'Fíjate.', 2)
  ) as o (text, is_correct, distractor_type, why_not, hint_specific, position)
$$, 'a contraste item is an A-vs-B pair: exactly 2 options, 1 correct');

select throws_ok($$
  insert into public.exercises (word_id, kind, sentence, hint_general, explanation, position)
  values ('00000000-0000-4000-6000-000000000001', 'dictado', 'Una frase con {{blank}}.', 'Pista.', 'Explicación.', 14)
$$, '23514', null, 'an unknown exercise kind is rejected');

select throws_ok($$
  insert into public.exercises (word_id, kind, sentence, hint_general, explanation, position)
  values ('00000000-0000-4000-6000-000000000001', 'contraste', 'A o B: {{blank}}.', 'Pista.', 'Explicación.', 15)
$$, '23514', null, 'a contraste item without its B side is rejected');

select throws_ok($$
  insert into public.exercises (word_id, secondary_word_id, kind, sentence, hint_general, explanation, position)
  values ('00000000-0000-4000-6000-000000000001', '00000000-0000-4000-6000-000000000001', 'contraste',
          'A o B: {{blank}}.', 'Pista.', 'Explicación.', 16)
$$, '23514', null, 'a word cannot be contrasted with itself');

select throws_ok($$
  with exercise as (
    insert into public.exercises (word_id, secondary_word_id, kind, sentence, hint_general, explanation, position)
    values ('00000000-0000-4000-6000-000000000001', '00000000-0000-4000-6000-000000000003', 'contraste',
            'A o B: tres son {{blank}}.', 'Pista.', 'Explicación.', 17)
    returning id
  )
  insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
  select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
  from exercise cross join (values
    ('publicada', true, null, null, null, 1),
    ('contraria', false, 'near_synonym', 'No encaja.', 'Fíjate.', 2),
    ('tercera', false, 'paronym', 'No encaja.', 'Fíjate.', 3)
  ) as o (text, is_correct, distractor_type, why_not, hint_specific, position)
$$, '23514', null, 'a contraste item rejects a third option');

select throws_ok($$
  with exercise as (
    insert into public.exercises (word_id, sentence, hint_general, explanation, position)
    values ('00000000-0000-4000-6000-000000000001', 'Un cloze con {{blank}} corto.', 'Pista.', 'Explicación.', 18)
    returning id
  )
  insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
  select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
  from exercise cross join (values
    ('publicada', true, null, null, null, 1),
    ('contraria', false, 'near_synonym', 'No encaja.', 'Fíjate.', 2)
  ) as o (text, is_correct, distractor_type, why_not, hint_specific, position)
$$, '23514', null, 'a cloze still requires exactly 3 options');

select is(
  (select kind from public.exercises where id = '00000000-0000-4000-5000-000000000003'),
  'contraste',
  'the contraste item survived with its kind'
);

select lives_ok(
  $$ delete from public.words where slug = 'test-tema-contraria' $$,
  'deleting the B side of a contrast removes the item instead of leaving half a contrast');

select is(
  (select count(*)::int from public.exercises where id = '00000000-0000-4000-5000-000000000003'),
  0,
  'the contraste item went with its B side'
);

-- Seed taxonomy ----------------------------------------------------------------------------------
select is((select count(*)::int from public.themes where slug not like 'test-tema-%'), 28,
  'the catalogue carries the whole 28-theme taxonomy');

select is((select count(*)::int from public.themes where published and slug not like 'test-tema-%'), 16,
  'the seed publishes the 16 launch themes and none of the 12 without content');

select is_empty(
  $$ select slug from public.themes
     where not published and status <> 'soon' and slug not like 'test-tema-%' $$,
  'a theme kept out of the catalogue is never anything but soon'
);

select is_empty(
  $$ select t.slug from public.themes t
     where t.status = 'live' and t.slug not like 'test-tema-%'
       and not exists (select 1 from public.word_themes wt where wt.theme_id = t.id) $$,
  'no theme is offered as live without a single word behind it'
);

select is_empty(
  $$ select w.slug from public.words w
     where w.published and w.slug not like 'test-tema-%'
       and (select count(*) from public.word_themes wt where wt.word_id = w.id) not between 1 and 3 $$,
  'every seeded word carries between 1 and 3 themes'
);

select set_eq(
  $$ select slug from public.words where semantic_set_id = 'fuerza-de-la-afirmacion' $$,
  array['matizar', 'contundente'],
  'the seed groups the two ends of one assertion axis into a semantic set'
);

select is_empty(
  $$ select slug from public.themes where slug not like 'test-tema-%' and btrim(tagline) = '' $$,
  'every seeded theme carries its tagline'
);

select * from finish();
rollback;
