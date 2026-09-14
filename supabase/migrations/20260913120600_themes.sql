-- Themes ("¿sobre qué tema?"): the second half of the daily choice.
--
-- A theme decides which NEW word the session planner may introduce. It never
-- touches the due-review queue, the number of new slots, the "Hoy toca
-- afianzar" threshold or the review ladder. Reviews stay global and land on
-- their computed due dates (Bjork's desirable difficulties; Anki's own
-- documentation warns that filtered decks desynchronise a schedule when they
-- reorder due cards). See docs/learning-method.md §1 and §7.
--
-- Taxonomy copy (slug, family, name, tagline, jtbd, content_type) is authored
-- in content/themes.yml and loaded by supabase/seed_themes.sql.

-- themes -------------------------------------------------------------------------------------------

create table if not exists public.themes (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  family text not null check (family in ('trabajo', 'social', 'publico', 'precision', 'emocion')),
  name text not null check (btrim(name) <> ''),
  tagline text not null check (btrim(tagline) <> ''),
  jtbd text not null check (btrim(jtbd) <> ''),
  content_type text not null check (content_type in ('word_driven', 'expression_driven', 'mixed')),
  status text not null default 'soon' check (status in ('live', 'beta', 'soon')),
  sort_order integer not null,
  published boolean not null default false,
  created_at timestamptz not null default now()
);

comment on table public.themes is 'The theme taxonomy (content/themes.yml). A theme filters the new-word candidate pool only; the review queue stays global.';
comment on column public.themes.family is 'Grouping used by the "Explorar" sheet.';
comment on column public.themes.jtbd is 'The job the user hires this theme for, in their own words.';
comment on column public.themes.status is 'live = offered today; beta = offered to some; soon = published taxonomy without enough content yet.';
comment on column public.themes.published is 'Visible to clients at all. Offering is decided by `status`.';

create index if not exists themes_live_sort_order_idx on public.themes (sort_order) where published and status = 'live';

-- word_themes --------------------------------------------------------------------------------------

create table if not exists public.word_themes (
  word_id uuid not null references public.words (id) on delete cascade,
  theme_id uuid not null references public.themes (id) on delete cascade,
  relevance smallint not null default 2 check (relevance between 1 and 3),
  sort_order integer,
  primary key (word_id, theme_id)
);

comment on table public.word_themes is 'Which themes a word belongs to. A word carries 1-3 themes.';
comment on column public.word_themes.relevance is '3 = the word is the point of the theme, 2 = clearly useful, 1 = adjacent.';
comment on column public.word_themes.sort_order is 'Introduction order inside the theme; falls back to words.sort_order when null.';

create index if not exists word_themes_theme_sort_order_idx on public.word_themes (theme_id, sort_order);

-- words.semantic_set_id ----------------------------------------------------------------------------
--
-- The semantic-set interference rule (docs/learning-method.md §7). Tinkham
-- (1993, 1997) and Nation (2000) found that synonyms, antonyms and category
-- mates presented together are learned more slowly, while thematic or
-- scenario clusters are not. Two words sharing a `semantic_set_id` are never
-- introduced within 7 days of each other, exactly like paronyms. Themes are a
-- thematic cluster, so they are deliberately NOT a semantic set.

alter table public.words add column if not exists semantic_set_id text;

comment on column public.words.semantic_set_id is 'Synonym / antonym / category-mate group. Two words of the same set are never introduced within 7 days (Tinkham 1993; Nation 2000).';

create index if not exists words_semantic_set_id_idx on public.words (semantic_set_id) where semantic_set_id is not null;

-- daily_sessions.theme_id --------------------------------------------------------------------------

alter table public.daily_sessions add column if not exists theme_id uuid references public.themes (id);

comment on column public.daily_sessions.theme_id is 'The theme chosen for this local day. Changing it recomputes the plan exactly like `minutes` does. NULL = no theme (global candidate pool).';

-- exercises: recombination kinds ---------------------------------------------------------------------
--
-- `cloze` keeps every invariant it had. The three new kinds are the
-- recombination content a theme falls back to once its new words run out:
--   registro   3 options, 1 correct  (same idea, which register fits here)
--   reemplazo  3 options, 1 correct  (swap the vague phrase for the sharp one)
--   contraste  2 options, 1 correct  (A vs B: the pair the user keeps mixing up)

