# Flui Speaking Loop P0 Design

## Purpose

Flui's first oral-training vertical slice turns the existing vocabulary-first
product into a communication gym without replacing the learning systems that
already work.

The P0 must let an authenticated user:

1. understand a speaking challenge immediately;
2. record a 45-second response;
3. receive useful feedback in under 10 seconds under normal conditions;
4. repeat the same challenge once;
5. see a direct comparison between both attempts; and
6. complete the exercise with the next recommended action already clear.

This slice validates Flui's core product hypothesis: immediate, specific
feedback followed by a second attempt creates visible improvement and makes
oral practice worth repeating.

## Product principles

- Training takes precedence over explanation.
- The microphone is the primary action.
- Feedback contains at most three signals after an attempt.
- Feedback describes observable events, not personality or clinical traits.
- Every signal answers: what happened, why it matters, and what to try next.
- The user competes against their previous attempt, not against other users.
- A metric is shown only when the input supports it reliably.
- Audio is transient by default and is never retained by the P0.
- Failure to transcribe must not erase the recording before the user can retry.
- Existing vocabulary sessions, subscriptions, authentication, themes, and
  mastery logic remain intact.

## Audit summary

### Existing strengths to preserve

- Flutter web-first application with Android and iOS targets.
- Feature-first Clean Architecture: `presentation -> domain <- data`.
- Riverpod dependency injection with fake and Supabase repository variants.
- GoRouter guards for authentication, entitlement, and daily planning.
- A mature vocabulary engine: spaced review, active recall, production checks,
  interference rules, themed recommendations, progress, and streaks.
- Supabase Auth, Postgres with RLS, and tested Edge Functions.
- A coherent visual system, Spanish product voice, responsive shell, motion,
  accessibility tests, and reusable controls.
- A substantial automated baseline: 78 Flutter test files and more than 600
  declared tests, plus database and Edge Function tests.

### Current product gap

The current main loop is predominantly read, choose, and type. The product
promise is about speaking, but the codebase has no microphone capture,
transcription, speech-attempt entity, oral metric, or speaking profile. The
onboarding also frames the whole product as finding better words, which is a
valuable subsystem but narrower than the intended communication gym.

### Existing pieces to reuse

- `Result` and `Failure` for typed failures.
- Fake/real repository overrides in `bootstrap.dart`.
- Session step and controller patterns from `features/daily`.
- Summary and retry patterns from exercises.
- Theme and scene metadata for generating relevant prompts later.
- Design tokens, `FluiButton`, `FluiCard`, progress bars, loading waves, sticky
  CTA docks, responsive page frames, and reduced-motion support.
- Supabase Edge Function HTTP, CORS, environment, and test helpers.

## Research decisions

### Capture

Use Flutter's `record` package. It supports web, Android, and iOS; provides
microphone permission checks, WAV/PCM capture, and amplitude readings; and is
the package used by Flutter's official audio-recording recipe.

Capture mono WAV at 16 kHz when supported. If a platform cannot honor that
configuration, accept its supported WAV format and let the transcription
provider downsample it. The first recording is capped at 45 seconds. The user
may stop after 5 seconds; shorter input is rejected locally as insufficient.

### Transcription

Use Groq `whisper-large-v3-turbo` behind an authenticated Supabase Edge
Function. It is multilingual, supports Spanish, returns word and segment
timestamps, has generous development limits, and currently costs about
US$0.04 per audio hour.

The provider key is a Supabase secret and never ships to Flutter. Provider
details stay behind a Flui-owned response contract so a Cloudflare Workers AI
adapter can replace Groq later without changing domain or UI code.

### Analysis

The P0 analysis is deterministic. It does not call a text-generation model.
This keeps latency, cost, and explanations predictable and makes every metric
testable.

The analyzer consumes:

- recording duration;
- normalized transcript;
- timestamped words;
- timestamped segments; and
- the challenge's configured filler lexicon and target duration.

The analyzer produces evidence, confidence, and one next action. It never
produces a global communication score.

### Rejected P0 alternatives

- Browser-local `whisper.cpp`: private and open source, but the documented
  browser runtime for a 60-second clip is roughly 20-30 seconds on a modern
  machine, which misses the feedback target.
- Browser speech recognition through `speech_to_text`: browser coverage is
  inconsistent and the package targets commands and short phrases.
- AssemblyAI: generous trial, but its documented filler-word preservation is
  English-only.
- A fully generative evaluator: adds cost and non-determinism before the core
  repeat-and-improve loop has been validated.
- Video, gaze, emotion, confidence, pronunciation, and clinical voice metrics:
  none are necessary to prove the P0 hypothesis, and several are easy to
  overstate.

## User experience

### Entry point

Add one primary card to `Hoy`, above vocabulary content:

