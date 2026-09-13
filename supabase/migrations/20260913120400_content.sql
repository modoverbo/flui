-- Learning content: words and everything attached to a word.
--
-- Readable only by signed-in users with access (`has_access()`: a trialing or
-- active Whop entitlement); never writable by clients (content is managed with the
-- service role / SQL). Only published words are visible. Child tables inherit
-- visibility from their word through the words RLS policy.
--
-- Product content (definitions, sentences, hints, readings) is written in Spanish.

-- words -------------------------------------------------------------------------------------------

create table if not exists public.words (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  lemma text not null check (btrim(lemma) <> ''),
  part_of_speech text not null check (part_of_speech in ('adjetivo', 'adverbio', 'conector', 'sustantivo', 'verbo')),
  syllables text[] not null check (cardinality(syllables) > 0),
  stressed_syllable smallint not null,
  ipa_latam text,
  ipa_es text,
  explanation text not null check (btrim(explanation) <> ''),
  example_sentence text not null check (btrim(example_sentence) <> ''),
  register text not null check (register in ('neutral', 'culto', 'coloquial')),
  pedantry_risk smallint not null check (pedantry_risk between 1 and 3),
  usage_tip text,
  when_not_to_use text,
  collocations text[] not null default '{}',
  replaces jsonb not null default '[]'::jsonb,
  family text[] not null default '{}',
  sort_order integer not null,
  published boolean not null default false,
  created_at timestamptz not null default now(),
  constraint words_stressed_syllable_in_range check (stressed_syllable between 1 and cardinality(syllables)),
  constraint words_replaces_shape check (
    jsonb_typeof(replaces) = 'array'
    and not jsonb_path_exists(replaces, '$[*] ? (!(exists(@.before)) || !(exists(@.after)))')
  )
);

comment on table public.words is 'Word catalog. Published words are readable by users with access.';
comment on column public.words.syllables is 'Syllables in order, e.g. {pers,pi,caz}.';
comment on column public.words.stressed_syllable is '1-based index into syllables.';
comment on column public.words.replaces is 'Array of {"before": text, "after": text} replacements (vague phrase -> better phrase).';
comment on column public.words.sort_order is 'Default introduction order for the session planner.';

create index if not exists words_published_sort_order_idx on public.words (sort_order) where published;

-- word_confusions ------------------------------------------------------------------------------------

create table if not exists public.word_confusions (
  id uuid primary key default gen_random_uuid(),
  word_id uuid not null references public.words (id) on delete cascade,
  confused_with text not null check (btrim(confused_with) <> ''),
  confused_word_id uuid references public.words (id) on delete set null,
  difference text not null check (btrim(difference) <> ''),
  memory_trick text,
  unique (word_id, confused_with)
);

comment on table public.word_confusions is 'Paronyms and near-synonyms of a word. Also drives the paronym interference rule.';
comment on column public.word_confusions.confused_word_id is 'Set when the confusable word is itself in the catalog.';

create index if not exists word_confusions_word_id_idx on public.word_confusions (word_id);
create index if not exists word_confusions_confused_word_id_idx on public.word_confusions (confused_word_id);

-- exercises ----------------------------------------------------------------------------------------------

create table if not exists public.exercises (
  id uuid primary key default gen_random_uuid(),
  word_id uuid not null references public.words (id) on delete cascade,
  kind text not null default 'cloze' check (kind in ('cloze')),
  sentence text not null,
  hint_general text not null check (btrim(hint_general) <> ''),
  explanation text not null check (btrim(explanation) <> ''),
  position smallint not null check (position > 0),
  unique (word_id, position),
  -- Exactly one literal {{blank}} token.
  constraint exercises_sentence_has_one_blank check (
    char_length(sentence) - char_length(replace(sentence, '{{blank}}', '')) = char_length('{{blank}}')
  )
);

comment on table public.exercises is 'Cloze exercises. `sentence` contains exactly one {{blank}} token.';

-- exercise_options ----------------------------------------------------------------------------------------

