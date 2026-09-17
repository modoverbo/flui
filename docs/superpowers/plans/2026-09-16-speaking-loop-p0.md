# Flui Speaking Loop P0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a visible, testable two-attempt oral training loop and a compile-time local developer mode that opens the app without manual authentication.

**Architecture:** Add an isolated `features/speaking` vertical slice with deterministic domain analysis, recorder and analysis repository contracts, fake and Supabase-backed adapters, Riverpod orchestration, and a full-screen route launched from Hoy. Developer access is a compile-time configuration input that seeds only the fake backend with a user, entitlement, and daily plan; production routing remains unchanged.

**Tech Stack:** Flutter 3.47, Dart 3.13, Riverpod, GoRouter, `record`, Supabase Edge Functions, Groq Whisper API, Deno tests.

**Spec:** `docs/superpowers/specs/2026-09-16-speaking-loop-p0-design.md`

## Global Constraints

- Audio is transient and is never persisted in P0.
- Transcripts are used transiently for analysis and are never persisted.
- Feedback contains at most three observable signals and one concrete retry action.
- The first challenge is fixed at 45 seconds and supports exactly two attempts.
- Measurements without enough evidence are omitted or labeled as estimates.
- Production authentication, entitlement, and daily-budget guards remain active.
- Developer bypass is compile-time, explicit, and accepted only with `BACKEND=fake`.
- Web and mobile-size layouts must remain usable and accessible.

---

### Task 1: Safe local developer access

**Files:**
- Modify: `app/lib/core/config/app_config.dart`
- Modify: `app/lib/bootstrap.dart`
- Modify: `app/config/fake.json`
- Test: `app/test/core/config/app_config_test.dart`
- Test: `app/test/app/app_flow_test.dart`

**Interfaces:**
- Produces: `AppConfig.devBypassAuth`, parsed from `DEV_BYPASS_AUTH`.
- Produces: fake backend initial user, access grant, and daily session only when the flag is true.

- [ ] Add parsing tests proving the flag defaults to false, accepts true for fake, and is rejected for Supabase.
- [ ] Run the focused configuration tests and confirm they fail because the field does not exist.
- [ ] Add `devBypassAuth` to `AppConfig`, validate it, and enable it in `config/fake.json`.
- [ ] Add an app-flow test proving the fake dev configuration lands inside the app without displaying login.
- [ ] Seed the fake repositories with `dev@flui.local`, granted access, and today’s plan when enabled.
- [ ] Run both focused test files and commit the task.

### Task 2: Deterministic speaking analysis domain

**Files:**
- Create: `app/lib/features/speaking/domain/speech_segment.dart`
- Create: `app/lib/features/speaking/domain/speech_transcript.dart`
- Create: `app/lib/features/speaking/domain/speaking_metrics.dart`
- Create: `app/lib/features/speaking/domain/speaking_feedback.dart`
- Create: `app/lib/features/speaking/domain/speech_analyzer.dart`
- Test: `app/test/features/speaking/domain/speech_analyzer_test.dart`

**Interfaces:**
- Consumes: transcript text, word timestamps, and duration.
- Produces: `SpeakingMetrics SpeechAnalyzer.analyze(SpeechTranscript transcript)`.
- Produces: `SpeakingFeedback SpeechAnalyzer.feedback(SpeakingMetrics metrics)` with no more than three signals.

- [ ] Write failing tests for WPM minimum evidence, timestamp pauses, long pauses, pace thirds, Spanish filler phrases, repetition, and insufficient confidence.
- [ ] Run the focused test and confirm failures come from missing domain types.
- [ ] Implement immutable domain models and the smallest deterministic analyzer that satisfies each threshold in the spec.
- [ ] Add failing tests for feedback priority and the single retry instruction.
- [ ] Implement feedback selection and rerun all domain tests.
- [ ] Commit the task.

### Task 3: Audio capture and analysis repository boundary

**Files:**
- Modify: `app/pubspec.yaml`
- Create: `app/lib/features/speaking/domain/speech_analysis_repository.dart`
- Create: `app/lib/features/speaking/domain/speech_recorder.dart`
- Create: `app/lib/features/speaking/data/record_speech_recorder.dart`
- Create: `app/lib/features/speaking/data/fake_speech_analysis_repository.dart`
- Create: `app/lib/features/speaking/data/supabase_speech_analysis_repository.dart`
- Create: `app/lib/features/speaking/presentation/providers/speaking_providers.dart`
- Test: `app/test/features/speaking/data/fake_speech_analysis_repository_test.dart`

**Interfaces:**
- Produces: `SpeechRecorder.start()`, `SpeechRecorder.stop()`, `SpeechRecorder.cancel()` and amplitude stream.
- Produces: `SpeechAnalysisRepository.analyze(Uint8List audio, {required String mimeType, required Duration duration})`.
- Fake adapter returns deterministic transcripts for local visual validation.
- Supabase adapter invokes `speech-analyze` and maps typed failures.