> Tienes 2 minutos. Vamos a entrenar tu fluidez.

Primary action: **Empezar reto oral**.

The existing vocabulary plan remains available below it. The first release
does not merge speech attempts into the vocabulary review ladder.

### Challenge

The initial challenge is a deterministic, versioned prompt:

> Tienes 45 segundos. Cuéntame una decisión pequeña que mejoró tu día.

Guidance is one line:

> Busca una idea clara. Si necesitas pensar, haz una pausa.

The prompt is intentionally personal, low-risk, and answerable without expert
knowledge. A fixed prompt makes comparison and QA easier. Prompt generation is
not part of P0.

### Permission state

Before the browser permission request, Flui explains:

> Usaremos el micrófono para analizar este intento. El audio se descarta al
> terminar el análisis.

Actions:

- **Permitir micrófono**
- **Ahora no**

If permission is denied, explain how to retry without trapping the user on the
screen. Do not repeatedly trigger the browser permission prompt.

### Recording state

- One large central microphone control.
- Countdown from 45 seconds.
- Elapsed time and a calm amplitude visualization.
- **Terminar** becomes available after 5 seconds.
- Recording ends automatically at 45 seconds.
- Navigation away during recording requires a confirmation inside the app.
- The P0 does not play the recording back automatically.

### Analysis state

Show a short progress state:

> Escuchando tu intento...

After 8 seconds, change the supporting copy to:

> Está tomando un poco más de lo normal. Tu intento sigue aquí.

At 15 seconds, expose **Reintentar análisis** and **Grabar de nuevo**. Keep the
recorded bytes in memory until analysis succeeds, the user records again, or
leaves the flow.

### First feedback

Show no more than three evidence-backed observations. Example:

> Acabas de hacerlo
>
> - Ritmo: 154 palabras/min; aceleraste al final.
> - Pausas: una pausa útil antes de tu conclusión.
> - Muletillas detectadas: 4 (`pues` x3, `eh` x1).
>
> Tu reto: repite haciendo una pausa antes de la última idea.

Primary action: **Intentar de nuevo**.

Secondary action: **Terminar por hoy**.

Do not label ordinary discourse markers as errors. The UI says “detectadas”
and describes concentration or repetition. A filler signal appears only when
the configured threshold is exceeded.

### Comparison

After the second attempt, compare only like-for-like measurements:

> Tu segundo intento
>
> - Muletillas: 4 -> 2
> - Ritmo: 154 -> 142 palabras/min
> - Pausas largas: 2 -> 1

Then state one grounded improvement:

> Redujiste tus muletillas en este reto.

If a measure worsens, avoid punishment:

> Esta vez fuiste más lento, pero aparecieron dos pausas largas. Tu siguiente
> sesión puede trabajar continuidad.

Primary action: **Completar reto**.

The P0 allows exactly two analyzed attempts per challenge. “One more try” with
more than two attempts can be tested after the basic loop is measurable.

## Metrics

### Words per minute

`wordCount / spokenDurationMinutes`, where spoken duration is the span from
the first timestamped word start to the last timestamped word end. Also retain
wall-clock recording duration. Show WPM only for at least 15 recognized words.

### Pauses

A pause is the gap between the end of one timestamped word and the start of
the next.

- intentional-pause candidate: 600-1,500 ms;
- long pause: greater than 2,000 ms.

Do not claim a pause was rhetorically effective from timing alone. “Pausa útil”
is allowed only when the gap occurs at sentence punctuation or before the last
segment; otherwise report its duration and position neutrally.

### Pace variation

Divide timestamped words into chronological thirds. Compute WPM for each
third. Report “aceleraste al final” or “bajaste el ritmo al final” only when the
last third differs from the first by at least 15 percent and each third has at
least five recognized words.

### Filler profile

P0 Spanish lexicon:

- filled pauses: `eh`, `mmm`, `um`, `em`;
- candidate discourse fillers: `este`, `pues`, `o sea`, `digamos`, `como que`.

Normalize case and punctuation. Match multiword phrases before single words.
The attempt stores counts by normalized phrase.

Rules:

- never call a phrase wrong merely because it occurs;
- expose a filler signal at three total detections, or when one candidate
  phrase appears twice;
- describe the pattern as an estimate because ASR may omit filled pauses;
- never display zero fillers as proof that none occurred;
- allow future per-user additions without changing the attempt schema.

### Repetition

Count normalized content words after removing a small, versioned Spanish
function-word list. Report repetition only when one content lemma or surface
form appears at least three times and represents at least 8 percent of content
tokens. P0 may use surface forms; lemmatization is deferred.

### Confidence

Each metric is `available`, `estimated`, or `unavailable`.

