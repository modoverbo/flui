-- speaking-audio storage: private bucket for milestone/diagnosis attempts.
-- Select/insert/delete restricted to the caller's own `<uid>/` folder;
-- insert additionally requires a matching pending speaking_attempts row
-- (diagnosis or a milestone week) AND profiles.audio_retention_consent =
-- true. No update policy exists at all. Also covers the consent columns
-- added to profiles.
begin;
select plan(22);

select is(
  (select count(*)::int from storage.buckets where id = 'speaking-audio'),
  1,
  'the speaking-audio bucket exists'
);
select has_column('public', 'profiles', 'audio_retention_consent', 'profiles.audio_retention_consent exists');
select has_column('public', 'profiles', 'audio_consent_updated_at', 'profiles.audio_consent_updated_at exists');

select tests.create_user('audio-owner@example.com') as owner_id \gset
select tests.create_user('audio-other@example.com') as other_id \gset

-- anon cannot write into the bucket at all -------------------------------------------
select tests.authenticate_as_anon();
select throws_ok(
  format($$ insert into storage.objects (bucket_id, name) values ('speaking-audio', %L || '/x.wav') $$, :'owner_id'),
  '42501', null, 'anon cannot insert into speaking-audio'
);
select tests.clear_authentication();

select tests.authenticate_as(:'owner_id');

-- fixture: a pending diagnosis attempt, eligible for storage ------------------------
select lives_ok(
  format($$ insert into public.speaking_attempts
              (id, user_id, session_id, context, kind, local_date, transcript, duration_ms, audio_status)
            values ('00000000-0000-4000-d000-000000000001', %L, gen_random_uuid(), 'diagnosis', 'first', current_date,
                    'Preséntate en pocas frases, sin prisa.', 15000, 'pending') $$, :'owner_id'),
  'owner records a pending diagnosis attempt'
);

-- insert blocked before consent is granted -------------------------------------------
select throws_ok(
  format($$ insert into storage.objects (bucket_id, name)
            values ('speaking-audio', %L || '/00000000-0000-4000-d000-000000000001.wav') $$, :'owner_id'),
  '42501', null, 'upload is rejected before audio_retention_consent is granted'
);

-- consent grant sets audio_consent_updated_at ----------------------------------------
select lives_ok(
  $$ update public.profiles set audio_retention_consent = true where id = (select auth.uid()) $$,
  'owner grants audio retention consent'
);
select isnt(
  (select audio_consent_updated_at from public.profiles where id = :'owner_id'::uuid),
  null,
  'audio_consent_updated_at is set once consent changes'
);

-- insert blocked into another user's folder ------------------------------------------
select throws_ok(
  format($$ insert into storage.objects (bucket_id, name)
            values ('speaking-audio', %L || '/00000000-0000-4000-d000-000000000001.wav') $$, :'other_id'),
  '42501', null, 'upload is rejected into another user''s folder'
);

-- insert blocked when the attempt is not pending / not milestone-or-diagnosis -------
select lives_ok(
  format($$ insert into public.speaking_attempts
              (id, user_id, session_id, context, kind, local_date, transcript, duration_ms, audio_status)
            values ('00000000-0000-4000-d000-000000000002', %L, gen_random_uuid(), 'lab', 'repeat', current_date,
                    'Repetí el mismo argumento con más precisión.', 12000, 'none') $$, :'owner_id'),
  'owner records a non-eligible attempt'
);
select throws_ok(
  format($$ insert into storage.objects (bucket_id, name)
            values ('speaking-audio', %L || '/00000000-0000-4000-d000-000000000002.wav') $$, :'owner_id'),
  '42501', null, 'upload is rejected for a non-pending, non-milestone, non-diagnosis attempt'
);

-- successful upload: diagnosis branch -------------------------------------------------
select lives_ok(
  format($$ insert into storage.objects (bucket_id, name)
            values ('speaking-audio', %L || '/00000000-0000-4000-d000-000000000001.wav') $$, :'owner_id'),
  'owner uploads audio for their own pending diagnosis attempt'
);

-- successful upload: weekly milestone branch (not diagnosis) -------------------------
select lives_ok(
  format($$ insert into public.speaking_attempts
              (id, user_id, session_id, context, kind, local_date, transcript, duration_ms, audio_status, milestone_week)
            values ('00000000-0000-4000-d000-000000000003', %L, gen_random_uuid(), 'daily', 'first', current_date,
                    'Hoy hablé sobre mi rutina matutina con calma.', 15000, 'pending', date_trunc('week', current_date)::date) $$,
         :'owner_id'),
  'owner records a pending weekly-milestone attempt'
);
select lives_ok(
  format($$ insert into storage.objects (bucket_id, name)
            values ('speaking-audio', %L || '/00000000-0000-4000-d000-000000000003.wav') $$, :'owner_id'),
  'owner uploads audio for their own pending milestone attempt'
);

select is(
  (select count(*)::int from storage.objects where bucket_id = 'speaking-audio' and (storage.foldername(name))[1] = :'owner_id'),
  2,
  'exactly the 2 successful uploads are stored in the owner''s folder'
);
select tests.clear_authentication();

-- another signed-in user cannot see or delete the owner's audio ----------------------
-- (storage.objects also guards direct SQL deletes behind
-- storage.allow_delete_query; set for this session so the RLS delete
-- policies themselves are what gets exercised below)
set local storage.allow_delete_query = 'true';

select tests.authenticate_as(:'other_id');
select is(
  (select count(*)::int from storage.objects where bucket_id = 'speaking-audio'),
  0,
  'another signed-in user sees no rows in the owner''s speaking-audio folder'
);
select lives_ok(
  format($$ delete from storage.objects where bucket_id = 'speaking-audio' and name = %L || '/00000000-0000-4000-d000-000000000001.wav' $$, :'owner_id'),
  'another user''s delete on the owner''s object completes without error'
);
select tests.clear_authentication();

select tests.authenticate_as(:'owner_id');
select is(
  (select count(*)::int from storage.objects where bucket_id = 'speaking-audio' and name = :'owner_id' || '/00000000-0000-4000-d000-000000000001.wav'),
  1,
  'the owner''s object survives another user''s delete attempt (RLS silently filtered it out)'
);

-- there is no update policy on the bucket at all: an update matches no rows ----------
select lives_ok(
  format($$ update storage.objects set metadata = '{"note": "x"}'::jsonb
            where bucket_id = 'speaking-audio' and name = %L || '/00000000-0000-4000-d000-000000000001.wav' $$, :'owner_id'),
  'the owner''s update statement itself does not error'
);
select is(
  (select metadata from storage.objects where bucket_id = 'speaking-audio' and name = :'owner_id' || '/00000000-0000-4000-d000-000000000001.wav'),
  null::jsonb,
  'no client, not even the owner, can update a speaking-audio object (no update policy matches any row)'
);

-- the owner can delete their own object ----------------------------------------------
select lives_ok(
  format($$ delete from storage.objects where bucket_id = 'speaking-audio' and name = %L || '/00000000-0000-4000-d000-000000000001.wav' $$, :'owner_id'),
  'owner deletes their own object'
);
select is(
  (select count(*)::int from storage.objects where bucket_id = 'speaking-audio' and name = :'owner_id' || '/00000000-0000-4000-d000-000000000001.wav'),
  0,
  'the object is gone after the owner deletes it'
);

select * from finish();
rollback;
