-- Seed invariants: plan placeholders and the quality bar of the starter word catalog.
-- These run against supabase/seed.sql as applied by `supabase db reset`.
begin;
select plan(19);

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
-- A floor, never an exact count: the catalogue grows every week and a test that
-- pins today's number only ever reports that authoring happened.
select cmp_ok(
  (select count(*)::int from public.words where published), '>=', 100,
  'the seed publishes a catalogue of at least 100 words'
);
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
-- Confusable pairs inside the catalogue are the product, not a bug: flui ships a
-- `paronimos` theme on purpose. What protects the reader is the planner's 7-day
-- interference rule (docs/learning-method.md §7,
-- app/lib/features/vocabulary/domain/confusability.dart), which refuses to
-- introduce two confusable words within a week of each other. That rule is
-- purely declaration-driven: `areConfusable(a, b)` is true only when a
-- `word_confusions` row of either word points at the other, by
-- `confused_word_id` or by a case-insensitive `confused_with` lemma match. One
-- direction is enough, because the Dart rule reads both.
--
-- The stronger invariant — *every* pair a paronym heuristic would flag is
-- declared — is deliberately not asserted here. The only such heuristic in the
-- repo is the authoring-side flag in content/lib/src/corpus/candidate_pool.dart
-- (`_flagParonyms`: lemma lengths within 1, first or last letter shared,
-- Levenshtein <= 2). It is advisory by contract (content/data/LICENSES.md) and
-- an author confirms or drops each suggestion, so its closure is not a property
-- the catalogue holds: mirrored in SQL it flags 20 published pairs today, 19 of
-- them undeclared and most of them noise ('vasto ~ tacto', 'hilar ~ calar').
-- Asserting it would be asserting something false. What is left below is the
-- true half: the declarations the rule does read must be unambiguous and alive.
select is_empty(
  $$ select w.slug from public.words w
     join public.word_confusions c on c.word_id = w.id
     where c.confused_word_id = w.id or lower(btrim(c.confused_with)) = lower(w.lemma) $$,
  'no word is declared confusable with itself'
);
select is_empty(
  $$ select w.slug || ' -> ' || c.confused_with
     from public.word_confusions c
     join public.words w on w.id = c.word_id
     join public.words target on target.id = c.confused_word_id
     where lower(btrim(c.confused_with)) <> lower(target.lemma) $$,
  'a confusion that carries a word id names that same word'
);
select is_empty(
  $$ select lower(lemma) from public.words where published
     group by lower(lemma) having count(*) > 1 $$,
  'published lemmas are unique, so a confusion resolves to exactly one word'
);

-- Exercises ------------------------------------------------------------------------------------------------
-- A band, not a number: a word is authored with 8 items and keeps 6 or 7 when
-- `content:prune` drops the ones the blind gate found ambiguous.
select is_empty(
  $$ select w.slug from public.words w
     where w.published
       and (select count(*) from public.exercises e where e.word_id = w.id) not between 6 and 8 $$,
  'every seeded word has between 6 and 8 cloze exercises'
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
  $$ select e.id from public.exercises e
     where char_length(e.sentence) - char_length(replace(e.sentence, '{{blank}}', ''))
           <> char_length('{{blank}}') $$,
  'every exercise sentence carries exactly one {{blank}}'
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
