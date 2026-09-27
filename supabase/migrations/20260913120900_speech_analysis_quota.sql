-- Daily paid speech-analysis quota (#430): bounds Groq spend per user per UTC
-- day. `speech_analysis_usage` is never read or written by clients -- only
-- `claim_speech_analysis` (SECURITY DEFINER, service_role only) touches it,
-- called by the speech-analyze Edge Function before any provider call, in
-- every analysis mode (a transcription-only call also claims 1 unit).

create table if not exists public.speech_analysis_usage (
  user_id uuid not null references auth.users (id) on delete cascade,
  usage_date date not null,
  analyses integer not null default 0 check (analyses >= 0),
  primary key (user_id, usage_date)
);

comment on table public.speech_analysis_usage is
  'Per-user-per-UTC-day paid speech-analysis call count. Written only by claim_speech_analysis (service_role); never queried or written directly by clients.';

alter table public.speech_analysis_usage enable row level security;

revoke all on table public.speech_analysis_usage from public, anon, authenticated;
grant all on table public.speech_analysis_usage to service_role;

create or replace function public.claim_speech_analysis(p_user_id uuid, p_daily_limit integer default 60)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_analyses integer;
begin
  insert into public.speech_analysis_usage as u (user_id, usage_date, analyses)
  values (p_user_id, (now() at time zone 'utc')::date, 1)
  on conflict (user_id, usage_date) do update
    set analyses = u.analyses + 1
    where u.analyses < p_daily_limit
  returning u.analyses into v_analyses;

  return v_analyses is not null;
end;
$$;

comment on function public.claim_speech_analysis(uuid, integer) is
  'Atomically claims one paid speech-analysis unit for the caller''s current UTC day. Returns true when the claim is under p_daily_limit, false once the day''s quota is exhausted. service_role only.';

revoke all on function public.claim_speech_analysis(uuid, integer) from public, anon, authenticated;
grant execute on function public.claim_speech_analysis(uuid, integer) to service_role;
