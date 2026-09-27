-- challenges: published training/diagnosis content, readable without an access
-- gate (D10 -- content itself is not the paid cost, unlike words); never
-- writable by clients. Also covers the additive daily_sessions plan columns
-- (focus_area, challenge_id, woven_word_ids).
begin;
select plan(22);

-- Structure -----------------------------------------------------------------------
select has_table('public', 'challenges', 'challenges table exists');
select is_empty(
  $$ select c.relname from pg_class c
     where c.oid = 'public.challenges'::regclass and not c.relrowsecurity $$,
  'RLS is enabled on challenges'
);
select has_column('public', 'daily_sessions', 'focus_area', 'daily_sessions.focus_area exists');
select has_column('public', 'daily_sessions', 'challenge_id', 'daily_sessions.challenge_id exists');
select has_column('public', 'daily_sessions', 'woven_word_ids', 'daily_sessions.woven_word_ids exists');

-- Fixtures (created as postgres, bypasses RLS) --------------------------------------
insert into public.challenges (id, slug, purpose, diagnosis_slot, skill, mode, difficulty, prompt, focus, transfer_prompts, sort_order, published)
values
  ('00000000-0000-4000-a000-000000000001', 'test-diagnostico-1', 'diagnosis', 1, 'thinking', null, 1,
   'Preséntate en pocas frases, sin prisa.', 'Estructura clara al hablar de ti mismo.', '{}', 9001, true),
  ('00000000-0000-4000-a000-000000000002', 'test-entrenamiento-1', 'training', null, 'language', 'speak_with_precision', 1,
   'Describe tu lugar favorito con palabras precisas.', 'Vocabulario preciso y variado.',
   array['Describe ahora un objeto cotidiano con la misma precisión.'], 9002, true),
  ('00000000-0000-4000-a000-000000000003', 'test-sin-publicar', 'training', null, 'voice', 'master_your_voice', 1,
   'Cuenta una anécdota breve controlando el volumen.', 'Volumen estable durante toda la respuesta.',
   array['Repite el mismo relato bajando el ritmo.'], 9003, false);

select tests.create_user('no-entitlement@example.com') as no_entitlement_id \gset

-- anon: no access at all -------------------------------------------------------------
select tests.authenticate_as_anon();
select throws_ok($$ select * from public.challenges $$, '42501', null, 'anon cannot read challenges');
select tests.clear_authentication();

-- signed-in without entitlement: published readable, no access gate (D10) -----------
select tests.authenticate_as(:'no_entitlement_id');
select set_eq(
  $$ select slug from public.challenges where slug like 'test-%' $$,
  array['test-diagnostico-1', 'test-entrenamiento-1'],
  'a signed-in user without entitlement reads published challenges, unpublished excluded'
);

-- Clients cannot write challenges ----------------------------------------------------
select throws_ok(
  $$ insert into public.challenges (slug, purpose, diagnosis_slot, skill, difficulty, prompt, focus, sort_order)
     values ('x', 'diagnosis', 1, 'thinking', 1, '0123456789', '01234', 1) $$,
  '42501', null, 'clients cannot insert challenges');
select throws_ok($$ update public.challenges set published = true where slug = 'test-sin-publicar' $$,
  '42501', null, 'clients cannot update challenges');
select throws_ok($$ delete from public.challenges $$, '42501', null, 'clients cannot delete challenges');
select tests.clear_authentication();

-- Structural checks (as postgres, bypasses RLS) --------------------------------------
select throws_ok(
  $$ insert into public.challenges (slug, purpose, diagnosis_slot, skill, difficulty, prompt, focus, transfer_prompts, sort_order)
     values ('test-slot-null', 'diagnosis', null, 'thinking', 1, '0123456789', '01234', '{}', 2) $$,
  '23514', null, 'a diagnosis challenge requires diagnosis_slot');
select throws_ok(
  $$ insert into public.challenges (slug, purpose, skill, difficulty, prompt, focus, transfer_prompts, sort_order)
     values ('test-mode-null', 'training', 'thinking', 1, '0123456789', '01234', array['x'], 3) $$,
  '23514', null, 'a training challenge requires mode');
select throws_ok(
  $$ insert into public.challenges (slug, purpose, diagnosis_slot, skill, mode, difficulty, prompt, focus, sort_order)
     values ('test-mode-set', 'diagnosis', 1, 'thinking', 'think_and_speak', 1, '0123456789', '01234', 4) $$,
  '23514', null, 'a diagnosis challenge cannot set mode');
select throws_ok(
  $$ insert into public.challenges (slug, purpose, skill, mode, difficulty, prompt, focus, transfer_prompts, sort_order)
     values ('test-no-transfer', 'training', 'thinking', 'think_and_speak', 1, '0123456789', '01234', '{}', 5) $$,
  '23514', null, 'a training challenge requires at least one transfer prompt');
select throws_ok(
  $$ insert into public.challenges (slug, purpose, diagnosis_slot, skill, difficulty, prompt, focus, sort_order)
     values ('Bad_Slug', 'diagnosis', 1, 'thinking', 1, '0123456789', '01234', 6) $$,
  '23514', null, 'slug must be kebab-case');
select throws_ok(
  $$ insert into public.challenges (slug, purpose, diagnosis_slot, skill, difficulty, prompt, focus, sort_order)
     values ('test-difficulty', 'diagnosis', 1, 'thinking', 4, '0123456789', '01234', 7) $$,
  '23514', null, 'difficulty must be between 1 and 3');
select throws_ok(
  $$ insert into public.challenges (slug, purpose, diagnosis_slot, skill, difficulty, prompt, focus, sort_order, target_seconds)
     values ('test-target-seconds', 'diagnosis', 1, 'thinking', 1, '0123456789', '01234', 8, 5) $$,
  '23514', null, 'target_seconds must be between 15 and 60');
select throws_ok(
  $$ insert into public.challenges (slug, purpose, skill, mode, difficulty, prompt, focus, transfer_prompts, sort_order)
     values ('test-too-many-transfers', 'training', 'thinking', 'think_and_speak', 1, '0123456789', '01234',
             array['a', 'b', 'c', 'd'], 9) $$,
  '23514', null, 'transfer_prompts holds at most 3 entries');

-- daily_sessions.challenge_id FK behavior (as postgres, bypasses RLS) -----------------
select lives_ok(
  format($$ insert into public.daily_sessions (user_id, local_date, minutes, challenge_id)
            values (%L, current_date, 10, '00000000-0000-4000-a000-000000000002') $$, :'no_entitlement_id'),
  'daily_sessions accepts a challenge_id'
);
select throws_ok(
  format($$ insert into public.daily_sessions (user_id, local_date, minutes, focus_area)
            values (%L, current_date + 1, 10, 'invalid_area') $$, :'no_entitlement_id'),
  '23514', null, 'daily_sessions.focus_area rejects an unknown area');
select is(
  (select challenge_id from public.daily_sessions where user_id = :'no_entitlement_id'::uuid and local_date = current_date),
  '00000000-0000-4000-a000-000000000002'::uuid,
  'daily_sessions kept the challenge_id before deletion'
);
delete from public.challenges where id = '00000000-0000-4000-a000-000000000002';
select is(
  (select challenge_id from public.daily_sessions where user_id = :'no_entitlement_id'::uuid and local_date = current_date),
  null::uuid,
  'deleting a challenge sets daily_sessions.challenge_id to null (on delete set null)'
);

select * from finish();
rollback;
