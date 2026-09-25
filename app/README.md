# flui app

Flutter app of flui (web first, Android and iOS scaffolded). Phase A ships the brand system,
onboarding, email/password auth, the Whop trial paywall, the checkout return flow and the app
shell. Phase B ships the learning experience: daily time budget, session planner, the session
runner (Descubre → Mira → Elige → Úsala → check), reviews and three tabs — **Hoy**, **Palabras**
and **Tu progreso**. It runs fully offline with an in-memory **fake backend** or against
**Supabase**.

## Quick path (fake backend, no network)

```bash
cd app
cp config/fake.example.json config/fake.json   # app/config/*.json is git-ignored
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
flutter run -d chrome --web-port 3000 --dart-define-from-file=config/fake.json
```

Walk it: Empezar → two questions and one real word (or Saltar) → your plan, the trial
timeline and the prices (no account yet) → Crear mi cuenta (any valid email, 8+ character
password) → Empezar prueba gratis → "Activando tu prueba…" → time budget → Hoy →
Empezar (first word: perspicaz) → session → Tu progreso.

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

## On a phone or emulator

Fastest loop for layout work: run on Chrome (see above) and toggle DevTools' device toolbar
(`Ctrl+Shift+M`). Use a real phone to judge touch, voice and performance.

### Android phone over USB (no Android Studio needed)

1. On the phone, enable **Developer options** → **USB debugging**, then plug it in.
2. Accept the **"Allow USB debugging?"** prompt on the phone (tick "Always allow").
   `adb devices` must list it as `device`; `unauthorized` means the prompt was not accepted yet
   (replug, or revoke USB debugging authorizations and replug).
3. Run it:

   ```bash
   flutter devices                                   # copy the phone's device id
   flutter run -d <device-id> --dart-define-from-file=config/fake.json
   ```

Press `r` for hot reload, `R` for hot restart, `q` to quit. Run `flutter run` from your own
terminal: hot reload needs its stdin.

| Gotcha | Fix |
|--------|-----|
| First build takes ~4 min | Gradle downloads its dependencies and may install missing build-tools; later builds are much faster |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | An install signed with another key exists; Flutter uninstalls it (its data is lost) and retries |
| Fake backend state is gone on relaunch | Expected: it lives in memory |
| Local Supabase unreachable from the phone | `127.0.0.1` is the phone itself; run `adb reverse tcp:54421 tcp:54421` before `flutter run` with `config/local.json` |

### Android emulator

Needs hardware acceleration: your user must be in the `kvm` group
(`sudo usermod -aG kvm $USER`, then log out and back in). Then:

```bash
flutter emulators                                 # list AVDs
flutter emulators --launch <avd-id>
flutter run -d emulator-5554 --dart-define-from-file=config/fake.json
```

The Supabase config works unchanged on the emulator through `adb reverse` as above.

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
| Custom glyphs | `node tool/generate_glyphs.mjs` |
| Green texture plates | see the header of `tool/generate_texture_plates.mjs` (needs `sharp`) |
| Android/iOS launcher icons | `dart run flutter_launcher_icons` |

Generated files (`*.g.dart`, `*.freezed.dart`, `lib/core/l10n/gen/`) are **not committed**; CI
regenerates them before formatting, analyzing and testing.

## Structure

