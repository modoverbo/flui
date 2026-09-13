-- Common helpers shared by every flui table.
--
-- Conventions used across migrations:
--   * Every table enables RLS and starts from REVOKE ALL for the client roles
--     (anon, authenticated). Grants are then added explicitly, so the schema is
--     least-privilege regardless of the project's default privileges.
--   * The service role (Edge Functions) keeps full access and bypasses RLS.
--   * Functions pin `search_path` to '' and schema-qualify every reference.

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

comment on function public.set_updated_at() is 'Trigger function: keeps updated_at current on UPDATE.';

revoke all on function public.set_updated_at() from public, anon, authenticated;
