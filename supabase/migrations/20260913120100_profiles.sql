-- profiles: one row per auth user, created by trigger at signup.
--
-- A profile grants no access by itself. The 7-day free trial is a Whop trial
-- (card collected at checkout) and lives in `entitlements`
-- (see docs/adr/0004-whop-payments-and-entitlements.md).

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text check (display_name is null or char_length(display_name) between 1 and 80),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is 'Public profile of each user. Created by the on_auth_user_created trigger.';
comment on column public.profiles.display_name is 'The only column clients may update (column privileges).';

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- Signup trigger -------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, left(nullif(btrim(new.raw_user_meta_data ->> 'display_name'), ''), 80))
  on conflict (id) do nothing;
  return new;
end;
$$;

comment on function public.handle_new_user() is 'Trigger function on auth.users: creates the matching profile.';

revoke all on function public.handle_new_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Privileges and RLS ---------------------------------------------------------------------

alter table public.profiles enable row level security;

revoke all on table public.profiles from anon, authenticated;
grant select on table public.profiles to authenticated;
-- Column-level privilege: clients may only change their display name.
grant update (display_name) on table public.profiles to authenticated;
grant all on table public.profiles to service_role;

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
  for select to authenticated
  using (id = (select auth.uid()));

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));