```text
lib/
  main.dart, bootstrap.dart   # config → backend overrides → ProviderScope → FluiApp
  app/                        # FluiApp, go_router (routes, pure redirect), shell, splash, licenses
  core/                       # config, error (Result, Failure), clock, theme, l10n, supabase client
  shared/
    layout/                   # bento packing, section rhythm (pure, tested)
    motion/                   # RevealLines, DrawUnderline, ShakeBox, SectionEntrance
    widgets/                  # FluiPlate, BentoGrid, StickyCtaDock, SplitHero, PageFrame,
                              # FluiGlyphIcon, FluiButton, FluiCard, FluiLabel, ...
  features/
    auth/ subscription/       # domain (pure Dart) · data (Supabase + fake) · presentation
    onboarding/               # welcome, the two questions, the pre-signup micro-lesson
    daily/                    # time budget, SessionPlanner, SessionFlow, Hoy, session runner
    vocabulary/               # words, progress, ReviewScheduler, MasteryPolicy/Meter, Palabras
    exercises/                # cloze flow, form recall, production with its rubric, attempts
    reading/                  # readings, the "En contexto" sections
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
| Design system | `core/theme/`: `FluiTypeScale` (8 roles, compact/wide), `FluiSpacing` (one scale, one content max-width policy), `FluiRadii` (14 px CTA, never a pill), `FluiSurfaces` (hairlines, one shadow), `FluiMotion`, `FluiColorRules`. Screens read `context.type` / `context.layout`; no screen calls `MediaQuery` for sizing. |
| Icons | `flutter_lucide` (one font, tree-shaken) plus ten custom SVG glyphs on the wave motif (`assets/icons`, `tool/generate_glyphs.mjs`), rendered with `flutter_svg`. `lucide_icons_flutter` also ships six weight fonts (~2.7 MB) that web would download at startup. Three icon sizes only: 22 / 20 / 18. |
| Texture | One green plate, pre-baked WebP at 1x/2x/3x (`tool/generate_texture_plates.mjs`). A live fragment shader would cost a first-frame stall on CanvasKit for a background that never moves. |
| Motion | `flutter_animate` 4.5.2 for the one declarative section entrance (stable but dormant upstream since Nov 2024, so it is confined to `shared/motion/section_entrance.dart`); `animations` 3.0.0 for shared-axis route transitions; everything else is a plain `AnimationController`. Reduce-motion is honoured through `FluiMotion.resolve`. |
| Fonts | Static OFL TTFs, only the weights in the type scale: Plus Jakarta Sans 600/700/800, Inter 400/600. Licenses are registered with `LicenseRegistry`. |
| Logo | Three waves derived from Tabler Icons `ripple` (MIT): thicker strokes, left-to-right phase offset, calmer lower waves. `FluiSymbolGeometry` and the SVG assets share numbers; a test keeps them in sync. |
| Web | Path URL strategy, SPA rewrite and revalidating cache headers in `vercel.json` (no COOP/COEP), branded loading splash in `web/index.html`. CanvasKit loads from Google's CDN by default. |
| Google sign-in | Visible, disabled button with a `TODO(auth)`; not in Phase A. |
| Pre-signup paywall | `/plan` shows the real `subscription_plans` prices before the account exists (`anon` can read active plans). The chosen plan is kept on the device, so `/paywall` opens straight on the decision after sign-up instead of repeating the pitch. |
| Onboarding answers | Two questions before the account, kept in `shared_preferences` (`OnboardingStore`). A `TODO(flui)` marks the move to an `onboarding_answers` table; inventing the schema before the questions settle would migrate it twice. |
| Trial reminder | `FluiFeatures.trialReminder` is **off**: there are no notifications or reminder emails yet, so the paywall's day-5 line promises only what "Tu progreso" already shows. |
| Rive / Lottie | Not used. Rive community files are CC BY and the LottieFiles free plan is non-commercial for authoring, and both need asset authoring we have not scoped. `TODO` left for a separate decision. |

## Learning rules

`docs/learning-method.md` is the spec; the rules are pure Dart under `features/*/domain` with
table-driven tests. Interpretations where the spec leaves room:

| Topic | Choice |
|-------|--------|
| Preselected budget | Today's choice, else the latest earlier session ("yesterday", also after a skipped day), else 10 min |
| Warm-up | Up to 2 planned due reviews whose last grade was `good` go first; no extra items |
| Session order | Warm-up reviews, then one **blocked** acquisition run per new word (Descubre, one scene, Elige) with the remaining due reviews between the runs, then the form recalls, the held-back scenes, the productions, and a mixed end-of-session check in a per-day order. Acquisition is never interleaved: interleaving hurts vocabulary material (Brunmair & Richter 2019); see the `SessionFlow` doc comment |
| Introduced word | `word_progress` row on leaving Descubre, `next_due_on = today + 1` so an abandoned session still brings it back |
| Form recall prompt | The example sentence with the word masked; typo tolerance (1 edit) only for forms of 6+ letters |
| Úsala situation | "Antes decías: «first `replaces.before`»" |
| Re-queue | Forced reveal → once per word with an unused sentence; a first-try re-queue of a `nueva` word counts as its unaided check |
| Resume | Rebuilt from `word_progress` and today's `exercise_attempts`. Every step is done only on its **own** evidence (a row for Descubre, an attempt for a cloze, `form_recall_done`, `production_done`) or when a later step of the same word is; pending re-queues are not restored; forced reveals count per local day |
| Empty day | The planner says *why* (`EmptyPlanReason`): too small a budget, no candidates left, or every candidate still too close to this week's words. Each gets its own copy and its own way out |
| Active day | Opening a session marks the day active, even with an empty plan: the gap is ours, not the user's |
| Free run | `/session?mode=free` practises words that are **not** due. Attempts are recorded; the ladder is untouched |
| Visible progress | The three states are coarse, so `MasteryMeter` shows five rungs per word (descubierta → practicada → recall → producción → tuya), and precision is a rolling 30-day window |
| Daily guard | Without today's `daily_sessions` row, app routes go to `/today/time`; `/progress` stays reachable |

## Phase B entry points (for later phases)

| Need | Use |
|------|-----|
| Learning data of the user | `learningDataControllerProvider(userId)` (writes go through it), `currentLearningDataProvider` |
| Session runner | `/session` (`?mode=review` for "Repaso extra", `?mode=free` for "Repaso libre"), `SessionController`, `SessionFlow` |
| Content | `catalogProvider`, `wordsByIdProvider` |
| Signed-in user / access | `authUserProvider`, `currentAccessProvider`, `accessGateProvider` |
| Supabase client in data sources | `supabaseClientProvider` (override set in `bootstrap.dart`) |
| Today's local date | `clockProvider` → `clock.today()`; `FixedClock` in tests |
| Errors | return `Result<T>`, map with `failureMessage(l10n, failure)`; add `Failure` subtypes as needed |
| UI | `shared/widgets/` (buttons, cards, `StateChip`, `StatTile`, `FluiProgressBar`, `EmptyState`, `LoadingWave`) and `core/theme/` tokens |
| Tests | `test/helpers/`: `createTestContainer`, `pumpFlui`, `pumpRoutedPage`, `AppHarness` and `runFirstRunFlow` in `integration_test/support/` (shared with the VM tests) |
