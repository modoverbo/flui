-- Per-user learning data. Written by the Flutter app, which owns the domain logic
-- (session planning, grading, mastery, streaks). RLS limits every row to its
-- owner, so tampering can only affect the user's own learning history.
-- See docs/adr/0003-domain-logic-in-dart-client.md and docs/learning-method.md.

-- daily_sessions ------------------------------------------------------------------------------------

create table if not exists public.daily_sessions (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  local_date date not null,
  minutes smallint not null check (minutes between 5 and 60),
  planned_word_ids uuid[] not null default '{}',
  review_word_ids uuid[] not null default '{}',
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, local_date)
);

comment on table public.daily_sessions is 'The time budget chosen for a local day and the plan produced by the SessionPlanner.';
comment on column public.daily_sessions.local_date is 'Calendar date in the user''s time zone.';

drop trigger if exists daily_sessions_set_updated_at on public.daily_sessions;
create trigger daily_sessions_set_updated_at
  before update on public.daily_sessions
  for each row execute function public.set_updated_at();

-- word_progress --------------------------------------------------------------------------------------------

create table if not exists public.word_progress (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  word_id uuid not null references public.words (id) on delete cascade,
  state text not null default 'nueva' check (state in ('nueva', 'practica', 'tuya')),
  introduced_on date not null,
  first_try_success_days date[] not null default '{}',
  form_recall_done boolean not null default false,
  production_done boolean not null default false,
  ladder_step smallint not null default 0 check (ladder_step between 0 and 5),
  next_due_on date,
  last_grade text check (last_grade in ('good', 'hard', 'again')),
  last_reviewed_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (user_id, word_id)
);

comment on table public.word_progress is 'Mastery state and review schedule of a word for one user.';
comment on column public.word_progress.ladder_step is 'Rungs climbed on the 1-3-7-14-30 day review ladder (0 = not yet reviewed).';
comment on column public.word_progress.first_try_success_days is 'Distinct local dates with a first-try success in a review.';

create index if not exists word_progress_due_idx on public.word_progress (user_id, next_due_on);

drop trigger if exists word_progress_set_updated_at on public.word_progress;
create trigger word_progress_set_updated_at
  before update on public.word_progress
  for each row execute function public.set_updated_at();

-- exercise_attempts (append-only) ------------------------------------------------------------------------------

create table if not exists public.exercise_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  exercise_id uuid not null references public.exercises (id) on delete cascade,
  word_id uuid not null references public.words (id) on delete cascade,
  attempts smallint not null check (attempts between 1 and 3),
  revealed boolean not null default false,
  grade text not null check (grade in ('good', 'hard', 'again')),
  local_date date not null,
  duration_ms integer check (duration_ms >= 0),
  created_at timestamptz not null default now(),
  constraint exercise_attempts_revealed_is_again check (not revealed or grade = 'again')
);

comment on table public.exercise_attempts is 'One row per answered exercise. Append-only for clients.';

create index if not exists exercise_attempts_user_date_idx on public.exercise_attempts (user_id, local_date);

-- streak_repairs -------------------------------------------------------------------------------------------------

create table if not exists public.streak_repairs (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  repaired_date date not null,
  created_at timestamptz not null default now(),
  primary key (user_id, repaired_date)
);

comment on table public.streak_repairs is 'Missed local dates the user repaired with the free weekly streak repair.';

-- Privileges and RLS -------------------------------------------------------------------------------------------------

alter table public.daily_sessions enable row level security;
alter table public.word_progress enable row level security;
alter table public.exercise_attempts enable row level security;
alter table public.streak_repairs enable row level security;

revoke all on table public.daily_sessions, public.word_progress, public.exercise_attempts, public.streak_repairs
  from anon, authenticated;
grant select, insert, update on table public.daily_sessions, public.word_progress to authenticated;
grant select, insert on table public.exercise_attempts, public.streak_repairs to authenticated;
grant all on table public.daily_sessions, public.word_progress, public.exercise_attempts, public.streak_repairs
  to service_role;

-- daily_sessions
drop policy if exists daily_sessions_select_own on public.daily_sessions;
create policy daily_sessions_select_own on public.daily_sessions
  for select to authenticated using (user_id = (select auth.uid()));

drop policy if exists daily_sessions_insert_own on public.daily_sessions;
create policy daily_sessions_insert_own on public.daily_sessions
  for insert to authenticated with check (user_id = (select auth.uid()));

drop policy if exists daily_sessions_update_own on public.daily_sessions;
create policy daily_sessions_update_own on public.daily_sessions
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- word_progress
drop policy if exists word_progress_select_own on public.word_progress;
create policy word_progress_select_own on public.word_progress
  for select to authenticated using (user_id = (select auth.uid()));

drop policy if exists word_progress_insert_own on public.word_progress;
create policy word_progress_insert_own on public.word_progress
  for insert to authenticated with check (user_id = (select auth.uid()));

drop policy if exists word_progress_update_own on public.word_progress;
create policy word_progress_update_own on public.word_progress
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- exercise_attempts
drop policy if exists exercise_attempts_select_own on public.exercise_attempts;
create policy exercise_attempts_select_own on public.exercise_attempts
  for select to authenticated using (user_id = (select auth.uid()));

drop policy if exists exercise_attempts_insert_own on public.exercise_attempts;
create policy exercise_attempts_insert_own on public.exercise_attempts
  for insert to authenticated with check (user_id = (select auth.uid()));

-- streak_repairs
drop policy if exists streak_repairs_select_own on public.streak_repairs;
create policy streak_repairs_select_own on public.streak_repairs
  for select to authenticated using (user_id = (select auth.uid()));

drop policy if exists streak_repairs_insert_own on public.streak_repairs;
create policy streak_repairs_insert_own on public.streak_repairs
  for insert to authenticated with check (user_id = (select auth.uid()));
