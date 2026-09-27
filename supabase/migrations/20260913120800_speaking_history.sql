-- Speaking history: every analyzed speaking attempt (append-only) and the
-- one-row-per-diagnosis skill profile it produces.
--
-- RLS limits every row to its owner. speaking_attempts is append-only for
-- clients: only audio_status/audio_path/audio_mime are ever client-writable,
-- and only through the documented state machine (see the guard trigger
-- below). skill_profiles is select/insert only; the trigger owns kind and
-- diagnosed_at and rejects a retake less than 30 days after the previous one.

-- speaking_attempts ----------------------------------------------------------------------------------

create table if not exists public.speaking_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  session_id uuid not null,
  context text not null check (context in ('diagnosis', 'daily', 'lab', 'word', 'quick')),
  kind text not null check (kind in ('first', 'repeat', 'transfer')),
  challenge_id uuid references public.challenges (id) on delete set null,
  target_word_ids uuid[] not null default '{}',
  words_used uuid[] not null default '{}',
  local_date date not null,
  transcript text not null check (char_length(transcript) between 1 and 5000),
  duration_ms integer not null check (duration_ms between 500 and 60000),
  metrics jsonb not null default '{}'::jsonb check (jsonb_typeof(metrics) = 'object' and octet_length(metrics::text) < 4096),
  observations jsonb not null default '[]'::jsonb check (jsonb_typeof(observations) = 'array' and octet_length(observations::text) < 8192),
  audio_status text not null default 'none' check (audio_status in ('none', 'pending', 'stored', 'failed', 'deleted')),
  audio_path text check (audio_path ~ '^[^/]+/[^/]+\.[^/.]+$'),
  audio_mime text check (audio_mime in ('audio/wav', 'audio/webm', 'audio/ogg', 'audio/mp4')),
  milestone_week date,
  created_at timestamptz not null default now(),
  constraint speaking_attempts_audio_path_matches_status check ((audio_status = 'stored') = (audio_path is not null)),
  constraint speaking_attempts_milestone_week_shape check (
    milestone_week is null
    or (context in ('daily', 'lab') and kind = 'first' and extract(isodow from milestone_week) = 1)
  )
);

comment on table public.speaking_attempts is 'Append-only history of every analyzed speaking attempt. Diagnosis progress is derived from these rows (no separate progress column).';
comment on column public.speaking_attempts.session_id is 'Groups the attempts of one training/diagnosis session; not a foreign key.';
comment on column public.speaking_attempts.audio_status is 'none/deleted are terminal; pending->stored|failed, failed->pending|stored, stored->deleted are the only allowed transitions (see the guard trigger).';
comment on column public.speaking_attempts.audio_path is 'Storage object key, shaped <uid>/<attempt id>.<ext>; only set together with audio_status = stored.';
comment on column public.speaking_attempts.milestone_week is 'Monday of the local ISO week this attempt counts as a stored milestone for; unique per (user, week).';

create unique index if not exists speaking_attempts_user_milestone_week_idx
  on public.speaking_attempts (user_id, milestone_week) where milestone_week is not null;

alter table public.speaking_attempts enable row level security;

revoke all on table public.speaking_attempts from anon, authenticated;
grant select, insert on table public.speaking_attempts to authenticated;
grant update (audio_status, audio_path, audio_mime) on table public.speaking_attempts to authenticated;
grant all on table public.speaking_attempts to service_role;

drop policy if exists speaking_attempts_select_own on public.speaking_attempts;
create policy speaking_attempts_select_own on public.speaking_attempts
  for select to authenticated using (user_id = (select auth.uid()));

drop policy if exists speaking_attempts_insert_own on public.speaking_attempts;
create policy speaking_attempts_insert_own on public.speaking_attempts
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and audio_path is null
    and audio_status in ('none', 'pending')
  );

