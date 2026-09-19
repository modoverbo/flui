# 00 — Current UI Map

Phase 0 inventory of every route, screen, shared widget, and design token in the app today, with file paths, as input to the redesign. Compiled by reading the router, shell, feature `presentation/` folders, `shared/widgets`, `shared/motion`, and `core/theme` directly (Flutter 3.47.4, Dart 3.13.3, `material_ui`, Riverpod 3 + codegen, go_router 18, freezed 4).

Dependency rule in force everywhere: `presentation → domain ← data`; domain is pure Dart (no Flutter/Supabase/Riverpod imports). The redesign must not break this.

## 1. Routes

All paths in `app/lib/app/router/app_routes.dart`; wiring in `app/lib/app/router/app_router.dart`; guard chain in `app/lib/app/router/app_redirect.dart`; transitions in `app/lib/app/router/flui_transitions.dart`.

| Path | Screen | File | Shell? | Transition |
|---|---|---|---|---|
| `/`, `/splash` | `SplashPage` | `app/lib/app/pages/splash_page.dart` | outside | — |
| `/welcome` | `WelcomePage` | `features/onboarding/presentation/welcome_page.dart` | outside | default |
| `/intro` | `IntroPage` | `features/onboarding/presentation/intro_page.dart` | outside | sharedAxisX |
| `/plan` | `PlanPreviewPage` | `features/subscription/presentation/pages/plan_preview_page.dart` | outside | sharedAxisX |
| `/login` | `LoginPage` | `features/auth/presentation/pages/login_page.dart` | outside | default |
| `/register` | `RegisterPage` | `features/auth/presentation/pages/register_page.dart` | outside | sharedAxisX |
| `/reset-password` | `PasswordResetPage` | `features/auth/presentation/pages/password_reset_page.dart` | outside | default |
| `/paywall` | `PaywallPage` | `features/subscription/presentation/pages/paywall_page.dart` | outside | default |
| `/checkout/return` | `CheckoutReturnPage` | `features/subscription/presentation/pages/checkout_return_page.dart` | outside | default |
| `/session?mode=review\|free` | `SessionPage` | `features/daily/presentation/session_page.dart` | **outside shell**, root navigator | sharedAxisZ (scale-in, "a different place") |
| `/speaking/challenge` | `SpeakingChallengePage` | `features/speaking/presentation/speaking_challenge_page.dart` | **outside shell**, root navigator | sharedAxisZ |
| `/today` (tab 0) | `TodayPage` | `features/daily/presentation/today_page.dart` | shell | shell default |
| `/today/time` | `TimeBudgetPage` | `features/daily/presentation/time_budget_page.dart` | outside shell (root navigator) | default |
| `/words` (tab 1) | `WordsPage` | `features/vocabulary/presentation/words_page.dart` | shell | shell default |
| `/words/:wordId` | `WordDetailPage` | `features/vocabulary/presentation/word_detail_page.dart` | shell | default |
| `/progress` (tab 2) | `ProgressPage` | `features/profile/presentation/progress_page.dart` | shell | shell default |
| `/practice`, `/reading` | — | retired, redirect to `/today`, `/words` (`AppRoutes.retiredRoutes`) | — | — |

Guard chain (`app_redirect.dart`, pure function, unit-tested): `AuthStatus → AccessGate → DailyGate`. Unknown state parks on `/splash?from=...`. Signed-out restricted to public routes else `/welcome`. Signed-in without access restricted to paywall-free routes else `/paywall`. Signed-in with access, on a route in `AppRoutes.needsDailyBudget` (today, session, words, word detail), redirected to `/today/time` until `DailyGate.needsBudget` resolves.

**Finding — speaking is not part of the daily `SessionFlow`.** `/speaking/challenge` is a fully independent full-screen route, not one of the 9 `SessionStep` variants inside `SessionFlow`. The core loop's "speak" stage currently lives outside the reviewed/spaced daily session entirely. This constrains the navigation model (02) and speaking spec (04): the redesign can either graft speaking into `SessionFlow` as a new step type, or keep it a standalone surface reached from its own nav entry. See `02-navigation-model.md` for the decision.

## 2. Shell

`app/lib/app/shell/` — `AppShell` wraps go_router's `StatefulNavigationShell` with 3 branches (today / words / progress), handed to `AppShellScaffold`. Below `FluiBreakpoints.rail` (600px): `NavigationBar` pill, rounded 28, ink background, acid-lime indicator. Above `FluiBreakpoints.extendedRail` (1024px): extended `NavigationRail`. Between: compact rail. Destination glyphs (`FluiGlyph`, custom SVG, 22px): today → `onda`, words → `wordOfTheDay`, progress → `streak`. Code comment: "was five tabs, now three" — Practica merged into Hoy, En contexto merged into word detail. `docs/brand.md` still documents the older 5-tab nav (**Hoy, Palabras, Practica, En contexto, Tu progreso**) and separately notes **Habla** as a planned future tab — confirms the task's target nav (Hoy/Palabras/Habla/Progreso) is the intended next step, not a fresh invention.

