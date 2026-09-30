# Architecture

flui is a Flutter app (web first) backed by Supabase. There is **no custom backend**: the app talks
to Supabase Auth and Postgres directly, Row Level Security protects every table, and a small set of
Edge Functions talks to Whop for payments and Groq for speech analysis. Domain logic runs in pure
Dart on the client.

flui is a daily oral-expression gym: every learning surface (a mandatory spoken diagnosis, the daily
plan, the ENTRENAR training lab, vocabulary review, quick practice) ends in the user speaking, through
one shell-owned mic (`core/mic`) — never a per-screen record button. See ADR-0006 for the training
engine's decisions in full.

Decisions and trade-offs: [ADRs](adr/). Product rules: [learning-method.md](learning-method.md).

## 1. System context

```mermaid
flowchart LR
  user([Adult Spanish speaker])
  subgraph vercel[Vercel Pro]
    web[Flutter web build<br/>static files + SPA rewrites]
  end
  subgraph supabase[Supabase project]
    auth[Auth<br/>email + password]
    rest[PostgREST API]
    db[(Postgres + RLS)]
    fnCheckout[Edge Function<br/>whop-checkout]
    fnWebhook[Edge Function<br/>whop-webhook]
    fnAnalyze[Edge Function<br/>speech-analyze]
    fnRetention[Edge Function<br/>audio-retention]
    fnDelete[Edge Function<br/>account-delete]
    bucket[(Storage bucket<br/>speaking-audio)]
  end
  whop[Whop<br/>hosted checkout, memberships]
  groq[Groq<br/>Whisper + LLM]
  gha[GitHub Actions]

  user -->|HTTPS| web
  web -->|supabase_flutter: sign-in, JWT| auth
  web -->|JWT: select/insert own rows, rpc my_access/has_access| rest
  rest --> db
  web -->|JWT: POST planId| fnCheckout
  fnCheckout -->|service role: plans, has_access| db
  fnCheckout -->|API key: create checkout configuration| whop
  user -->|redirect: pays or starts trial| whop
  whop -->|signed webhook| fnWebhook
  fnWebhook -->|service role: events, entitlements| db
  web -->|JWT: audio + challengeId + mode| fnAnalyze
  fnAnalyze -->|service role: has_access, quota| db
  fnAnalyze -->|Whisper transcribe, LLM evaluate| groq
  web -->|JWT: upload own attempt audio| bucket
  gha -->|daily cron| fnRetention
  fnRetention -->|service role: delete expired/orphan objects| bucket
  web -->|JWT: request own account deletion| fnDelete
  fnDelete -->|cancel membership| whop
  fnDelete -->|service role: remove storage, delete auth user| db
  gha -->|flutter build web + vercel deploy| vercel
  gha -->|CI: pgTAP, Deno tests| supabase
```

## 2. Components

| Component | Responsibility | Trust boundary |
|-----------|----------------|----------------|
| Flutter app (`app/`) | UI, session/training planning, grading, mastery, streaks, voice metrics (pure Dart), one shell-owned mic, persistence through Supabase | Untrusted client. Holds only the publishable (anon) key and the user JWT. |
| Supabase Auth | Email/password accounts (Google later), JWT issuance | Managed |
| Postgres + RLS (`supabase/migrations`) | Content (words + challenges), learning/training data, entitlements, access + quota functions | Enforces who reads and writes what |
| `whop-checkout` Edge Function | Verifies the user JWT, looks up the plan, creates a Whop checkout configuration with `metadata.app_user_id` | Holds `WHOP_API_KEY` |
| `whop-webhook` Edge Function | Verifies the Standard Webhooks signature, stores events idempotently, updates `entitlements` | Holds `WHOP_WEBHOOK_SECRET`; only writer of entitlements |
| `speech-analyze` Edge Function | Verifies access and the daily quota before any paid call, resolves the prompt by `challengeId` server-side, calls Groq (`mode=analyze`: Whisper + LLM; `mode=transcribe`: Whisper only), sanitizes the response | Holds the Groq API key; the only caller of Groq |
| `audio-retention` Edge Function | Daily cron: deletes `speaking-audio` objects past the 90-day milestone window or orphaned (24 h grace), never one a `stored` row still references | Holds `AUDIO_RETENTION_SECRET`; service role only |
| `account-delete` Edge Function | Fail-closed self-service deletion: cancels the Whop membership, removes the user's storage, deletes the auth user | Service role; only path that deletes an `auth.users` row on request |
| Whop | Product, 2 recurring plans (30 and 90 days) with a 7-day trial, hosted checkout, card collection, membership cancellation | External |
| Groq | Whisper transcription and LLM evaluation for speaking attempts | External |
| Vercel Pro | Serves the prebuilt Flutter web bundle | Static hosting only |
| GitHub Actions | CI, web build and deploy, Supabase keep-alive, daily audio-retention cron | Holds deploy secrets |