drop policy if exists speaking_attempts_update_own on public.speaking_attempts;
create policy speaking_attempts_update_own on public.speaking_attempts
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- Guard trigger: the only audio_status transitions a client update may make.
create or replace function public.speaking_attempts_guard_audio()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.audio_status = old.audio_status then
    return new;
  end if;

  if old.audio_status = 'pending' and new.audio_status in ('stored', 'failed') then
    return new;
  end if;

  if old.audio_status = 'failed' and new.audio_status in ('pending', 'stored') then
    return new;
  end if;

  if old.audio_status = 'stored' and new.audio_status = 'deleted' then
    new.audio_path := null;
    return new;
  end if;

  raise exception 'invalid speaking_attempts audio_status transition: % -> %', old.audio_status, new.audio_status
    using errcode = 'check_violation';
end;
$$;

comment on function public.speaking_attempts_guard_audio() is 'Trigger function: enforces the speaking_attempts audio_status state machine (none/deleted terminal).';

revoke all on function public.speaking_attempts_guard_audio() from public, anon, authenticated;

drop trigger if exists speaking_attempts_guard_audio on public.speaking_attempts;
create trigger speaking_attempts_guard_audio
  before update on public.speaking_attempts
  for each row execute function public.speaking_attempts_guard_audio();

-- skill_profiles ----------------------------------------------------------------------------------------

create table if not exists public.skill_profiles (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  kind text not null check (kind in ('baseline', 'retake')),
  top_area text not null check (top_area in ('thinking', 'language', 'voice', 'fluency')),
  second_area text not null check (second_area in ('thinking', 'language', 'voice', 'fluency')),
  top_behavior text not null check (btrim(top_behavior) <> ''),
  second_behavior text not null check (btrim(second_behavior) <> ''),
  strengths jsonb not null check (jsonb_typeof(strengths) = 'array' and jsonb_array_length(strengths) >= 1),
  evidence jsonb not null default '[]'::jsonb check (jsonb_typeof(evidence) = 'array'),
  diagnosed_at timestamptz not null default now(),
  constraint skill_profiles_areas_distinct check (top_area <> second_area)
);

comment on table public.skill_profiles is 'One row per closed diagnosis session (id = the diagnosis session_id). kind and diagnosed_at are trigger-owned.';
comment on column public.skill_profiles.top_behavior is 'BehaviorCode wire code; free text, catalog parity is enforced outside the database.';
comment on column public.skill_profiles.strengths is 'BehaviorCode wire codes from areas other than top/second, at least 1.';

create index if not exists skill_profiles_user_diagnosed_idx on public.skill_profiles (user_id, diagnosed_at desc);

alter table public.skill_profiles enable row level security;

revoke all on table public.skill_profiles from anon, authenticated;
grant select, insert on table public.skill_profiles to authenticated;
grant all on table public.skill_profiles to service_role;

drop policy if exists skill_profiles_select_own on public.skill_profiles;
create policy skill_profiles_select_own on public.skill_profiles
  for select to authenticated using (user_id = (select auth.uid()));

drop policy if exists skill_profiles_insert_own on public.skill_profiles;
create policy skill_profiles_insert_own on public.skill_profiles
  for insert to authenticated with check (user_id = (select auth.uid()));

-- Trigger: server clock, and kind/30-day-retake enforcement, ignoring the client's kind.
create or replace function public.skill_profiles_before_insert()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_last_diagnosed_at timestamptz;
begin
  new.diagnosed_at := now();

  select max(diagnosed_at) into v_last_diagnosed_at
  from public.skill_profiles
  where user_id = new.user_id;

  if v_last_diagnosed_at is null then
    new.kind := 'baseline';
  else
    if v_last_diagnosed_at > now() - interval '30 days' then
      raise exception 'retake_too_soon' using errcode = 'check_violation';
    end if;
    new.kind := 'retake';
  end if;

  return new;
end;
$$;

comment on function public.skill_profiles_before_insert() is 'Trigger function: server-clock diagnosed_at, trigger-owned kind, 30-day retake enforcement.';

revoke all on function public.skill_profiles_before_insert() from public, anon, authenticated;

drop trigger if exists skill_profiles_before_insert on public.skill_profiles;
create trigger skill_profiles_before_insert
  before insert on public.skill_profiles
  for each row execute function public.skill_profiles_before_insert();
