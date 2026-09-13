-- profiles: signup trigger, RLS and column privileges.
begin;
select plan(17);

select has_table('public', 'profiles', 'profiles table exists');
select is(
  (select relrowsecurity from pg_class where oid = 'public.profiles'::regclass),
  true,
  'RLS is enabled on profiles'
);

-- Fixtures ------------------------------------------------------------------
select tests.create_user('ana@example.com', 'Ana') as ana_id \gset
select tests.create_user('beto@example.com') as beto_id \gset

-- Signup trigger ------------------------------------------------------------
select is(
  (select display_name from public.profiles where id = :'ana_id'),
  'Ana',
  'signup trigger creates the profile with display_name from user metadata'
);
select ok(
  exists (select 1 from public.profiles where id = :'beto_id' and display_name is null),
  'signup trigger creates a profile even without display_name metadata'
);
select hasnt_column('public', 'profiles', 'trial_ends_at', 'profiles has no in-app trial column (the trial lives in Whop)');

-- RLS: own row only -----------------------------------------------------------
select tests.authenticate_as(:'ana_id');

select results_eq(
  $$ select id from public.profiles $$,
  format($$ values (%L::uuid) $$, :'ana_id'),
  'a user only sees their own profile'
);

select lives_ok(
  $$ update public.profiles set display_name = 'Ana María' where id = auth.uid() $$,
  'a user can update their own display_name'
);

update public.profiles set display_name = 'hacked' where id = :'beto_id';

select throws_ok(
  $$ update public.profiles set created_at = now() - interval '10 years' where id = auth.uid() $$,
  '42501',
  null,
  'a user can only update display_name (column privileges)'
);

select throws_ok(
  format($$ insert into public.profiles (id, display_name) values (%L, 'fake') $$, gen_random_uuid()),
  '42501',
  null,
  'a user cannot insert profiles'
);

select throws_ok(
  $$ delete from public.profiles where id = auth.uid() $$,
  '42501',
  null,
  'a user cannot delete profiles'
);

select tests.clear_authentication();

select is(
  (select display_name from public.profiles where id = :'ana_id'),
  'Ana María',
  'the own display_name update was persisted'
);
select is(
  (select display_name from public.profiles where id = :'beto_id'),
  null,
  'a user cannot update another user''s profile'
);
select is(
  (select created_at from public.profiles where id = :'ana_id'),
  now(),
  'created_at is unchanged after the rejected update'
);

-- updated_at is maintained by trigger -----------------------------------------
select ok(
  (select updated_at >= created_at from public.profiles where id = :'ana_id'),
  'updated_at is set'
);

-- anon has no access ------------------------------------------------------------
select tests.authenticate_as_anon();
select throws_ok(
  $$ select * from public.profiles $$,
  '42501',
  null,
  'anon cannot read profiles'
);
select tests.clear_authentication();

-- Deleting the auth user removes the profile --------------------------------------
delete from auth.users where id = :'beto_id';
select is(
  (select count(*)::int from public.profiles where id = :'beto_id'),
  0,
  'profile is deleted when the auth user is deleted'
);

select is(
  (select count(*)::int from public.profiles where id = :'ana_id'),
  1,
  'exactly one profile per user'
);

select * from finish();
rollback;