## 3. App flow (first run)

```mermaid
flowchart LR
  welcome[Welcome] --> intro[Intro<br/>benefits + micro-lesson, skippable]
  intro --> register[Register<br/>Supabase Auth]
  register --> paywall["Paywall<br/>monthly / quarterly<br/>«7 días gratis. Hoy no te cobramos nada.»"]
  paywall -->|POST whop-checkout| checkout[Whop hosted checkout<br/>card collected, trial starts]
  checkout -->|redirect APP_URL/checkout/return| confirm[Confirming access<br/>poll my_access]
  confirm -->|has_access = true, no skill_profiles row| diagnosis[Mandatory diagnosis<br/>3 spoken slots, pausable]
  diagnosis -->|profile derived + saved| hoy[Hoy<br/>duration chips, budget-free]
```

- Router guard: signed out → Welcome; signed in and `my_access().has_access == false` → Paywall;
  signed in, access granted and no `skill_profiles` row yet → the diagnosis (mandatory, pausable back
  to its own intro, never skippable outright).
- The webhook can arrive after the redirect. On `/checkout/return`, poll `my_access()` (for example
  every 2 s for up to 60 s) and then offer a retry. Do not trust query parameters on the return URL.
- On app start and on resume, refresh `my_access()`; if access ended, route to the Paywall.
- HOY itself no longer requires a persisted daily-session row first (D41): it shows duration chips
  and a provisional plan, and persists on START or the first mic press. The classic word-review
  daily session (Descubre → Mira → Elige → Úsala) keeps its own separate time-budget ask
  (`/today/time`), unchanged by the diagnosis or the chips card.

## 4. Data flows

### 4.1 Sign-up → trial

```mermaid
sequenceDiagram
  actor U as User
  participant A as Flutter app
  participant Auth as Supabase Auth
  participant DB as Postgres
  participant F as whop-checkout
  participant W as Whop
  participant H as whop-webhook

  U->>A: email, password, name
  A->>Auth: signUp(data: {display_name})
  Auth->>DB: insert auth.users
  DB->>DB: trigger on_auth_user_created → profiles row
  A->>DB: rpc my_access() → has_access = false
  A-->>U: Paywall
  U->>A: choose plan
  A->>F: POST {planId} + Bearer JWT
  F->>DB: subscription_plans (active), has_access(uid)
  F->>W: POST /checkout_configurations {plan_id, metadata.app_user_id, redirect_url}
  W-->>F: purchase_url
  F-->>A: {purchaseUrl}
  A-->>U: open Whop checkout
  U->>W: card + confirm (trial, no charge today)
  W->>H: membership.activated (status trialing, metadata.app_user_id)
  H->>DB: whop_webhook_events + upsert entitlements(trialing, trial_ends_at)
  W-->>U: redirect APP_URL/checkout/return
  A->>DB: poll my_access() → has_access = true
```

### 4.2 Daily session

