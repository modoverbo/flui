# flui app

Flutter app of flui (web first, Android and iOS scaffolded). Phase A ships the brand system,
onboarding, email/password auth, the Whop trial paywall, the checkout return flow and the app
shell. Phase B ships the learning experience: daily time budget, session planner, the session
runner (Descubre → Mira → Elige → Úsala → check), reviews, Palabras, Practica, En contexto and
Tu progreso. It runs fully offline with an in-memory **fake backend** or against **Supabase**.

## Quick path (fake backend, no network)

```bash
cd app
cp config/fake.example.json config/fake.json   # app/config/*.json is git-ignored
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
flutter run -d chrome --web-port 3000 --dart-define-from-file=config/fake.json
```

Walk it: Empezar → Saltar → create an account (any valid email, 8+ character password) →
Empezar prueba gratis → "Activando tu prueba…" → time budget → Hoy → Empezar (first word:
perspicaz) → session → Tu progreso.

| Fake backend behavior | Detail |
|-----------------------|--------|
| Sign in | Any valid email and password; a registered email must use its password |
| Plans | Same as `supabase/seed.sql` (monthly, quarterly with "Ahorra 17%") |
| Checkout | No redirect: grants a 7-day trial after one extra `my_access()` poll (webhook lag) |
| Content | The 8 words of `supabase/seed.sql`, generated into `lib/features/vocabulary/data/fake/seed_content.dart` |
| Learning data | Progress, attempts, daily sessions and streak repairs per user, in memory |
| State | In memory; a page reload starts signed out |

## Against local Supabase

```bash
npx supabase@latest start && npx supabase@latest db reset   # from the repo root
cp config/local.example.json config/local.json              # paste the local anon key
flutter run -d chrome --web-port 3000 --dart-define-from-file=config/local.json
```

New users have no access until a Whop trial starts; see the repo README for the dev entitlement
snippet or a webhook tunnel.

## Configuration

`--dart-define-from-file=config/<env>.json`, parsed by `lib/core/config/app_config.dart`.

| Key | Values | Notes |
|-----|--------|-------|
| `BACKEND` | `fake` \| `supabase` | Defaults to `supabase` (the deploy workflow only writes the two keys below) |
| `SUPABASE_URL` | absolute http(s) URL | Required for `supabase` |
| `SUPABASE_ANON_KEY` | publishable key | Required for `supabase` |
| `APP_URL` | absolute http(s) URL | Optional; redirect target of Supabase email links |

Only `*.example.json` files are committed. An invalid config shows a developer error screen.

## Commands

| Task | Command |
|------|---------|
| Code generation (freezed, json, riverpod) | `dart run build_runner build` (or `watch`) |
| Localizations (`lib/core/l10n/app_es.arb`) | `flutter gen-l10n` |
| Format check | `dart format --set-exit-if-changed lib test integration_test` |
| Analyze (very_good_analysis) | `flutter analyze` |
| Analyze + riverpod_lint | `dart analyze` (plugin diagnostics only appear here) |
| Unit and widget tests | `flutter test --coverage` |
| Integration flow (headless) | `flutter test integration_test -d flutter-tester` |
| Web release build | `flutter build web --release --dart-define-from-file=config/fake.json` |
| Brand SVGs and web icons | see the header of `tool/generate_brand_assets.mjs` |
| Fake content from the seed | `dart run tool/seed_to_fixture.dart` (a test fails when it drifts) |
| Android/iOS launcher icons | `dart run flutter_launcher_icons` |

Generated files (`*.g.dart`, `*.freezed.dart`, `lib/core/l10n/gen/`) are **not committed**; CI
regenerates them before formatting, analyzing and testing.

## Structure

```text
lib/
  main.dart, bootstrap.dart   # config → backend overrides → ProviderScope → FluiApp
  app/                        # FluiApp, go_router (routes, pure redirect), shell, splash, licenses
  core/                       # config, error (Result, Failure), clock, theme, l10n, supabase client
  shared/widgets/             # FluiSymbol, FluiLogo, FluiButton, FluiCard, FluiTextField, ...
  features/
    auth/ subscription/       # domain (pure Dart) · data (Supabase + fake) · presentation
    onboarding/               # welcome, intro
    daily/                    # time budget, SessionPlanner, SessionFlow, Hoy, session runner
    vocabulary/               # words, progress, ReviewScheduler, MasteryPolicy, Palabras
    exercises/                # cloze flow, form recall, production, attempts, Practica
    reading/                  # readings, En contexto
    profile/                  # streaks and repairs, stats, achievements, Tu progreso
```

