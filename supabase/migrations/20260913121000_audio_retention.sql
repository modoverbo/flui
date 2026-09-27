-- Audio retention selection (decision #430, revised #522): SECURITY DEFINER,
-- service_role-only functions that select which speaking-audio storage work
-- the audio-retention Edge Function should act on. Selection alone never
-- deletes or updates anything -- the Edge Function acts on exactly what
-- these functions return, batched and bounded by p_batch_size.
--
-- (a) Expired milestone audio: a weekly-milestone speaking_attempts row
--     (milestone_week not null) whose audio has been stored for more than 90
--     days. context <> 'diagnosis' is checked explicitly even though the
--     milestone_week check constraint already guarantees a diagnosis row can
--     never carry a milestone_week -- decision #430 keeps diagnosis baseline
--     audio for the account lifetime and this selection must never expire
--     it, regardless of how old it is.
-- (b) Orphaned speaking-audio objects: any object in the speaking-audio
--     bucket older than a 24 h grace period whose name is not the audio_path
--     of a speaking_attempts row currently audio_status = 'stored' (decision
--     #522). This reconciles objects left behind by a failed status update,
--     a client crash mid-upload, or any other client/server mismatch --
--     never an object still referenced by a stored row.

create or replace function public.select_expired_milestone_audio(p_batch_size integer default 500)
returns table (attempt_id uuid, user_id uuid, audio_path text)
language sql
stable
security definer
set search_path = ''
as $$
  select id, user_id, audio_path
  from public.speaking_attempts
  where milestone_week is not null
    and audio_status = 'stored'
    and context <> 'diagnosis'
    and created_at < now() - interval '90 days'
  order by created_at asc
  limit p_batch_size;
$$;

comment on function public.select_expired_milestone_audio(integer) is
  'Selects weekly-milestone speaking_attempts rows whose stored audio is older than 90 days (decision #430). Diagnosis baselines are never selected. service_role only, bounded by p_batch_size.';

revoke all on function public.select_expired_milestone_audio(integer) from public, anon, authenticated;
grant execute on function public.select_expired_milestone_audio(integer) to service_role;

create or replace function public.select_orphaned_speaking_audio(p_batch_size integer default 500)
returns table (object_name text, created_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select o.name, o.created_at
  from storage.objects o
  where o.bucket_id = 'speaking-audio'
    and o.created_at < now() - interval '24 hours'
    and not exists (
      select 1
      from public.speaking_attempts sa
      where sa.audio_status = 'stored'
        and sa.audio_path = o.name
    )
  order by o.created_at asc
  limit p_batch_size;
$$;

comment on function public.select_orphaned_speaking_audio(integer) is
  'Selects speaking-audio storage objects older than a 24 h grace period that are not the audio_path of any audio_status = stored speaking_attempts row (decision #522). Never selects an object referenced by a stored row. service_role only, bounded by p_batch_size.';

revoke all on function public.select_orphaned_speaking_audio(integer) from public, anon, authenticated;
grant execute on function public.select_orphaned_speaking_audio(integer) to service_role;
