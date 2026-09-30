# ADR 0006: flui as a daily oral-expression gym — the speaking training engine

- **Status:** Accepted
- **Date:** 2026-09-29
- **Evidence:** research/mvp-frontend-only.md (voice pipeline options), Groq Whisper/LLM docs,
  `just_audio` platform support matrix (verified by spike, U3), Whop's live OpenAPI spec (reused from
  ADR-0004), decisions #420/#422/#429/#430/#434/#448/#450 (see `sdd/flui-eloquence-gym-refactor`
  proposal/design artifacts)

## Context

flui repositioned from a vocabulary flashcard app to a **daily oral-expression gym**: every learning
surface now ends in the user speaking, not typing. This required a new recording/analysis pipeline
(`SpeechRecorder`/`SpeechPlayer`/`speech-analyze`, already shipped before this refactor as the
Habla/speaking-challenge tab), a training-engine domain (diagnosis, daily/lab/word/quick contexts,
progress evidence), and — because "voice-first" only means something if the mic is never more than
one tap away — a single shell-owned mic system replacing every screen-owned record button.

The whole engine was built behind a compile-time flag, `FluiFeatures.speakingGym` (design D17), so
`main` stayed shippable through 44 stacked-to-main work units (U1–U23e) even though `web-deploy.yml`
redeploys production on every push. This ADR is the last unit (U20): it removes the flag, deletes the
flag-off code paths it was protecting, and records the accumulated decisions as one durable record.

## Decision

### Seams (design §1–2)

1. **`core/audio`**: `SpeechRecorder` (PCM16 16 kHz mono → WAV, one path for analysis and storage),
   `SpeechPlayer` (`just_audio`; signed URL for stored audio, web blob / io temp-file for in-memory
   playback), `HoldToRecord` (plain-Dart gesture state machine, no widget owns timers or permission
   state).
2. **`core/mic`**: one shell-owned `MicController` per signed-in session, wrapping the single
   `HoldToRecord`, bound through a layered `MicTargetRegistry` (root layer for full-screen takeovers,
   one stack per shell branch) to whichever screen's `MicTarget` is currently active. Screens never
   own capture logic; they register a `MicTarget` adapter and interpret `MicDelivery`.
3. **`features/speaking`**: `speech-analyze` Edge Function, extended additively — `challengeId`
   (server-resolved prompt, D18), `mode: "analyze" | "transcribe"` (D34), sanitized `observations`.
   Access (`has_access`) and quota (`claim_speech_analysis`) are checked before any provider call, in
   both modes.
4. **`features/training`**: pure-Dart domain shared by diagnosis, HOY, ENTRENAR, PALABRAS and quick
   practice — one `TrainingLoop`/`LoopScript` state machine (D13), `TrainingPlanner`, `Progression`,
   `DiagnosisProfiler`, `DiagnosisResumePolicy`, `MilestonePolicy`, `RetakePolicy`.
5. **`supabase/`**: additive migrations — `challenges`, `speaking_attempts`, `skill_profiles`,
   `daily_sessions` plan columns, a consent column, the `speaking-audio` bucket, the daily analysis
   quota table.

### Key decisions (condensed; full rationale in the retired design artifacts)