## 3. Screens by feature — core loop vs. support

**Core loop** (discover → understand → choose → use → speak → feedback → retry, per the founder's brief; canonical in-app naming is **Descubre → Entiende → Mira → Elige → Úsala** + end-of-session check, per `docs/brand.md` and `docs/learning-method.md`):

| Screen | File | Role in loop |
|---|---|---|
| `TodayPage` | `features/daily/presentation/today_page.dart` | entry point, daily plan, streak, theme picker access |
| `TimeBudgetPage` | `features/daily/presentation/time_budget_page.dart` | pre-session setup (budget + theme) |
| `SessionPage` | `features/daily/presentation/session_page.dart` | runs the full loop, step by step, via `SessionFlow` |
| `WordsPage` | `features/vocabulary/presentation/words_page.dart` | catalogue browse / discover surface outside a session |
| `WordDetailPage` | `features/vocabulary/presentation/word_detail_page.dart` | standalone discover/understand view; `WordDetailView` inside it is reused by `SessionPage`'s `DiscoverStep` |
| `SpeakingChallengePage` | `features/speaking/presentation/speaking_challenge_page.dart` | the "speak" stage — currently standalone, not fed by `SessionFlow` |
| `ProgressPage` | `features/profile/presentation/progress_page.dart` | feedback/reflection surface — a target nav tab, but not part of the moment-to-moment loop |

**Support** (onboarding, auth, paywall, settings-adjacent):

| Screen | File |
|---|---|
| `SplashPage` | `app/lib/app/pages/splash_page.dart` |
| `WelcomePage` | `features/onboarding/presentation/welcome_page.dart` |
| `IntroPage` | `features/onboarding/presentation/intro_page.dart` |
| `LoginPage` / `RegisterPage` / `PasswordResetPage` | `features/auth/presentation/pages/*.dart` |
| `PlanPreviewPage` / `PaywallPage` / `CheckoutReturnPage` | `features/subscription/presentation/pages/*.dart` |

**No standalone page today**: `exercises/` (only widgets consumed inside `SessionPage`), `reading/` (only widgets consumed inside `SessionPage`/`TodayPage`), `themes/` (`ThemeChoiceCard`, `ThemeExplorerSheet` — a picker sheet used from `TimeBudgetPage`, no dedicated route).

## 4. `SessionFlow` — the engine behind the core loop

`features/daily/domain/session_flow.dart`, class `SessionFlow` (`@immutable final class`, pure domain, no Flutter imports).

- State: `steps` (unmodifiable `List<SessionStep>`), `index` (cursor), `current => steps[index]`, `isFinished => index >= steps.length`, `guard` (`SessionFrustrationGuard`), `seeding` (reading-only fallback after 3 forced reveals), `postponedWordIds`.
- `SessionStep` (`features/daily/domain/session_step.dart`) is a `@freezed sealed class`, 8 variants: `ReviewClozeStep`, `DiscoverStep`, `ReadingsStep`, `PracticeClozeStep`, `FormRecallStep`, `ProductionStep`, `FinalCheckStep`, `RequeueClozeStep`, `SeedingReadingStep`. Each maps 1:1 to a widget rendered by `SessionPage`'s `_StepContent`.
- Advancing is immutable and user-driven only: `completeStep()` / `completeCloze(ClozeResolution)` both return a **new** `SessionFlow` at `index + 1`. No timer, no auto-advance — always a `FluiButton.onPressed` or option-tap.
- `SessionController` (`features/daily/presentation/controllers/session_controller.dart`, Riverpod `@riverpod` class, `Future<SessionState> build(SessionMode)`) is the only thing screens talk to; `SessionState.step/word/cloze/formRecall/production` are getters over `flow.current`.
- `_StepContent` switches on `step.runtimeType`, keyed `ValueKey('${flow.index}-${step.runtimeType}')` — this is the natural per-card identity hook for `03-card-stack-spec.md`.
- Lookahead is free: `state.flow.steps.skip(state.flow.index)` yields every upcoming step in order — the direct feed for a 3-deep card stack.

## 5. Design tokens (`app/lib/core/theme/`)

| File | Exposes |
|---|---|
| `flui_type_scale.dart` | `FluiTypeScale` (compact/wide), `FluiTypeRole` (8 roles), `FluiFonts` |
| `flui_spacing.dart` | spacing scale, block/section gaps, content/page max-width, `FluiBreakpoints` |
| `flui_radii.dart` | chip/cta/card/plate/pill radii |
| `flui_motion.dart` | durations, curves, named motion constants, `FluiMotion.reduced/resolve` |
| `flui_surfaces.dart` | hairline borders, the one app-wide shadow (`ctaDockShadow`) |
| `flui_color_rules.dart` | `FluiColorRules` — static tested table of readable/border/forbidden `ColorPair`s, `aaText`/`aaLargeText` thresholds, `YellowRole` |
| `flui_colors.dart` | **two overlapping palettes** — see `01-design-system.md` §0 |
| `flui_layout.dart` | `FluiFormFactor`, 12-col grid |
| `flui_theme.dart` | `ThemeData` builders (`light()`, `progressSurface()`) |
| `contrast.dart` | `contrastRatio(a, b)` — WCAG relative-luminance ratio |

Full values are catalogued in `01-design-system.md`; this file only inventories what exists.

## 6. Shared widgets (`app/lib/shared/widgets/`)

`bento_grid.dart` (`BentoGrid`, `BentoTile`), `choice_chips.dart` (`ChoiceChips<T>`, `ExpandableChip`), `empty_state.dart` (`EmptyState`), `flui_button.dart` (`FluiButton`), `flui_card.dart` (`FluiCard`), `flui_glyph.dart` (`FluiGlyphIcon`), `flui_label.dart` (`FluiLabel`, `SectionHeader`, `PageHeader`), `flui_logo.dart` (`FluiLogo`), `flui_notice.dart` (`FluiNotice`), `flui_plate.dart` (`FluiPlate`, `PlateWaveMark` — pre-baked WebP + painted wave field, **explicitly not a live shader today**), `flui_progress_bar.dart` (`FluiProgressBar`, `FluiProgressDots`), `flui_symbol.dart` (`FluiSymbol`, `FluiWave` — current 3-wave logo mark), `flui_text_field.dart`, `headline_text.dart`, `loading_wave.dart`, `page_frame.dart` (`PageFrame`, `PageSection`), `split_hero.dart` (`SplitHero`), `state_chip.dart` (`StateChip`), `sticky_cta_dock.dart` (`StickyCtaDock`).

## 7. Shared motion (`app/lib/shared/motion/`)

`feedback_motion.dart` (`DrawUnderline` 220ms, `ShakeBox` 260ms/3 cycles), `reveal_lines.dart` (`RevealLines`, 40ms stagger), `section_entrance.dart` (`SectionEntrance`, via `flutter_animate`, deliberately confined to one file — package is "stable but dormant upstream"). All three honor `FluiMotion.reduced(context)` by snapping to end-state.

## 8. Feature-by-feature widget inventory

| Feature | Presentation files (non-page) |
|---|---|
| `daily/` | `widgets/budget_choice_card.dart`, `widgets/session_summary_view.dart`, `controllers/session_controller.dart`, `controllers/time_budget_controller.dart`, `providers/daily_providers.dart`, `providers/learning_data_controller.dart`, `providers/today_overview.dart` |
| `vocabulary/` | `widgets/word_detail_view.dart`, `widgets/mastery_meter_view.dart`, `widgets/highlighted_text.dart`, `word_state_kind.dart` |
| `exercises/` | `widgets/cloze_view.dart`, `widgets/form_recall_view.dart`, `widgets/production_view.dart` |
| `reading/` | `widgets/readings_carousel.dart`, `widgets/reading_card.dart` |
| `profile/` | `widgets/achievement_tile.dart`, `widgets/week_dots.dart`, `subscription_summary.dart` |
| `subscription/` | `widgets/paywall_flow.dart`, `widgets/plan_card.dart`, `widgets/trial_timeline.dart` |
| `themes/` | `presentation/widgets/theme_choice_card.dart`, `presentation/widgets/theme_explorer_sheet.dart` |
| `speaking/` | `presentation/widgets/voice_orb.dart` (already amplitude-reactive `CustomPainter`), `presentation/widgets/speaker_cue_cards.dart`, `presentation/providers/speaking_providers.dart` |

`speaking/` is a full clean-architecture slice (`domain/speech_recorder.dart`, `domain/speech_analysis_repository.dart`, `domain/speech_transcript.dart`, `domain/speaking_metrics.dart`, `domain/speaking_feedback.dart`, `domain/speech_analyzer.dart`; `data/record_speech_recorder.dart`, `data/http_speech_analysis_repository.dart`, `data/supabase_speech_analysis_repository.dart`, `data/fake_speech_analysis_repository.dart`) — see `04-speaking-spec.md` for the full flow. It is **not** listed in `docs/architecture.md`'s feature folder list yet (that doc predates it).