```mermaid
sequenceDiagram
  actor U as User
  participant A as Flutter app (domain)
  participant DB as Postgres (RLS)

  A->>DB: select word_progress (own), words + exercises + readings (published, has_access), themes
  U->>A: picks 10 min and a theme
  A->>A: SessionPlanner(budget, dueReviews, candidates, confusions, semantic sets, themeId)
  A->>DB: upsert daily_sessions(local_date, minutes, theme_id, planned_word_ids, review_word_ids)
  A-->>U: reviews first, then Descubre → Entiende → Mira → Elige → Úsala
```

### 4.3 Exercise attempt → progress

```mermaid
sequenceDiagram
  actor U as User
  participant A as Flutter app (domain)
  participant DB as Postgres (RLS)

  U->>A: picks an option
  A->>A: HintPolicy: "Casi." + hint / resolve → grade (good | hard | again)
  A->>DB: insert exercise_attempts(attempts, revealed, grade, local_date, duration_ms)
  A->>A: ReviewScheduler + MasteryStateMachine
  A->>DB: upsert word_progress(state, ladder_step, next_due_on, first_try_success_days, ...)
  A->>DB: update daily_sessions.completed_at (when the session ends)
```

### 4.4 Checkout → webhook → entitlement → access

```mermaid
sequenceDiagram
  participant W as Whop
  participant H as whop-webhook
  participant DB as Postgres
  participant A as Flutter app

  W->>H: POST (webhook-id, webhook-timestamp, webhook-signature)
  H->>H: verify HMAC-SHA256 (5 min tolerance) → 401 if invalid
  H->>DB: insert whop_webhook_events on conflict do nothing
  alt already processed
    H-->>W: 200 {status: duplicate}
  else membership.* event
    H->>DB: read entitlements(user_id)
    H->>H: map Whop status, skip stale or older-membership events
    H->>DB: upsert entitlements, then set processed_at
    H-->>W: 200 {status: applied}
  else other event
    H->>DB: set processed_at
    H-->>W: 200 {status: ignored}
  end
  A->>DB: rpc my_access() / content queries → RLS uses has_access(auth.uid())
```

Whop → flui status mapping: `trialing` → `trialing`; `active`, `canceling` → `active`;
`past_due`, `unresolved` → `past_due`; `completed`, `expired` → `expired`; `canceled` → `canceled`;
`drafted` and unknown → ignored. Only `trialing` and `active` within `current_period_end` grant access.

## 5. Data model

