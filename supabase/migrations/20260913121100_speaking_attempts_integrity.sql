-- Confused-deputy fix (independent security review finding F1, on top of
-- U21/decision #522): the update-only speaking_attempts_guard_audio trigger
-- from 20260913120800_speaking_history.sql let an authenticated client
-- (a) set an arbitrary audio_path (any string matching the table's general
-- '<segment>/<segment>.<ext>' shape check, not necessarily their own row)
-- once audio_status transitioned to 'stored', and (b) backdate created_at at
-- insert time (no server-clock enforcement existed on that column). Chained
-- together, a user could insert an own row with created_at far in the past,
-- move it pending -> stored while pointing audio_path at ANOTHER user's
-- canonical object key, and have the daily audio-retention sweep
-- (service_role) delete that object once "expired". This migration closes
-- both gaps at the source, in the table's own trigger, so every writer --
-- the app, a hand-crafted API call, or a future feature -- is protected the
-- same way:
--
--   1. created_at is always the server clock on insert; any client-supplied
--      value is silently ignored (never rejected -- see the grants note
--      below for why "ignore", not "reject").
--   2. A non-null audio_path must be exactly this row's own canonical
--      <user_id>/<id>.<ext> path, ext one of the allowed audio MIME
--      extensions (matching audio_mime's own check constraint:
--      wav/webm/ogg/mp4). This now applies on BOTH insert and update, so
--      the previously update-only path (audio_status pending -> stored) is
--      also ownership-checked, not just shape-checked.
--
-- Column-level INSERT grants were deliberately NOT tightened here, even
-- though that would be a plausible second layer for created_at:
--   - user_id/id must stay insertable: the app's
--     SupabaseSpeakingAttemptRepository/SpeakingAttemptDto never sends
--     user_id (relies on the column default `auth.uid()`), so restricting
--     it would not break the app -- but 090_speaking_attempts.test.sql and
--     110_speaking_audio_storage.test.sql's already-green fixtures legitimately
--     list user_id in their own authenticated-role INSERT statements (the
--     value is already re-validated against auth.uid() by the
--     speaking_attempts_insert_own policy). Restricting the grant would
--     break those tests for no additional protection, since RLS already
--     fully owns that check. `id` is always sent by the DTO
--     (SpeakingAttemptDto.fromDomain always includes it) and is not part of
--     this vulnerability -- the canonical-path trigger scopes audio_path to
--     whichever id/user_id the row actually has, however chosen.
--   - created_at: revoking column-level INSERT access would turn "ignore a
--     backdated value" into "reject the whole insert" -- a stricter and
--     different contract than the one required here. The trigger already
--     makes any client-supplied created_at unobservable in the stored row,
--     which is sufficient and matches the documented "ignore" contract; no
--     pgTAP/app fixture ever relies on setting created_at explicitly
--     through the authenticated role.
--
-- Existing rows are never revalidated by this migration (a trigger, not a
-- CHECK constraint, applies only to future writes) -- see
-- select_expired_milestone_audio's matching defense-in-depth read-side
-- guard (20260913121000_audio_retention.sql) against any pre-fix data, and
-- the audio-retention Edge Function's own ownership check
-- (supabase/functions/audio-retention/handler.ts) as a third, independent
-- layer before any service-role delete.

create or replace function public.speaking_attempts_guard_audio()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.created_at := now();
  end if;

  if new.audio_path is not null
     and new.audio_path not in (
       new.user_id::text || '/' || new.id::text || '.wav',
       new.user_id::text || '/' || new.id::text || '.webm',
       new.user_id::text || '/' || new.id::text || '.ogg',
       new.user_id::text || '/' || new.id::text || '.mp4'
     )
  then
    raise exception 'speaking_attempts audio_path must be the row''s own canonical <user_id>/<id>.<ext> path'
      using errcode = 'check_violation';
  end if;

  if tg_op = 'INSERT' then
    return new;
  end if;

  -- UPDATE: existing audio_status transition rules, unchanged.
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

comment on function public.speaking_attempts_guard_audio() is 'Trigger function: forces created_at to the server clock on insert, rejects any non-null audio_path that is not the row''s own canonical <user_id>/<id>.<ext> path (insert and update), and enforces the speaking_attempts audio_status state machine (none/deleted terminal) on update. Security review finding F1.';

revoke all on function public.speaking_attempts_guard_audio() from public, anon, authenticated;

drop trigger if exists speaking_attempts_guard_audio on public.speaking_attempts;
create trigger speaking_attempts_guard_audio
  before insert or update on public.speaking_attempts
  for each row execute function public.speaking_attempts_guard_audio();