| # | Decision |
|---|----------|
| D1–D4 | `core/audio` ports (`SpeechRecorder`/`SpeechPlayer`), plain-Dart `HoldToRecord`, one PCM16 WAV capture path, `just_audio` for playback (web blob / io temp file, spike-verified). |
| D5–D6 | `has_access` checked before body parsing, fail closed (403/503); an atomic `claim_speech_analysis` RPC bounds spend at 60/day (env-configurable), 429 `daily_limit_reached`, in both `analyze` and `transcribe` modes. |
| D7–D9, D21–D22 | Milestone audio (baseline + weekly, consent-gated) retained 90 days by a daily server-side sweep; consent lives on `profiles`; account deletion cancels the Whop membership (fail closed, ADR-0004 decision 9), then storage, then the auth user. |
| D10–D11 | Published challenges are readable without an access gate (content is not the cost); `features/training` owns the closed `BehaviorCode` catalog, `features/speaking` never reads it back. |
| D12–D16 | Voice metrics computed on the client, never sent to the LLM as numbers; one `TrainingLoop` state machine driven by `LoopScript` data (not a class per consumer); `SessionPlanner` is composed, never rewritten; spoken word-use detected client-side via `WordForms.appearsIn`, no server target-word field; a pure `DiagnosisGate` in the router redirect. |
| D18–D20 | The server resolves the prompt from `challengeId` (no prompt injection from the client); fake challenges are generated from `seed.sql` (single source); an attempt is inserted after each successful analysis (partial loops survive a Whop-checkout detour). |
| D23–D33 | One shell-scoped `MicController`; a layered registry with last-registered-wins and token disposal; `deliver()` returns a `MicDelivery`, latched outcomes; a gesture recognizer starts on pointer-down, a hold under 300 ms latches to a tap-toggle; the mic fallback is an explained target, then prompt-first quick practice (D40, superseding an immediate-capture default); capture is cancelled on navigation/lifecycle change, never on an in-flight delivery; a custom `FluiBottomBar` with a raised center mic (Material 3's `NavigationBar` cannot host a raised action); loop routes live inside shell branches, root-navigator screens (diagnosis, `/session`) use a `MicDock`; precedence is busy > access > quota > permission > target; the whole mic system stayed behind `speakingGym` until this unit; `context='quick'` never counts toward milestones or the 7-day exclusion. |
| D34–D45 | Word exercises transcribe-only (`mode=transcribe`, 1 quota unit, no LLM); form-recall matches a spoken transcript via a window scan + a Spanish sound-alike key (b/v, ll/y, silent h, c/z/s), production reuses its existing text validator unchanged; `/session` stays on the root navigator with `MicDock`, the typed path removed in this unit; word-exercise answers are never persisted as `speaking_attempts` rows; diagnosis progress/resume is derived from existing `speaking_attempts` rows, no new column; "Continuar después" pauses diagnosis back to its intro, disabled mid-capture; quick practice shows its prompt before ever recording; HOY shows duration chips and a provisional plan when no session exists yet, persisted through one shared `PlanToday` use case; captures auto-stop at `min(1.5× target, 60 s)`; every cancellation notice has distinct copy; hold is pointer-only, keyboard/switch-access/screen-reader activation always uses the tap-toggle path; `HoldToRecord` collects levels through exactly one amplitude subscription (D45).

### This unit (U20): the flip

- Deleted `FluiFeatures.speakingGym` and `speakingGymEnabledProvider`, and every flag-off branch they
  gated. The paired flag-off/gym structures collapse into the single gym version: the shell's
  `ShellDestination` enum, its branches, and `AppRoutes.retiredRoutes` (the old `/speaking/challenge`
  deep links now redirect into `/train` unconditionally, the way `gymRetiredRoutes` used to only while
  the flag was on).
- Deleted the dead legacy surfaces the flag was keeping alive: `speaking_challenge_page.dart` and
  `speaker_cue_cards.dart` (superseded by ENTRENAR, U16), the typed `/session` `FluiTextField` views
  (superseded by the mic-driven `FormRecallMicTarget`/`ProductionMicTarget`, U17b), `OnboardingAnswers`
  and its two retired preference questions (superseded by the spoken diagnosis, U14b) along with the
  `ThemeRecommender` scoring they fed (now catalog order — a personalization signal with nothing left
  to read is not a personalization signal).
- `DailySessionDto`'s training-plan columns (`focus_area`, `challenge_id`, `woven_word_ids`) are now
  always selected and written; the flag-gated column-stripping in `SupabaseDailySessionRepository`
  (kept because production migrations are applied manually and PostgREST rejects unknown columns) is
  gone now that the U7 migration is a merge precondition, not a maybe.
- `app/lib/core/config/feature_flags.dart` had no `FLUI_SPEAKING_GYM` dart-define anywhere in
  `app/config/*.json` or `web-deploy.yml` — the flag was a bare compile-time constant defaulting
  `false`, never wired to a build-time override. "Flipping" it is exactly this unit's deletion, not a
  config edit.

### Retention and orphan sweep (U21)

A daily Actions cron (`audio-retention.yml`) runs an Edge Function that deletes `speaking-audio`
objects whose `speaking_attempts` row is missing or not `audio_status='stored'` with that exact path,
after a 24-hour grace period — never an object a `stored` row still references. Three independent
layers close a confused-deputy gap (a client backdating `created_at` or another user's canonical
path): a server-clock trigger on `speaking_attempts`, a DB-side canonical-path filter on the
candidate selection, and the function's own ownership re-check immediately before every delete.

### Account deletion (U22)

Reuses ADR-0004 decision 9's fail-closed order (cancel the Whop membership → remove
`speaking-audio/<uid>/*` → delete the auth user) — see that ADR for the Whop contract, and this one's
D21/D22 for why milestone audio retention and account deletion share one storage-cleanup shape. A
pgTAP suite (U22c) proves the cascade reaches every user-owned table, including the training-engine
ones this ADR adds.