```mermaid
erDiagram
  AUTH_USERS ||--|| PROFILES : "trigger creates"
  AUTH_USERS ||--o| ENTITLEMENTS : "has"
  AUTH_USERS ||--o{ DAILY_SESSIONS : "plans"
  AUTH_USERS ||--o{ WORD_PROGRESS : "learns"
  AUTH_USERS ||--o{ EXERCISE_ATTEMPTS : "answers"
  AUTH_USERS ||--o{ STREAK_REPAIRS : "repairs"
  WORDS ||--o{ WORD_CONFUSIONS : "is confused with"
  WORDS ||--o{ EXERCISES : "has"
  EXERCISES ||--|{ EXERCISE_OPTIONS : "has exactly 3"
  WORDS ||--o{ READINGS : "shown in"
  WORDS ||--o{ WORD_PROGRESS : "tracked by"
  EXERCISES ||--o{ EXERCISE_ATTEMPTS : "attempted in"

  PROFILES {
    uuid id PK
    text display_name
    timestamptz created_at
    timestamptz updated_at
  }
  WORDS {
    uuid id PK
    text slug UK
    text lemma
    text part_of_speech
    text_array syllables
    smallint stressed_syllable
    text ipa_latam
    text ipa_es
    text explanation
    text example_sentence
    text register
    smallint pedantry_risk
    text usage_tip
    text when_not_to_use
    text_array collocations
    jsonb replaces
    text_array family
    int sort_order
    bool published
  }
  WORD_CONFUSIONS {
    uuid id PK
    uuid word_id FK
    text confused_with
    uuid confused_word_id FK
    text difference
    text memory_trick
  }
  EXERCISES {
    uuid id PK
    uuid word_id FK
    text kind
    text sentence
    text hint_general
    text explanation
    smallint position
  }
  EXERCISE_OPTIONS {
    uuid id PK
    uuid exercise_id FK
    text text
    bool is_correct
    text distractor_type
    text why_not
    text hint_specific
    smallint position
  }
  READINGS {
    uuid id PK
    uuid word_id FK
    text scene
    text conversation_type
    text title
    text body
    text before_phrase
    text after_phrase
    smallint position
  }
  DAILY_SESSIONS {
    uuid user_id PK
    date local_date PK
    smallint minutes
    uuid_array planned_word_ids
    uuid_array review_word_ids
    timestamptz completed_at
  }
  WORD_PROGRESS {
    uuid user_id PK
    uuid word_id PK
    text state
    date introduced_on
    date_array first_try_success_days
    bool form_recall_done
    bool production_done
    smallint ladder_step
    date next_due_on
    text last_grade
    timestamptz last_reviewed_at
  }
  EXERCISE_ATTEMPTS {
    uuid id PK
    uuid user_id FK
    uuid exercise_id FK
    uuid word_id FK
    smallint attempts
    bool revealed
    text grade
    date local_date
    int duration_ms
  }
  STREAK_REPAIRS {
    uuid user_id PK
    date repaired_date PK
  }
  SUBSCRIPTION_PLANS {
    text id PK
    text whop_plan_id
    int billing_period_days
    int price_cents
    text currency
    text label
    text savings_label
    int sort_order
    bool active
  }
  ENTITLEMENTS {
    uuid user_id PK
    text whop_membership_id UK
    text whop_plan_id
    text status
    timestamptz current_period_end
    timestamptz trial_ends_at
    bool cancel_at_period_end
    timestamptz last_event_at
  }
  WHOP_WEBHOOK_EVENTS {
    text webhook_id PK
    text event_type
    timestamptz received_at
    timestamptz processed_at
    jsonb payload
  }
```

### Training-engine tables (added by ADR-0006, not shown in the ERD above)

| Table | Purpose |
|-------|---------|
| `challenges` | Training/diagnosis prompts, seeded from `content/challenges/*.yml`; readable by any authenticated user once `published` (no access gate — content is not the cost). |
| `speaking_attempts` | Append-only: one row per analyzed spoken attempt (`context` in diagnosis/daily/lab/word/quick), transcript, metrics, sanitized observations, audio status/path. Word-exercise answers are never inserted here (D37). |
| `skill_profiles` | One row per diagnosis (id = the diagnosis session id); closes that diagnosis. A trigger sets `kind` (baseline/retake) and rejects a retake under 30 days. |
| `speech_analysis_usage` | The daily analysis quota ledger (`claim_speech_analysis`), service-role only. |
| `daily_sessions` (additive columns) | `focus_area`, `challenge_id`, `woven_word_ids` — the speaking goal woven into the same row the word plan already used. |
| `profiles` (additive column) | `audio_retention_consent` — null until asked; gates the `speaking-audio` bucket's insert policy alongside the row's own `pending` status. |

`speaking-audio` (private bucket, 2 MiB/object): key `<uid>/<attempt_id>.<ext>`; insert requires the
matching attempt row to be `pending`, the context to be diagnosis or a weekly milestone, and consent
`true`. `select`/`delete` are own-folder only; there is no `update`.

### Access rules

| Table / function | anon | authenticated | service role |
|------------------|------|---------------|--------------|
| `profiles` | — | select own; update own `display_name` only | all |
| `words`, `word_confusions`, `exercises`, `exercise_options`, `readings`, `word_themes` | — | select published content **only when `has_access()`** | all |
| `themes` | — | select published rows (the taxonomy is the shape of the offer, not the paid content) | all |
| `daily_sessions`, `word_progress` | — | select, insert, update own rows | all |
| `exercise_attempts`, `streak_repairs` | — | select, insert own rows (append-only) | all |
| `subscription_plans` | select active | select active | all |
| `entitlements` | — | select own | all (webhook) |
| `whop_webhook_events` | — | — | all |
| `has_access(uid)` | — | execute (own uid only) | execute |
| `my_access()` | — | execute | execute |