create table if not exists public.exercise_options (
  id uuid primary key default gen_random_uuid(),
  exercise_id uuid not null references public.exercises (id) on delete cascade,
  text text not null check (btrim(text) <> ''),
  is_correct boolean not null default false,
  distractor_type text check (distractor_type in ('paronym', 'near_synonym', 'register')),
  why_not text,
  hint_specific text,
  position smallint not null check (position > 0),
  unique (exercise_id, position),
  unique (exercise_id, text),
  -- The correct option carries no distractor data; every distractor is typed and explained.
  constraint exercise_options_distractor_details check (
    (is_correct and distractor_type is null and why_not is null and hint_specific is null)
    or (not is_correct and distractor_type is not null and why_not is not null and hint_specific is not null)
  )
);

comment on table public.exercise_options is 'Options of a cloze exercise: exactly 3 per exercise, exactly 1 correct (deferred constraint trigger).';

-- Invariant: every exercise has exactly 3 options and exactly 1 of them is correct.
-- Checked at commit time so that an exercise and its options can be inserted in
-- separate statements of the same transaction.
create or replace function public.check_exercise_options_invariant()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_exercise_ids uuid[];
  v_exercise_id uuid;
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
    continue when not exists (select 1 from public.exercises e where e.id = v_exercise_id);

    select count(*), count(*) filter (where o.is_correct)
      into v_total, v_correct
      from public.exercise_options o
     where o.exercise_id = v_exercise_id;

    if v_total <> 3 or v_correct <> 1 then
      raise exception 'exercise % must have exactly 3 options and exactly 1 correct (found % options, % correct)',
        v_exercise_id, v_total, v_correct
        using errcode = 'check_violation';
    end if;
  end loop;

  return null;
end;
$$;

revoke all on function public.check_exercise_options_invariant() from public, anon, authenticated;

drop trigger if exists exercise_options_invariant on public.exercise_options;
create constraint trigger exercise_options_invariant
  after insert or update or delete on public.exercise_options
  deferrable initially deferred
  for each row execute function public.check_exercise_options_invariant();

drop trigger if exists exercises_have_options on public.exercises;
create constraint trigger exercises_have_options
  after insert on public.exercises
  deferrable initially deferred
  for each row execute function public.check_exercise_options_invariant();

-- readings ---------------------------------------------------------------------------------------------------

create table if not exists public.readings (
  id uuid primary key default gen_random_uuid(),
  word_id uuid not null references public.words (id) on delete cascade,
  scene text not null check (scene in ('trabajo', 'social', 'entrevista', 'familia')),
  conversation_type text not null check (conversation_type in ('practica', 'emocional', 'social')),
  title text not null check (btrim(title) <> ''),
  body text not null check (btrim(body) <> ''),
  before_phrase text not null check (btrim(before_phrase) <> ''),
  after_phrase text not null check (btrim(after_phrase) <> ''),
  position smallint not null check (position > 0),
  unique (word_id, position)
);

comment on table public.readings is 'Short scenes that show a word in context ("Mira"), tagged by scene and conversation type.';

-- Privileges and RLS --------------------------------------------------------------------------------------------

alter table public.words enable row level security;
alter table public.word_confusions enable row level security;
alter table public.exercises enable row level security;
alter table public.exercise_options enable row level security;
alter table public.readings enable row level security;

revoke all on table public.words, public.word_confusions, public.exercises, public.exercise_options, public.readings
  from anon, authenticated;
grant select on table public.words, public.word_confusions, public.exercises, public.exercise_options, public.readings
  to authenticated;
grant all on table public.words, public.word_confusions, public.exercises, public.exercise_options, public.readings
  to service_role;

drop policy if exists words_select_readable on public.words;
create policy words_select_readable on public.words
  for select to authenticated
  using (published and (select public.has_access()));

-- Child tables: visible when the parent row is visible under its own policy.
drop policy if exists word_confusions_select_readable on public.word_confusions;
create policy word_confusions_select_readable on public.word_confusions
  for select to authenticated
  using (exists (select 1 from public.words w where w.id = word_confusions.word_id));

drop policy if exists exercises_select_readable on public.exercises;
create policy exercises_select_readable on public.exercises
  for select to authenticated
  using (exists (select 1 from public.words w where w.id = exercises.word_id));

drop policy if exists exercise_options_select_readable on public.exercise_options;
create policy exercise_options_select_readable on public.exercise_options
  for select to authenticated
  using (exists (select 1 from public.exercises e where e.id = exercise_options.exercise_id));

drop policy if exists readings_select_readable on public.readings;
create policy readings_select_readable on public.readings
  for select to authenticated
  using (exists (select 1 from public.words w where w.id = readings.word_id));