- **Dependency rule:** `presentation → domain ← data`. Domain imports no Flutter, Supabase or
  Riverpod. `bootstrap.dart` is the only place that picks data implementations.
- **Screens** are containers that read providers; shared widgets take plain values and callbacks.
- **Routing guard:** `app/router/app_redirect.dart` is a pure function of auth status, access gate
  and location, unit-tested as a truth table. The splash keeps `?from=` so `/checkout/return`
  survives a reload.

## Decisions

| Topic | Decision |
|-------|----------|
| Material | `package:material_ui` (Flutter 3.47 standalone). Localizations use material_ui's `GlobalMaterialLocalizations.delegates`. No dependency exposes legacy Material types, so `MaterialUiCompatibilityBridge` is not needed. |
| State | Riverpod 3 with code generation. Automatic retry is disabled (`ProviderScope(retry:)`): failures are typed and shown. Access is keyed by user id to avoid stale sessions. |
| Lints | very_good_analysis 11, including the Dart 3.13 `new` / `factory name` constructor style. `public_member_api_docs` is off (app, not package). `invalid_annotation_target` is ignored as freezed documents for `@JsonSerializable` on factories. |
| Icons | `flutter_lucide` (one font, tree-shaken). `lucide_icons_flutter` also ships six weight fonts (~2.7 MB) that web would download at startup. |
| Fonts | Static OFL TTFs, only the weights in the type scale: Plus Jakarta Sans 700/800, Inter 400/600. Licenses are registered with `LicenseRegistry`. |
| Logo | Three waves derived from Tabler Icons `ripple` (MIT): thicker strokes, left-to-right phase offset, calmer lower waves. `FluiSymbolGeometry` and the SVG assets share numbers; a test keeps them in sync. |
| Web | Path URL strategy, SPA rewrite and revalidating cache headers in `vercel.json` (no COOP/COEP), branded loading splash in `web/index.html`. CanvasKit loads from Google's CDN by default. |
| Google sign-in | Visible, disabled button with a `TODO(auth)`; not in Phase A. |

## Learning rules

`docs/learning-method.md` is the spec; the rules are pure Dart under `features/*/domain` with
table-driven tests. Interpretations where the spec leaves room:

| Topic | Choice |
|-------|--------|
| Preselected budget | Today's choice, else the latest earlier session ("yesterday", also after a skipped day), else 10 min |
| Warm-up | Up to 2 planned due reviews whose last grade was `good` go first; no extra items |
| Introduced word | `word_progress` row on leaving Descubre, `next_due_on = today + 1` so an abandoned session still brings it back |
| Form recall prompt | The example sentence with the word masked; typo tolerance (1 edit) only for forms of 6+ letters |
| Úsala situation | "Antes decías: «first `replaces.before`»" |
| Re-queue | Forced reveal → once per word with an unused sentence; a first-try re-queue of a `nueva` word counts as its unaided check |
| Resume | Rebuilt from `word_progress` and today's `exercise_attempts`; pending re-queues are not restored; forced reveals count per local day |
| Daily guard | Without today's `daily_sessions` row, app routes go to `/today/time`; `/progress` stays reachable |

## Phase B entry points (for later phases)

| Need | Use |
|------|-----|
| Learning data of the user | `learningDataControllerProvider(userId)` (writes go through it), `currentLearningDataProvider` |
| Session runner | `/session` (`?mode=review` for Practica), `SessionController`, `SessionFlow` |
| Content | `catalogProvider`, `wordsByIdProvider` |
| Signed-in user / access | `authUserProvider`, `currentAccessProvider`, `accessGateProvider` |
| Supabase client in data sources | `supabaseClientProvider` (override set in `bootstrap.dart`) |
| Today's local date | `clockProvider` → `clock.today()`; `FixedClock` in tests |
| Errors | return `Result<T>`, map with `failureMessage(l10n, failure)`; add `Failure` subtypes as needed |
| UI | `shared/widgets/` (buttons, cards, `StateChip`, `StatTile`, `FluiProgressBar`, `EmptyState`, `LoadingWave`) and `core/theme/` tokens |
| Tests | `test/helpers/`: `createTestContainer`, `pumpFlui`, `pumpRoutedPage`, `AppHarness` and `runFirstRunFlow` in `integration_test/support/` (shared with the VM tests) |