Enforced invariants: every exercise has exactly 3 options and exactly 1 correct (deferred constraint
trigger); a sentence contains exactly one `{{blank}}`; distractors carry type, `why_not` and
`hint_specific`; a revealed attempt is graded `again`.

### Access functions

```sql
public.has_access(uid uuid default auth.uid()) returns boolean
-- true when entitlements.status in ('trialing','active')
-- and (current_period_end is null or current_period_end > now())

public.my_access() returns json
-- { "has_access": bool,
--   "entitlement_status": "trialing"|"active"|"past_due"|"canceled"|"expired"|null,
--   "current_period_end": timestamptz|null,
--   "trial_ends_at": timestamptz|null }   -- only while trialing
```

### Edge Function contracts

| Function | Request | Success | Errors (`{error: {code, message}}`) |
|----------|---------|---------|--------------------------------------|
| `POST /functions/v1/whop-checkout` | `Authorization: Bearer <user JWT>`, body `{"planId": "monthly" \| "quarterly"}` | `200 {"purchaseUrl": "https://whop.com/checkout/..."}` | 400 `invalid_body`, 401 `unauthorized`, 403 `origin_not_allowed`, 404 `unknown_plan`, 405, 409 `already_subscribed`, 502 `upstream_error`, 500 `internal_error` |
| `POST /functions/v1/whop-webhook` | Whop Standard Webhooks headers + raw JSON | `200 {"status": "applied" \| "duplicate" \| "ignored" \| "skipped", "reason"?}` | 401 `invalid_signature`, 400 `invalid_payload`, 500 (Whop retries) |
| `POST /functions/v1/speech-analyze` | `Authorization: Bearer <user JWT>`, body `{audio (base64), mimeType, durationMs, challengeId?, mode?: "analyze"\|"transcribe"}` | `200` analyze: `{analysis:{summary,structure,vocabulary,strength,retryCue}, observations:[...]}`; transcribe: `{text, durationMs, words}` | 400 `invalid_body`/`invalid_audio`/`unknown_challenge`, 401, 403 `access_required`, 413 `payload_too_large`, 422 `no_speech`, 429 `rate_limited`/`daily_limit_reached`, 502 `upstream_error`, 503 `access_unavailable` |
| `POST /functions/v1/account-delete` | `Authorization: Bearer <user JWT>` | `200 {"status": "deleted"}` | 401, 502 `billing_unavailable`, 404 `whop_membership_not_found`, 500 |
| `audio-retention` (cron only, `Authorization: Bearer <AUDIO_RETENTION_SECRET>`) | — | `200 {"deleted": N, "failed": N}` | 401, 500 |

## 6. Flutter app structure

Feature-first, with Clean Architecture layers inside each feature.

```text
app/lib/
  main.dart, bootstrap.dart   # config parsing, backend selection (fake | supabase), DI overrides
  app/                  # FluiApp, router + guards, FluiBottomBar/NavigationRail shell, top-level pages
  core/                 # app-wide infrastructure: config, clock, theme tokens, Supabase client,
                        # error/Result types, l10n (app_es.arb). No feature imports.
                        # audio/  — SpeechRecorder/SpeechPlayer ports, HoldToRecord (pure)
                        # mic/    — MicController, MicTargetRegistry, MicTarget contracts (pure) +
                        #           presentation/ (MicButton, MicDock, notices — the only recorder UI)
  shared/               # reusable UI (atoms, molecules) and pure helpers. No feature imports.
  features/
    auth/               # sign-up, sign-in, sign-out, session stream
    onboarding/         # welcome and intro slides (benefits + a real-word micro-lesson)
    subscription/       # plans, my_access, paywall, checkout return polling
    diagnosis/          # the mandatory 3-slot spoken diagnosis, pause/resume, skill_profiles
    daily/              # HOY: budget-free chips + provisional plan, SessionPlanner, daily_sessions,
                        # the word daily session (Descubre/Mira/Elige/Úsala)
    training/           # the training-engine domain (Challenge, BehaviorCode, TrainingLoop,
                        # TrainingPlanner, Progression, DiagnosisProfiler) and ENTRENAR + quick
                        # practice presentation; data/ for challenges, speaking_attempts, audio store
    speaking/           # SpeechAnalysisRepository (speech-analyze client), SpeechTranscript
    themes/             # theme taxonomy, recommender (catalog order), neighbours, "Explorar"
    vocabulary/         # catalog, word detail, mastery state machine, review scheduling, exercises
                        # (cloze, form recall, production — all spoken through the shell mic)
    reading/            # "En contexto" scenes
    profile/            # "Tu progreso": streaks, evidence, playback, audio settings, account,
                        # account deletion
      domain/           # entities, value objects, use cases, repository interfaces (pure Dart)
      data/             # Supabase data sources, DTOs, repository implementations
      presentation/     # Riverpod notifiers (view models), screens (containers), widgets (presentational)
```

