-- Test helpers shared by every pgTAP file in this folder.
--
-- pg_prove runs files in alphabetical order, so this file installs the helpers
-- (idempotently, outside a rolled-back transaction) before the other files run.
-- The `tests` schema only exists in local/CI databases; it is never part of a
-- migration.

create extension if not exists pgtap with schema extensions;

create schema if not exists tests;
grant usage on schema tests to anon, authenticated, service_role;

-- Creates an auth user (which fires the profile trigger) and returns its id.
create or replace function tests.create_user(p_email text, p_display_name text default null)
returns uuid
language plpgsql
as $$
declare
  v_id uuid := gen_random_uuid();
begin
  insert into auth.users (id, instance_id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (
    v_id,
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    p_email,
    '{"provider": "email", "providers": ["email"]}'::jsonb,
    case when p_display_name is null then '{}'::jsonb else jsonb_build_object('display_name', p_display_name) end,
    now(),
    now()
  );
  return v_id;
end;
$$;

-- Impersonates a signed-in user for the rest of the transaction.
create or replace function tests.authenticate_as(p_user_id uuid)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

-- Impersonates an anonymous (signed-out) client for the rest of the transaction.
create or replace function tests.authenticate_as_anon()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  perform set_config('role', 'anon', true);
end;
$$;

-- Impersonates the service role (used by Edge Functions).
create or replace function tests.authenticate_as_service_role()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
  perform set_config('role', 'service_role', true);
end;
$$;

-- Returns to the session user (postgres) with no JWT claims.
create or replace function tests.clear_authentication()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', '', true);
  perform set_config('role', 'none', true);
end;
$$;

grant execute on all functions in schema tests to anon, authenticated, service_role;

select plan(5);
select has_function('tests', 'create_user', array['text', 'text'], 'tests.create_user exists');
select has_function('tests', 'authenticate_as', array['uuid'], 'tests.authenticate_as exists');
select has_function('tests', 'authenticate_as_anon', 'tests.authenticate_as_anon exists');
select has_function('tests', 'authenticate_as_service_role', 'tests.authenticate_as_service_role exists');
select has_function('tests', 'clear_authentication', 'tests.clear_authentication exists');
select * from finish();
