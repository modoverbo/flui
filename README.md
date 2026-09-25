# flui

**flui** is a Spanish-language communication trainer for adults: it helps people find better words and
use them naturally in real conversations. *"Habla como quieres sonar."*

Each day the user picks how much time they have (5, 10, 20 or 30 minutes). flui plans a session
(reviews first, then new words) and walks each word through **Descubre → Entiende → Mira → Elige →
Úsala** until it becomes *tuya*. Parent brand on social media: ModoVerbo.

## Monorepo layout

| Path | What lives there |
|------|------------------|
| `app/` | Flutter app (web first). Domain logic in pure Dart. See `app/README.md`. |
| `supabase/` | Postgres migrations, RLS, seed, pgTAP tests and the two Whop Edge Functions. |
| `docs/` | Architecture, brand, learning method, ADRs, deployment and research. |
| `.github/workflows/` | CI for app and Supabase, web deploy to Vercel, Supabase keep-alive. |

## Prerequisites

| Tool | Version | Used for |
|------|---------|----------|
| Flutter | 3.47.4 (Dart 3.13) | the app |
| Docker | Desktop or Engine | local Supabase stack, Deno tests |
| Node.js | 20+ (for `npx`) | Supabase CLI via `npx supabase@latest`, Vercel CLI |
| Deno | 2.x (optional) | Edge Function tests; can run through Docker instead |

## Quick start

### 1. Backend (Supabase, local)

```bash
npx supabase@latest start            # API http://127.0.0.1:54421, DB port 54422, Studio :54423
npx supabase@latest db reset         # applies migrations + seed (8 starter words, 2 plans)
npx supabase@latest test db          # pgTAP: RLS, access rules, seed invariants
```

Local ports are shifted by +100 from the Supabase defaults so flui can run next to other local
Supabase projects. `npx supabase@latest status` prints the local keys.

### 2. Edge Functions (Whop)

```bash
cp supabase/functions/.env.example supabase/functions/.env   # fill in Whop SANDBOX values
npx supabase@latest functions serve
cd supabase/functions && deno task ci                        # fmt, lint, type-check, tests
```

No Deno locally? `docker run --rm -v "$PWD/supabase/functions":/work -w /work denoland/deno:2.9.6 task ci`.

New users have no access until they start the Whop trial. Whop cannot call `localhost`, so for local
app work grant a dev entitlement with
[`supabase/snippets/grant_dev_entitlement.sql`](supabase/snippets/grant_dev_entitlement.sql) or use a
tunnel (see [deployment](docs/deployment.md#local-webhooks)).

### 3. App

```bash
cd app
flutter pub get
flutter run -d chrome --web-port 3000 --dart-define-from-file=config/local.json
```

`config/local.json` is git-ignored; copy it from `config/local.example.json`.

No backend at hand? Use `config/fake.json` (in-memory fake backend). To see the app on an Android
phone or emulator, see [app/README.md](app/README.md#on-a-phone-or-emulator).

## Documentation

| Doc | Read it when |
|-----|--------------|
| [Architecture](docs/architecture.md) | You need the system map, data model, flows or testing strategy. |
| [Learning method](docs/learning-method.md) | You implement session planning, grading, mastery, hints or streaks. |
| [Brand](docs/brand.md) | You write UI copy or content, or touch visual design. |
| [Deployment](docs/deployment.md) | You set up Supabase, Whop, Vercel or GitHub secrets. |
| [ADRs](docs/adr/) | You want to know why a decision was made. |
| [Research](docs/research/) | You want the evidence behind the product rules. |

## Conventions

- Code, identifiers, comments and docs: English. Product content and UI copy: neutral Spanish, "tú".
- Conventional commits. Tests first (TDD) for all logic.
- No secrets in the repository: only `*.example` files are committed.