- [ ] Add the `record` dependency and write the fake repository test first.
- [ ] Run the test and confirm it fails because the interfaces are absent.
- [ ] Implement contracts, the deterministic fake adapter, and Riverpod providers.
- [ ] Implement the `record` adapter with permission, WAV recording, amplitude, stop, and cancellation.
- [ ] Implement the Supabase adapter without persisting audio or transcripts.
- [ ] Run focused data tests and compile analysis; commit the task.

### Task 4: Speaking session state machine

**Files:**
- Create: `app/lib/features/speaking/presentation/controllers/speaking_session_state.dart`
- Create: `app/lib/features/speaking/presentation/controllers/speaking_session_controller.dart`
- Test: `app/test/features/speaking/presentation/speaking_session_controller_test.dart`

**Interfaces:**
- Consumes: `SpeechRecorder`, `SpeechAnalysisRepository`, and `SpeechAnalyzer`.
- Produces: idle, requesting permission, recording, analyzing, first feedback, retry recording, comparison, and typed recovery states.

- [ ] Write failing controller tests for the happy path, 45-second auto-stop, permission denial, no speech, network timeout, retry, and cancel.
- [ ] Run the controller tests and confirm the missing implementation failures.
- [ ] Implement the minimal state machine with injectable timer behavior.
- [ ] Ensure failed analysis retains retry capability but never stores audio after completion or cancellation.
- [ ] Run focused tests and commit the task.

### Task 5: Full-screen microphone-first UI

**Files:**
- Create: `app/lib/features/speaking/presentation/speaking_challenge_page.dart`
- Create: `app/lib/features/speaking/presentation/widgets/speaking_prompt_card.dart`
- Create: `app/lib/features/speaking/presentation/widgets/record_button.dart`
- Create: `app/lib/features/speaking/presentation/widgets/speaking_feedback_view.dart`
- Create: `app/lib/features/speaking/presentation/widgets/attempt_comparison_view.dart`
- Test: `app/test/features/speaking/presentation/speaking_challenge_page_test.dart`

**Interfaces:**
- Consumes: `speakingSessionControllerProvider`.
- Produces: accessible 45-second challenge with permission disclosure, countdown, amplitude feedback, analysis progress, up to three signals, retry CTA, and attempt comparison.

- [ ] Write failing widget tests for every visible state and semantics of the recording control.
- [ ] Run the focused widget tests and verify the page is missing.
- [ ] Build the responsive page using existing Flui tokens and shared controls.
- [ ] Add reduced-motion behavior, readable error recovery, and mobile overflow coverage.
- [ ] Run widget and accessibility tests; commit the task.

### Task 6: Route and Hoy integration

**Files:**
- Modify: `app/lib/app/router/app_routes.dart`
- Modify: `app/lib/app/router/app_router.dart`
- Modify: `app/lib/features/daily/presentation/today_page.dart`
- Test: `app/test/app/app_router_test.dart`
- Test: `app/test/features/daily/presentation/today_page_test.dart`

**Interfaces:**
- Produces: `/speaking/challenge` protected by existing production guards.
- Produces: a prominent “Entrena tu voz · 45 s” card on Hoy.

- [ ] Add failing route and Hoy tests.
- [ ] Run them and confirm the missing route and CTA failures.
- [ ] Register the full-screen route and add the primary speaking card without removing vocabulary content.
- [ ] Run the focused tests and commit the task.

### Task 7: Supabase transcription boundary

**Files:**
- Create: `supabase/functions/speech-analyze/handler.ts`
- Create: `supabase/functions/speech-analyze/index.ts`
- Create: `supabase/functions/speech-analyze/handler_test.ts`
- Modify: `supabase/functions/.env.example`

**Interfaces:**
- Consumes: authenticated multipart request containing audio, MIME type, and duration.
- Produces: provider-neutral JSON with transient transcript and word/segment timestamps.

- [ ] Write failing Deno tests for authorization, size/type/duration validation, Groq mapping, timeout, rate-limit, and provider failure.
- [ ] Run focused Deno tests and confirm the handler is missing.
- [ ] Implement dependency-injected handler and CORS using existing shared utilities.
- [ ] Add index wiring and document `GROQ_API_KEY` in the environment example.
- [ ] Run Edge Function tests and commit the task.

### Task 8: End-to-end verification and visible local app

**Files:**
- Modify only files required by failures discovered during verification.

**Interfaces:**
- Produces: running local app at `http://127.0.0.1:3000/today` with dev bypass and fake speaking analysis.

- [ ] Format changed Dart and TypeScript files.
- [ ] Run all Dart tests, Deno tests, and static analysis.
- [ ] Build Flutter web with `config/fake.json`.
- [ ] Start or hot-restart the local web server on port 3000.
- [ ] Verify in the browser: direct Hoy entry, challenge start, visible record state, first feedback, second attempt, comparison, error recovery, and responsive layout.
- [ ] Inspect the final diff for secrets, persisted audio/transcripts, unrelated changes, and production guard regressions.
- [ ] Commit verification fixes and report exact evidence.