## Consequences

- **Storage growth**: every milestone attempt is a WAV file (~1 MB); the 90-day sweep and per-user
  bucket size limit (2 MiB/object) bound it, but it is now a real, monitored cost, not zero.
- **Three-way parity**: the `BehaviorCode` catalog must stay identical across `content/`,
  `speech-analyze/behavior_codes.json` and the app — a parity test guards it, but it is a real
  coordination surface a single-source enum would not have.
- **Blob playback is web-specific**: the io fallback (`path_provider` temp file) is a second code path
  with its own failure mode; both are spike-verified but neither has run against every browser/OS
  combination in production yet.
- **One RPC per analysis**: `speech-analyze` is now on the hot path for daily sessions, word exercises
  and diagnosis. Quota and access checks run before every paid call, but a Groq outage now degrades a
  much larger surface of the app than it used to (previously only Habla).
- **A single shell-owned recorder and a single shell-owned mic controller**: every consumer surface is
  a thin adapter; a bug in `MicController` now affects every speaking surface at once, not one screen.
- **Spoken exercises spend quota**: vocabulary review, previously free, now claims a daily-analysis
  unit per spoken answer (transcribe-only, so cheaper than a full analysis, but not zero).

## Rejected alternatives

| Option | Why not |
|--------|---------|
| Per-screen `HoldToRecord`/recorder ownership | Racing recorders across screens; superseded by one shell-owned `MicController` (D23). |
| A second, separate `speech-transcribe` function for word exercises | Duplicated access/quota gating logic; `mode=transcribe` on the existing function reuses one gate (D34). |
| On-device STT (Web Speech API) for word exercises | No Firefox support; a second capture path breaks the single-recorder invariant (D23). |
| Server-side comparison of the spoken answer against the expected word | Leaks the expected answer to the client via prompt biasing or requires a new contract; client-side matching is deterministic and free (D35). |
| Keep the two retired onboarding preference questions alongside the diagnosis | Redundant personalization signal once a real diagnosis exists; the questions and their theme-recommender scoring are now fully dead code once nothing ever answers them. |
| A full-screen loop with its own record button per training context (daily/lab/word/quick) | Reintroduces the pre-refactor problem (recorder logic duplicated per screen) the mic system exists to remove. |

## Follow-ups

- `micControllerProvider`'s `keepAlive` lifetime was never load-tested for a long-running tab left
  open across multiple sign-in/sign-out cycles; watch for a `HoldToRecord`/platform-recorder leak.
- `MicNoticeHost` has not been exercised on a real diagnosis-failure device path (only the fake
  recorder in tests) — revisit once the manual device checks below are done.
- Manual device checks not yet run (tracked as pre-merge items, not blocking this ADR): U23a.8/9
  (tap-vs-hold and first-use permission prompt, Chrome + Android), U23c.8 (bottom-bar parity on a
  device).
- Manual sandbox checks not yet run: U22a.4 (Whop cancel against the sandbox), U22b.4
  (`account-delete` end-to-end against the sandbox).
- `ProgressEvidence`'s "before vs. now" comparison threshold (2 attempts) was a starting number, not a
  measured one; revisit once real usage data exists.
- Opus/webm compression for stored audio, and generalizing the 90-day retention sweep to other
  audio-bearing tables if any are added, remain open.
- Analytics on the speaking funnel (diagnosis completion, quick-practice adoption, milestone playback
  rate) do not exist yet.
- On-device STT was rejected for word exercises (see above) but may be worth revisiting if Groq
  latency or cost becomes a problem for that specific path.