do $$
declare
  v_name text;
begin
  -- The original check was declared inline, so its name is generated. Drop
  -- whatever check on `exercises` constrains `kind`, by definition rather than
  -- by a name this migration would have to guess.
  for v_name in
    select c.conname
    from pg_constraint c
    where c.conrelid = 'public.exercises'::regclass
      and c.contype = 'c'
      and pg_get_constraintdef(c.oid) ilike '%kind%'
  loop
    execute format('alter table public.exercises drop constraint %I', v_name);
  end loop;
end;
$$;

alter table public.exercises
  add constraint exercises_kind_check
  check (kind in ('cloze', 'contraste', 'registro', 'reemplazo'));

alter table public.exercises add column if not exists secondary_word_id uuid references public.words (id) on delete cascade;

comment on column public.exercises.secondary_word_id is 'The B side of a contraste item. Deleting either word removes the item, because half a contrast is not an exercise.';

alter table public.exercises drop constraint if exists exercises_secondary_word_differs;
alter table public.exercises
  add constraint exercises_secondary_word_differs
  check (secondary_word_id is null or secondary_word_id <> word_id);

alter table public.exercises drop constraint if exists exercises_contraste_has_secondary;
alter table public.exercises
  add constraint exercises_contraste_has_secondary
  check (kind <> 'contraste' or secondary_word_id is not null);

create index if not exists exercises_secondary_word_id_idx on public.exercises (secondary_word_id);

comment on table public.exercises is 'Exercises. `sentence` contains exactly one {{blank}} token. `contraste` items carry 2 options; every other kind carries 3.';
comment on table public.exercise_options is 'Options of an exercise: 3 per exercise (2 for `contraste`), exactly 1 correct (deferred constraint trigger).';

-- The option-count invariant, now per kind. Still checked at commit time so an
-- exercise and its options can be inserted in separate statements of the same
-- transaction.
create or replace function public.check_exercise_options_invariant()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_exercise_ids uuid[];
  v_exercise_id uuid;
  v_kind text;
  v_expected integer;
  v_total integer;
  v_correct integer;
begin
  if tg_table_name = 'exercises' then
    v_exercise_ids := array[new.id];
  elsif tg_op = 'INSERT' then
    v_exercise_ids := array[new.exercise_id];
  elsif tg_op = 'DELETE' then
    v_exercise_ids := array[old.exercise_id];
  else
    v_exercise_ids := array[old.exercise_id, new.exercise_id];
  end if;

  foreach v_exercise_id in array v_exercise_ids loop
    -- The exercise itself was deleted (e.g. cascade from its word): nothing to check.
    select e.kind into v_kind from public.exercises e where e.id = v_exercise_id;
    continue when v_kind is null;

    -- A contraste is one pair, A against B; everything else keeps 3 options.
    v_expected := case when v_kind = 'contraste' then 2 else 3 end;

    select count(*), count(*) filter (where o.is_correct)
      into v_total, v_correct
      from public.exercise_options o
     where o.exercise_id = v_exercise_id;

    if v_total <> v_expected or v_correct <> 1 then
      raise exception 'exercise % (%) must have exactly % options and exactly 1 correct (found % options, % correct)',
        v_exercise_id, v_kind, v_expected, v_total, v_correct
        using errcode = 'check_violation';
    end if;
  end loop;

  return null;
end;
$$;

revoke all on function public.check_exercise_options_invariant() from public, anon, authenticated;

-- Privileges and RLS ---------------------------------------------------------------------------------

alter table public.themes enable row level security;
alter table public.word_themes enable row level security;

revoke all on table public.themes, public.word_themes from anon, authenticated;
grant select on table public.themes, public.word_themes to authenticated;
grant all on table public.themes, public.word_themes to service_role;

-- Themes are the shape of the offer, not the paid content itself: any
-- signed-in user may read the published taxonomy, including one who has not
-- started a trial yet. The words behind a theme stay behind `has_access()`.
drop policy if exists themes_select_readable on public.themes;
create policy themes_select_readable on public.themes
  for select to authenticated
  using (published);

-- Child table: visible when the parent word is visible under its own policy.
drop policy if exists word_themes_select_readable on public.word_themes;
create policy word_themes_select_readable on public.word_themes
  for select to authenticated
  using (exists (select 1 from public.words w where w.id = word_themes.word_id));
