-- Seed invariants: plan placeholders and the quality bar of the starter word catalog.
-- These run against supabase/seed.sql as applied by `supabase db reset`.
begin;
select plan(16);

-- Plans ------------------------------------------------------------------------------------------------
select set_eq(
  $$ select id from public.subscription_plans where active $$,
  array['monthly', 'quarterly'],
  'seed provides the monthly and quarterly plans'
);
select results_eq(
  $$ select billing_period_days from public.subscription_plans where id in ('monthly', 'quarterly') order by sort_order $$,
  array[30, 90],
  'plans bill every 30 and 90 days'
);

-- Words --------------------------------------------------------------------------------------------------
select is((select count(*)::int from public.words where published), 8, 'seed publishes 8 words');
select is_empty(
  $$ select slug from public.words where published and pedantry_risk > 2 $$,
  'no seeded word has a pedantry risk above 2'
);
select is_empty(
  $$ select w.slug from public.words w
     where w.published and not exists (select 1 from public.word_confusions c where c.word_id = w.id) $$,
  'every seeded word has at least one confusion'
);
select is_empty(
  $$ select w.slug from public.words w
     where w.published and (jsonb_array_length(w.replaces) = 0 or cardinality(w.collocations) = 0) $$,
  'every seeded word lists what it replaces and its collocations'
);
select is_empty(
  $$ select a.slug || ' ~ ' || b.slug
     from public.words a
     join public.word_confusions c on c.word_id = a.id
     join public.words b on b.published and b.id <> a.id
       and (c.confused_word_id = b.id or lower(c.confused_with) = lower(b.lemma))
     where a.published $$,
  'no two seeded words are confusable with each other'
);

-- Exercises ------------------------------------------------------------------------------------------------
select is_empty(
  $$ select w.slug from public.words w
     where w.published and (select count(*) from public.exercises e where e.word_id = w.id) <> 3 $$,
  'every seeded word has exactly 3 cloze exercises'
);
select is_empty(
  $$ select e.id from public.exercises e
     where (select count(*) from public.exercise_options o where o.exercise_id = e.id and o.is_correct) <> 1 $$,
  'every exercise has exactly one correct option'
);
select is_empty(
  $$ select e.id from public.exercises e
     where (select count(*) from public.exercise_options o where o.exercise_id = e.id) <> 3 $$,
  'every exercise has exactly three options'
);
select is_empty(
  $$ select o.id from public.exercise_options o
     where not o.is_correct and (o.distractor_type is null or o.why_not is null or o.hint_specific is null) $$,
  'every distractor is typed and has why_not and hint_specific'
);
select is_empty(
  $$ select e.id from public.exercises e
     where cardinality(regexp_split_to_array(btrim(e.hint_general), '\s+')) >= 25 $$,
  'every general hint is shorter than 25 words'
);
select is_empty(
  $$ select e.id from public.exercises e
     join public.words w on w.id = e.word_id
     where exists (select 1 from public.exercises other
                   where other.word_id = e.word_id and other.id <> e.id and other.sentence = e.sentence) $$,
  'every exercise of a word uses a different sentence'
);

-- Readings ---------------------------------------------------------------------------------------------------
select is_empty(
  $$ select w.slug from public.words w
     where w.published
       and (select count(distinct r.scene) from public.readings r where r.word_id = w.id) < 3 $$,
  'every seeded word has 3 readings in different scenes'
);
select is_empty(
  $$ select r.id from public.readings r where btrim(r.before_phrase) = '' or btrim(r.after_phrase) = '' $$,
  'every reading has a before and after phrase'
);

-- Brand voice guardrail --------------------------------------------------------------------------------------------
select is_empty(
  $$ select t.txt from (
       select explanation as txt from public.words
       union all select usage_tip from public.words
       union all select hint_general from public.exercises
       union all select explanation from public.exercises
       union all select why_not from public.exercise_options
       union all select hint_specific from public.exercise_options
       union all select body from public.readings
     ) t
     where t.txt ~* '\m(lección|examen|alumno|profesor|tarea|calificación|gramática|memorización|evaluación|incorrecto)\M' $$,
  'seed content avoids the words the brand voice forbids'
);

select * from finish();
rollback;
