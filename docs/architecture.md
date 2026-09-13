# Architecture

flui is a Flutter app (web first) backed by Supabase. There is **no custom backend**: the app talks
to Supabase Auth and Postgres directly, Row Level Security protects every table, and one small
Edge Functions area talks to Whop for payments. Domain logic runs in pure Dart on the client.

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
  end
  whop[Whop<br/>hosted checkout, memberships]
  gha[GitHub Actions]

  user -->|HTTPS| web
  web -->|supabase_flutter: sign-in, JWT| auth
  web -->|JWT: select/insert own rows, rpc my_access| rest
  rest --> db
  web -->|JWT: POST planId| fnCheckout
  fnCheckout -->|service role: plans, has_access| db
  fnCheckout -->|API key: create checkout configuration| whop
  user -->|redirect: pays or starts trial| whop
  whop -->|signed webhook| fnWebhook
  fnWebhook -->|service role: events, entitlements| db
  gha -->|flutter build web + vercel deploy| vercel
  gha -->|CI: pgTAP, Deno tests| supabase
```

## 2. Components

| Component | Responsibility | Trust boundary |
|-----------|----------------|----------------|
| Flutter app (`app/`) | UI, session planning, grading, mastery, streaks (pure Dart), persistence through Supabase | Untrusted client. Holds only the publishable (anon) key and the user JWT. |
| Supabase Auth | Email/password accounts (Google later), JWT issuance | Managed |
| Postgres + RLS (`supabase/migrations`) | Content, learning data, entitlements, access functions | Enforces who reads and writes what |
| `whop-checkout` Edge Function | Verifies the user JWT, looks up the plan, creates a Whop checkout configuration with `metadata.app_user_id` | Holds `WHOP_API_KEY` |
| `whop-webhook` Edge Function | Verifies the Standard Webhooks signature, stores events idempotently, updates `entitlements` | Holds `WHOP_WEBHOOK_SECRET`; only writer of entitlements |
| Whop | Product, 2 recurring plans (30 and 90 days) with a 7-day trial, hosted checkout, card collection | External |
| Vercel Pro | Serves the prebuilt Flutter web bundle | Static hosting only |
| GitHub Actions | CI, web build and deploy, Supabase keep-alive | Holds deploy secrets |

## 3. App flow (first run)

```mermaid
flowchart LR
  welcome[Welcome] --> register[Register<br/>Supabase Auth]
  register --> paywall["Paywall<br/>monthly / quarterly<br/>«7 días gratis. Hoy no te cobramos nada.»"]
  paywall -->|POST whop-checkout| checkout[Whop hosted checkout<br/>card collected, trial starts]
  checkout -->|redirect APP_URL/checkout/return| confirm[Confirming access<br/>poll my_access]
  confirm -->|has_access = true| budget[Time budget<br/>5 / 10 / 20 / 30]
  budget --> hoy[Hoy]
```

- Router guard: signed out → Welcome; signed in and `my_access().has_access == false` → Paywall.
- The webhook can arrive after the redirect. On `/checkout/return`, poll `my_access()` (for example
  every 2 s for up to 60 s) and then offer a retry. Do not trust query parameters on the return URL.
- On app start and on resume, refresh `my_access()`; if access ended, route to the Paywall.

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

  A->>DB: select word_progress (own), words + exercises + readings (published, has_access)
  U->>A: picks 10 min
  A->>A: SessionPlanner(budget, dueReviews, candidates, confusions)
  A->>DB: upsert daily_sessions(local_date, minutes, planned_word_ids, review_word_ids)
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

### Access rules

| Table / function | anon | authenticated | service role |
|------------------|------|---------------|--------------|
| `profiles` | — | select own; update own `display_name` only | all |
| `words`, `word_confusions`, `exercises`, `exercise_options`, `readings` | — | select published content **only when `has_access()`** | all |
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

## 6. Flutter app structure

Feature-first, with Clean Architecture layers inside each feature.

```text
app/lib/
  core/                 # app-wide infrastructure: config, router, theme tokens, Supabase client,
                        # error/Result types, l10n setup. No feature imports.
  shared/               # reusable UI (atoms, molecules) and pure helpers. No feature imports.
  features/
    auth/               # sign-up, sign-in, session
    access/             # my_access, paywall, checkout return polling
    session/            # time budget, SessionPlanner, daily_sessions
    practice/           # exercise flow, hint policy, grading, attempts
    words/              # catalog, word detail, mastery state machine
    progress/           # streaks, weekly consistency, stats
      domain/           # entities, value objects, use cases, repository interfaces (pure Dart)
      data/             # Supabase data sources, DTOs, repository implementations
      presentation/     # Riverpod notifiers (view models), screens (containers), widgets (presentational)
```

**Dependency rule:** `presentation → domain ← data`. `domain` imports no Flutter, Supabase or
Riverpod code. `data` implements `domain` interfaces. Features talk to each other only through
another feature's `domain` API. Screens (containers) read providers; widgets receive plain values
and callbacks.

Stack (for reference): Flutter 3.47.4, Dart 3.13, `material_ui`, Riverpod 3 + generator,
go_router 18, freezed 4, `supabase_flutter`, `very_good_analysis`, `mocktail`, gen-l10n (es).

## 7. Testing strategy

| Layer | Tool | What it proves | Runs in |
|-------|------|----------------|---------|
| Domain (Dart) | `flutter test` unit tests | Session planner, ladder, grading, hint policy, mastery, streaks (tables in learning-method.md) | `app-ci.yml` |
| Presentation | widget tests with provider overrides, `mocktail` | Screens render states, one primary action, copy | `app-ci.yml` |
| Flows | `integration_test` | Sign-up → paywall → session against a local stack | local / later CI |
| Database | pgTAP (`supabase/tests/database`) | RLS for every table, access truth table, triggers, content invariants, seed quality | `supabase-ci.yml` |
| Edge Functions | `deno test` (`supabase/functions/**/_test.ts`) | Signature verification, event mapping, CORS, validation, handler behavior with fakes | `supabase-ci.yml` |

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
  `supabase/functions/.env` locally. See [deployment.md](deployment.md).
