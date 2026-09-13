-- Access rules: who may use the paid part of flui.
--
-- Access = a Whop entitlement in ('trialing', 'active') whose period has not
-- ended. The 7-day free trial is a Whop trial with the card collected at
-- checkout, so a signup alone grants nothing. Both functions are SECURITY
-- DEFINER with a pinned search_path and are not executable by anon.

create or replace function public.has_access(uid uuid default auth.uid())
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_caller uuid := auth.uid();
begin
  if uid is null then
    return false;
  end if;

  -- A signed-in caller may only evaluate their own access. Server contexts
  -- without a user (service role, migrations, tests) may evaluate any user.
  if v_caller is not null and uid <> v_caller then
    return false;
  end if;

  return exists (
    select 1
    from public.entitlements e
    where e.user_id = uid
      and e.status in ('trialing', 'active')
      and (e.current_period_end is null or e.current_period_end > now())
  );
end;
$$;

comment on function public.has_access(uuid) is 'True when the user has a trialing or active Whop entitlement within its period.';

revoke all on function public.has_access(uuid) from public, anon;
grant execute on function public.has_access(uuid) to authenticated, service_role;

create or replace function public.my_access()
returns json
language sql
stable
security definer
set search_path = ''
as $$
  select json_build_object(
    'has_access', public.has_access(me.uid),
    'entitlement_status', e.status,
    'current_period_end', e.current_period_end,
    'trial_ends_at', case when e.status = 'trialing' then coalesce(e.trial_ends_at, e.current_period_end) end
  )
  from (select auth.uid() as uid) as me
  left join public.entitlements e on e.user_id = me.uid;
$$;

comment on function public.my_access() is
  'Access summary for the signed-in user: {has_access, entitlement_status, current_period_end, trial_ends_at}. trial_ends_at is null unless trialing.';

revoke all on function public.my_access() from public, anon;
grant execute on function public.my_access() to authenticated, service_role;
