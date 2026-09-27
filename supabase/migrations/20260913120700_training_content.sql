-- Training content: challenges (diagnosis + lab prompts) and the additive
-- daily_sessions plan columns produced by the training planner.
--
-- Readable by every signed-in user once published, with no `has_access` gate
-- (D10 -- the content itself is not the paid cost, unlike words); never
-- writable by clients (content is managed with the service role / SQL).

-- challenges ----------------------------------------------------------------------------------------

create table if not exists public.challenges (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  purpose text not null check (purpose in ('training', 'diagnosis')),
  diagnosis_slot smallint check (diagnosis_slot between 1 and 3),
  skill text not null check (skill in ('thinking', 'language', 'voice')),
  mode text check (mode in ('think_and_speak', 'speak_with_precision', 'master_your_voice', 'real_situations')),
  difficulty smallint not null check (difficulty between 1 and 3),
  prompt text not null check (char_length(prompt) between 10 and 280),
  cue text check (char_length(cue) <= 200),
  focus text not null check (char_length(focus) between 5 and 200),
  focus_behaviors text[] not null default '{}',
  transfer_prompts text[] not null default '{}' check (cardinality(transfer_prompts) <= 3),
  target_seconds smallint not null default 30 check (target_seconds between 15 and 60),
  sort_order integer not null,
  published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint challenges_diagnosis_slot_matches_purpose check ((purpose = 'diagnosis') = (diagnosis_slot is not null)),
  constraint challenges_mode_matches_purpose check ((purpose = 'training') = (mode is not null)),
  constraint challenges_transfer_prompts_required check (purpose = 'diagnosis' or cardinality(transfer_prompts) >= 1)
);

comment on table public.challenges is 'Diagnosis and training-lab prompts, seeded from content/challenges/*.yml. Published content is readable without an access gate.';
comment on column public.challenges.diagnosis_slot is 'Which of the 3 diagnosis slots this challenge belongs to; null for training challenges.';
comment on column public.challenges.mode is 'Which of the 4 training-lab modes this challenge belongs to; null for diagnosis challenges.';
comment on column public.challenges.focus_behaviors is 'BehaviorCode wire codes the LLM is nudged to look for; app/content parity is enforced outside the database.';
comment on column public.challenges.transfer_prompts is 'Follow-up prompts for the transfer step; at least 1 for training, may be empty for diagnosis (measure-only).';
comment on column public.challenges.sort_order is 'Deterministic ordering used by the training planner and by content emission.';

create index if not exists challenges_published_lookup_idx on public.challenges (purpose, skill, difficulty, sort_order) where published;

drop trigger if exists challenges_set_updated_at on public.challenges;
create trigger challenges_set_updated_at
  before update on public.challenges
  for each row execute function public.set_updated_at();

alter table public.challenges enable row level security;

revoke all on table public.challenges from anon, authenticated;
grant select on table public.challenges to authenticated;
grant all on table public.challenges to service_role;

drop policy if exists challenges_select_published on public.challenges;
create policy challenges_select_published on public.challenges
  for select to authenticated
  using (published);

-- daily_sessions plan columns (additive) -------------------------------------------------------------

alter table public.daily_sessions
  add column if not exists focus_area text check (focus_area in ('thinking', 'language', 'voice', 'fluency')),
  add column if not exists challenge_id uuid references public.challenges (id) on delete set null,
  add column if not exists woven_word_ids uuid[] not null default '{}';

comment on column public.daily_sessions.focus_area is 'The training planner''s chosen SkillArea for the day; null before the planner runs.';
comment on column public.daily_sessions.challenge_id is 'The challenge picked for the day''s first speaking round; set null if the challenge is later removed.';
comment on column public.daily_sessions.woven_word_ids is 'Up to 3 due review word ids woven into the transfer step by the training planner.';

-- Existing daily_sessions RLS/grants already cover these new columns (whole-row policies).