**Dependency rule:** `presentation → domain ← data`. `domain` imports no Flutter, Supabase or
Riverpod code. `data` implements `domain` interfaces. Features talk to each other only through
another feature's `domain` API. Screens (containers) read providers; widgets receive plain values
and callbacks. `core/audio` and `core/mic` import no feature (checked by an architecture test);
widgets never own recorder, permission or timer logic — they forward pointer/keyboard events to
`MicController` and render its `states`/`notices`/`levels`.

Stack (for reference): Flutter 3.47.4, Dart 3.13, `material_ui`, Riverpod 3 + generator,
go_router 18, freezed 4, `supabase_flutter`, `very_good_analysis`, `mocktail`, gen-l10n (es).

## 7. Testing strategy

| Layer | Tool | What it proves | Runs in |
|-------|------|----------------|---------|
| Domain (Dart) | `flutter test` unit tests | Session planner, ladder, grading, hint policy, mastery, streaks (tables in learning-method.md) | `app-ci.yml` |
| Presentation | widget tests with provider overrides, `mocktail` | Screens render states, one primary action, copy | `app-ci.yml` |
| Flows | `integration_test` | Sign-up → paywall → session against a local stack | local / later CI |
| Database | pgTAP (`supabase/tests/database`) | RLS for every table, access truth table, triggers, content invariants, seed quality, account-deletion cascade, audio-retention selection | `supabase-ci.yml` |
| Edge Functions | `deno test` (`supabase/functions/**/_test.ts`) | Signature verification, event mapping, CORS, validation, access/quota gating (both `speech-analyze` modes), account-delete's fail-closed order, handler behavior with fakes | `supabase-ci.yml` |

## 8. Environments and configuration

| Environment | Supabase | Whop | App URL |
|-------------|----------|------|---------|
| local | `supabase start` (API `http://127.0.0.1:54421`) | sandbox (`https://sandbox-api.whop.com/api/v1`) | `http://localhost:3000` |
| dev (optional) | separate Supabase project | sandbox | Vercel preview |
| prod | production Supabase project | production (`https://api.whop.com/api/v1`) | Vercel production domain |

- **App config** is compile-time via `--dart-define-from-file=config/<env>.json` with the keys
  `SUPABASE_URL` and `SUPABASE_ANON_KEY` (the publishable key; safe for clients because RLS protects
  data). `app/config/*.json` is git-ignored; `*.example.json` templates are committed. CI writes a
  temporary file from GitHub secrets.
- **Function secrets** live only in Supabase (`supabase secrets set`) or in the git-ignored
  `supabase/functions/.env` locally. See [deployment.md](deployment.md). The training engine adds
  `GROQ_API_KEY` (`speech-analyze`), `AUDIO_RETENTION_SECRET` (shared between `audio-retention` and
  the GitHub Actions cron that calls it), `SPEECH_ANALYZE_DAILY_LIMIT` (optional; unset means
  unlimited), and a `WHOP_API_KEY` scoped for `membership:cancel` (`account-delete`, ADR-0004
  decision 9).