- WPM and timestamp gaps are `available` when timestamps exist.
- Filler and repetition counts are `estimated` because they depend on ASR.
- Missing or low-confidence transcription makes text-derived metrics
  `unavailable`.

The UI omits unavailable metrics and explains when the recording could not be
measured reliably.

## Architecture

### Flutter feature

Create `features/speaking/` with the existing layer boundaries:

```text
features/speaking/
  domain/
    speaking_challenge.dart
    speaking_attempt.dart
    speech_analysis.dart
    speech_analyzer.dart
    speaking_repository.dart
    attempt_comparison.dart
  data/
    dtos/speech_analysis_dto.dart
    fake_speaking_repository.dart
    supabase_speaking_repository.dart
  presentation/
    controllers/speaking_session_controller.dart
    providers/speaking_providers.dart
    pages/speaking_challenge_page.dart
    widgets/recording_control.dart
    widgets/speech_feedback_view.dart
    widgets/attempt_comparison_view.dart
```

Audio recording is represented by a small platform-facing interface so widget
and controller tests do not invoke a real microphone. The domain receives no
Flutter, plugin, Supabase, or provider types.

### Domain model

`SpeakingChallenge`:

- `id`;
- `version`;
- `prompt`;
- `guidance`;
- `durationSeconds`;
- `fillerLexiconVersion`.

`SpeakingAttempt`:

- local attempt index, 1 or 2;
- recording duration;
- analysis status;
- transcript for the current in-memory flow;
- `SpeechAnalysis`;
- provider request ID for diagnostics when available.

`SpeechAnalysis`:

- word count;
- optional WPM;
- pause observations;
- optional pace variation;
- filler counts;
- repeated-word observations;
- metric confidence map;
- one recommended retry action;
- analyzer version.

The transcript is not part of persisted P0 progress.

### Repository contract

`SpeakingRepository.analyze` accepts encoded audio bytes, MIME type, challenge
ID, challenge version, and recording duration. It returns a typed
`Result<SpeechAnalysisEnvelope>`.

The fake repository returns deterministic fixtures for first and second
attempts, including latency and injectable failures. It makes the complete UI
flow testable without microphone access or network calls.

### Edge Function

Add `supabase/functions/speech-analyze`.

Responsibilities:

1. require a valid Supabase user JWT;
2. enforce MIME type, maximum 60-second declared duration, and maximum 5 MB;
3. reject empty or malformed bodies;
4. rate-limit per user at the application level;
5. send audio to Groq with language `es`, word and segment timestamps;
6. normalize the provider response into Flui's contract;
7. run deterministic metric analysis in a shared TypeScript module or return
   normalized timestamps for the Dart analyzer;
8. return typed errors without provider secrets or raw error bodies; and
9. discard request bytes after the response.

The P0 uses one analyzer implementation in Dart for fake fixtures and unit
tests. The Edge Function returns provider-neutral transcription evidence; Dart
produces the final metrics. This keeps product rules in the existing domain
architecture and makes provider changes cheap.

### Edge response

```json
{
  "requestId": "uuid",
  "transcript": "texto normalizado",
  "durationMs": 42100,
  "words": [
    {"text": "una", "startMs": 420, "endMs": 610, "confidence": null}
  ],
  "segments": [
    {"text": "Una decisión...", "startMs": 420, "endMs": 5100}
  ],
  "provider": "groq",
  "model": "whisper-large-v3-turbo"
}
```

Provider and model are diagnostics, not user-facing claims.

### Persistence

Add `speaking_attempts` with RLS-protected rows owned by the current user:

- `id uuid`;
- `user_id uuid`;
- `challenge_id text`;
- `challenge_version int`;
- `attempt_index smallint`;
- `recording_duration_ms int`;
- `word_count int`;
- `words_per_minute numeric null`;
- `long_pause_count int null`;
- `filler_counts jsonb`;
- `repeated_words jsonb`;
- `metric_confidence jsonb`;
- `analyzer_version int`;
- `completed_at timestamptz`.

Do not persist:

- audio bytes;
- storage paths;
- transcript text;
- provider tokens; or
- provider raw responses.

An attempt is persisted only after analysis succeeds. Both attempts are kept
so personal progress can later compare historical aggregates.

### Integration with existing daily activity

A completed speaking challenge counts as an active day. Update the active-day
provider to union completed vocabulary sessions, exercise attempts, speaking
attempts, and streak repairs.

The P0 does not award vocabulary mastery, move word schedules, or change theme
selection. Future sessions may insert active vocabulary into speaking prompts
through a separate specification.

## Error handling

Typed failure categories:

- microphone permission denied;
- unsupported recording environment;
- recording interrupted;
- response too short;
- network unavailable;
- transcription timeout;
- transcription unavailable;
- speech not detected;
- rate limited; and
- unexpected service failure.

