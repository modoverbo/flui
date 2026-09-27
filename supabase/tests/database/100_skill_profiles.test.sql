-- skill_profiles: one row per closed diagnosis session. The before-insert
-- trigger sets kind (baseline if no prior row, retake otherwise) from the
-- server clock, ignoring whatever the client sends, and rejects a retake
-- less than 30 days after the previous one.
begin;
select plan(15);

select has_table('public', 'skill_profiles', 'skill_profiles table exists');
select is_empty(
  $$ select c.relname from pg_class c
     where c.oid = 'public.skill_profiles'::regclass and not c.relrowsecurity $$,
  'RLS is enabled on skill_profiles'
);
select has_index('public', 'skill_profiles', 'skill_profiles_user_diagnosed_idx', 'user_id, diagnosed_at index exists');

select tests.create_user('profile-owner@example.com') as owner_id \gset
select tests.create_user('profile-other@example.com') as other_id \gset
select tests.create_user('profile-area@example.com') as area_user_id \gset
select tests.create_user('profile-strengths@example.com') as strengths_user_id \gset

-- anon: no access at all -------------------------------------------------------------
select tests.authenticate_as_anon();
select throws_ok($$ select * from public.skill_profiles $$, '42501', null, 'anon cannot read skill_profiles');
select throws_ok(
  $$ insert into public.skill_profiles (id, user_id, kind, top_area, second_area, top_behavior, second_behavior, strengths)
     values (gen_random_uuid(), gen_random_uuid(), 'baseline', 'thinking', 'language', 'main_point_late', 'vague_word', '["clear_main_point"]'::jsonb) $$,
  '42501', null, 'anon cannot insert skill_profiles');
select tests.clear_authentication();

-- owner: first diagnosis always closes as baseline, ignoring the client's kind ------
select tests.authenticate_as(:'owner_id');
select lives_ok(
  format($$ insert into public.skill_profiles (id, user_id, kind, top_area, second_area, top_behavior, second_behavior, strengths)
            values ('00000000-0000-4000-c000-000000000001', %L, 'retake', 'thinking', 'language',
                    'main_point_late', 'vague_word', '["clear_main_point"]'::jsonb) $$, :'owner_id'),
  'owner closes their first diagnosis'
);
select is(
  (select kind from public.skill_profiles where id = '00000000-0000-4000-c000-000000000001'),
  'baseline',
  'the trigger overrides the client-sent kind to baseline when no prior row exists'
);
select throws_ok(
  format($$ insert into public.skill_profiles (id, user_id, kind, top_area, second_area, top_behavior, second_behavior, strengths)
            values ('00000000-0000-4000-c000-000000000002', %L, 'baseline', 'voice', 'fluency',
                    'pace_fast', 'long_pauses', '["steady_pace"]'::jsonb) $$, :'owner_id'),
  '23514', null, 'a retake less than 30 days after the previous one is rejected'
);
select tests.clear_authentication();

-- 30+ days later, a retake is accepted and the trigger sets kind = retake ------------
update public.skill_profiles set diagnosed_at = now() - interval '31 days'
  where id = '00000000-0000-4000-c000-000000000001';

select tests.authenticate_as(:'owner_id');
select lives_ok(
  format($$ insert into public.skill_profiles (id, user_id, kind, top_area, second_area, top_behavior, second_behavior, strengths)
            values ('00000000-0000-4000-c000-000000000003', %L, 'baseline', 'voice', 'fluency',
                    'pace_fast', 'long_pauses', '["steady_pace"]'::jsonb) $$, :'owner_id'),
  'owner closes a retake 31 days after the baseline'
);
select is(
  (select kind from public.skill_profiles where id = '00000000-0000-4000-c000-000000000003'),
  'retake',
  'the trigger sets kind = retake once 30 days have passed'
);

-- clients cannot update or delete skill_profiles -------------------------------------
select throws_ok(
  $$ update public.skill_profiles set top_area = 'voice' where id = '00000000-0000-4000-c000-000000000003' $$,
  '42501', null, 'clients cannot update skill_profiles'
);
select throws_ok(
  $$ delete from public.skill_profiles where id = '00000000-0000-4000-c000-000000000003' $$,
  '42501', null, 'clients cannot delete skill_profiles'
);
select tests.clear_authentication();

-- another user sees none of the owner's profiles -------------------------------------
select tests.authenticate_as(:'other_id');
select is(
  (select count(*)::int from public.skill_profiles where user_id = :'owner_id'::uuid),
  0,
  'another signed-in user cannot see the owner''s profiles'
);
select tests.clear_authentication();

-- Structural checks (fresh users, first diagnosis, isolated from the 30-day rule) ----
select tests.authenticate_as(:'area_user_id');
select throws_ok(
  format($$ insert into public.skill_profiles (id, user_id, kind, top_area, second_area, top_behavior, second_behavior, strengths)
            values (gen_random_uuid(), %L, 'baseline', 'thinking', 'thinking',
                    'main_point_late', 'vague_word', '["clear_main_point"]'::jsonb) $$, :'area_user_id'),
  '23514', null, 'top_area and second_area must differ'
);
select tests.clear_authentication();

select tests.authenticate_as(:'strengths_user_id');
select throws_ok(
  format($$ insert into public.skill_profiles (id, user_id, kind, top_area, second_area, top_behavior, second_behavior, strengths)
            values (gen_random_uuid(), %L, 'baseline', 'thinking', 'language',
                    'main_point_late', 'vague_word', '[]'::jsonb) $$, :'strengths_user_id'),
  '23514', null, 'strengths must have at least one entry'
);
select tests.clear_authentication();

select * from finish();
rollback;