Each state offers a next action. None discards an analyzable recording merely
because the first network request failed.

If speech is not detected, say:

> No pude distinguir suficiente voz en este intento. Acércate un poco al
> micrófono y prueba otra vez.

Do not assign scores or progress to failed analysis.

## Privacy and security

- Explain audio processing before requesting microphone permission.
- Send audio only after the user finishes recording.
- Keep provider credentials in Supabase secrets.
- Authenticate every analysis request.
- Reject oversized inputs before forwarding them.
- Do not log audio, transcript, authorization headers, or provider raw bodies.
- Do not place audio in Supabase Storage for the P0.
- Persist derived metrics only.
- Add a privacy note reachable from the recording screen.
- Later “before versus after” audio requires a separate, explicit opt-in
  design with retention and deletion controls.

## Accessibility and responsive behavior

- All recording states have visible text; waveform/amplitude is decorative.
- The microphone control has a semantic label and does not rely on color.
- Timer announcements occur at start, 15 seconds remaining, and end; they do
  not announce every second.
- Reduced-motion mode removes waveform scaling and uses a static level meter.
- Keyboard and switch users can start and stop recording.
- Minimum tap target remains 48 px.
- Mobile keeps the primary action within thumb reach; desktop constrains the
  exercise to a focused single column.

## Testing

### Domain tests

- WPM uses spoken span and respects the 15-word minimum.
- Pause thresholds handle exact boundaries.
- Pace variation requires 15 percent and sufficient words per third.
- Multiword filler matching precedes single-word matching.
- Functional single uses do not trigger filler feedback.
- Repetition ignores function words and respects both thresholds.
- Missing timestamps mark metrics unavailable.
- Attempt comparison reports improvement, regression, and no meaningful
  change without inventing precision.

### Repository and Edge Function tests

- Fake repository first/second fixtures and injected errors.
- JWT required.
- content type, duration, and body-size validation.
- provider request uses Spanish and word/segment timestamps.
- provider errors map to typed Flui errors.
- raw audio and transcript never reach logs or persistence.
- normalized response rejects impossible timestamps.

### Widget and controller tests

- permission explanation precedes plugin prompt.
- permission denial recovery.
- start, stop, auto-stop, and interrupted recording.
- too-short attempt.
- slow analysis state and retry without re-recording.
- first feedback has at most three signals.
- second attempt shows comparison.
- unavailable metrics are omitted.
- reduced motion and semantics.

### Integration test

Fake backend flow:

`Hoy -> reto oral -> permiso simulado -> grabar -> feedback -> repetir ->`
`comparación -> completar -> Hoy/progreso actualizado`.

The production-provider smoke test is manual and uses a non-sensitive Spanish
fixture; it is never part of pull-request CI.

## Rollout and observability

Protect the entry point with a feature flag. Initially enable it only on the
fake backend and local Supabase. Production activation requires:

- Groq secret configured;
- migration applied;
- Edge Function deployed;
- privacy copy reviewed;
- one Colombian and one non-Colombian Spanish fixture checked manually;
- median analysis latency below 10 seconds for 45-second inputs; and
- no transcript or audio in application logs.

Track operational aggregates without content:

- analysis success/failure counts;
- error category;
- provider latency;
- recording duration bucket;
- first-to-second attempt completion rate; and
- retry improvement availability.

## Scope boundaries

### P0

- one fixed 45-second challenge;
- two attempts;
- recording and microphone states;
- Groq transcription through Supabase;
- deterministic WPM, pauses, pace variation, filler estimate, repetition;
- concise feedback and attempt comparison;
- derived-metric persistence;
- active-day integration;
- fake backend and complete tests.

### P1

- initial multi-prompt speaking assessment;
- dynamic speaking profile;
- adaptive daily selection;
- prompt catalog by context;
- active-vocabulary speaking prompts;
- weekly personal trends.

### P2

- AI roleplay and conversation gym;
- story and argument gyms;
- voice lab for emphasis and intonation;
- personal filler lexicon;
- optional audio before/after history with consent.

### P3

- video and nonverbal signals;
- real-time interruption;
- experimental local ASR;
- community or optional competition.

## Acceptance criteria

The P0 is complete only when:

1. a user can finish the full loop on web and the UI supports mobile sizes;
2. no audio or transcript is persisted;
3. normal feedback arrives in under 10 seconds in the production smoke test;
4. first and second attempts are compared with deterministic metrics;
5. unavailable measurements are omitted or labeled honestly;
6. the complete fake integration flow passes;
7. existing vocabulary, auth, subscription, and progress tests still pass;
8. static analysis, formatting, unit, widget, integration, Edge Function, and
   database tests pass; and
9. microphone denial, timeout, no-speech, offline, and retry states all have a
  usable recovery path.
