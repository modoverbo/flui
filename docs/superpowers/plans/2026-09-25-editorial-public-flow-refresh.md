# Editorial Public Flow Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refresh the public welcome, six-step onboarding, and pre-signup plan flow into a restrained editorial UI without changing answers, routes, subscription facts, persistence, or authentication behavior.

**Architecture:** Keep presentation changes in the existing onboarding and subscription presentation owners, using existing Flui theme, layout, motion, and semantic primitives after auditing their actual values. Preserve current providers, domain types, route owners, catalog, and persistence; make no backend or route changes.

**Tech Stack:** Flutter/Dart, Riverpod, go_router, Flutter widget tests, existing Flui design/motion tokens and localization.

**Spec:** `docs/superpowers/specs/2026-09-25-editorial-public-flow-refresh-design.md`

## Global Constraints

- Preserve public `/welcome`, `/intro`, `/plan`, `/register`, signed-in `/paywall`, and their existing route/access owners.
- Keep the six onboarding steps and order; preserve `Set<Scene>` multi-select, nullable `SpeakingTone` single-select, through-store writes, micro-lesson correctness/retry behavior, and completion gate.
- Keep plan summary, trial explanation, and plan choice in the existing `/plan` sequence; plan prices and claims come only from the existing catalog/logic, and plan choice keeps its existing persistence and registration handoff.
- Preserve current localized trial, reminder, price, billing, and cancellation wording and backend-provided facts exactly; do not add or infer commercial terms.
- Category decks and word cards remain exclusively in signed-in Inicio/catalog. Do not change `/today/time`, `/today`, category recommendations, or their behavior.
- Before the first visual source write, audit `app/lib/core/theme/` and `docs/brand.md`; reconcile with actual tokens and the approved paper/ink/deep-green/sparse-yellow direction. Do not use `docs/redesign/01-design-system.md` as authoritative palette evidence. Task 1 owns this checkable audit step.
- Prefer existing SVG, glyph, and code-native geometry. Do not add raster art by default; if visual proof shows a specific unmet need, generate and review that asset before integration. Add no UI/animation dependency, component framework, token layer, analytics, feature flag, backend behavior, or generated source.
- Keep code and technical documentation in English; any new UI copy must be neutral Spanish using `tú`. Retain existing localization keys/copy unless separately approved; do not hard-code new legal or commercial copy.
- TDD is strict: every behavior/layout unit follows an observed RED → GREEN → REFACTOR cycle before its work-unit commit.
- Preserve reduced motion with `MediaQuery.disableAnimationsOf` / `FluiMotion.resolve`; target durations are benefit transition 220 ms, progress 180 ms, choice-card selection 160 ms, and plan-card selection 160 ms, with no new timeline animation feature.
- Keep controls keyboard/touch usable, visible focus, meaningful progress/selection semantics, logical reading order, at least 44 logical-pixel targets where feasible, WCAG AA contrast (4.5:1 normal text; 3:1 large text and essential boundaries/focus), and scrollable content that is not obscured by the dock.
- Test the public UI with the fake backend. Do not require remote credentials, change backend data, or run remote operations.
- Receipt-driven development (RDD/native review) is disabled for this work. Do not invoke RDD, native review, or review-mode commands.
- Planning performs no install, interaction, or other action on a physical device. The Android API 36 emulator is required for final visual proof. At execution, install/run/interact with the physical TECNO CM5 only after explicit authorization names both that target and the operation; if that authorization is not available, record the phone proof as pending rather than acting.
- Work directly on `main` only after implementation is authorized; make one Conventional Commit per task. Do not create a worktree, PR, push, or commit this plan.

## Review Focus

- **No context chosen:** the context step must keep Continue disabled until one `Scene` is selected, and deselecting the last one must disable it again. Pin this in Task 3's gate widget test.
- **Multi-select confused with exclusive selection:** selecting a second context must retain the first, while selecting a tone replaces the previous tone. Pin both assertions in Task 3's selection-semantics test.
- **Incorrect or retried lesson answer:** a wrong option must not unlock Continue; retrying with the correct option must unlock it and preserve the existing feedback. Pin in Task 3's micro-lesson test.
- **Missing or partial personalization:** the plan summary must use the existing anonymous/general fallback for absent values and reflect only actually saved context/tone values. Pin in Task 4's summary test.
- **Commercial facts drift:** reminder-off copy must remain honest and visible, while displayed catalog price/interval/savings facts must match the supplied plans. Pin reminder/disclosure assertions in Task 5 and catalog assertions in Task 6.

---

## File Map

| File | Responsibility in this plan |
|---|---|
| `app/lib/features/onboarding/presentation/welcome_page.dart` | Restyle `WelcomeView` only; retain `WelcomePage` callbacks and the start/sign-in routes. |
| `app/lib/features/onboarding/presentation/intro_page.dart` | Restyle the six existing `OnboardingStep` states and progression UI; retain current answer and lesson state owners and `/plan` navigation. |
| `app/lib/features/onboarding/presentation/widgets/onboarding_questions.dart` | Restyle current `ContextsQuestion` and `ToneQuestion` options while retaining existing labels and selection meaning. |
| `app/lib/features/onboarding/presentation/widgets/micro_lesson_view.dart` | Make the existing lesson visually continuous with the editorial intro; retain the current exercise, feedback, retries, and success signal. |
| `app/lib/features/subscription/presentation/widgets/paywall_flow.dart` | Restyle the existing preview summary, trial step, dock, and plan-choice composition; retain preview/checkout modes and their distinct finish callbacks. |
| `app/lib/features/subscription/presentation/widgets/trial_timeline.dart` | Refine the existing three-node line's readability/emphasis without adding a new timeline animation feature or changing node copy. |
| `app/lib/features/subscription/presentation/widgets/plan_card.dart` | Present catalog-backed plan data in comparable editorial cards with explicit selected state; preserve current price formatting and claims. |
| `app/test/features/onboarding/welcome_page_test.dart` | Welcome rendering, action routes, and responsive/dock coverage. |
| `app/test/features/onboarding/intro_page_test.dart` | Benefit progression, answer selection, lesson gate, persistence, and responsive/reduced-motion coverage. |
| `app/test/features/subscription/presentation/paywall_page_test.dart` | Preview/checkout behavior, summary, trial disclosure variants, catalog plan facts/selection, and handoff coverage. |

`app/lib/app/router/app_routes.dart`, `app/lib/app/router/app_router.dart`, onboarding domain/providers/store, subscription domain/catalog/provider, localization ARBs, `/register`, signed-in routes, and `docs/brand.md` are read-only inputs unless later implementation evidence identifies a concrete missing requirement; do not modify them as part of this plan by default. No generated files are planned.

## Task-Closure Verification

Run these four commands after **each task**, from `app/`, and record each observed result before committing that task. A task is not complete until its focused RED/GREEN/REFACTOR cycle and all four closure checks are recorded.

- **C1 — formatting check:** `dart format --set-exit-if-changed lib test integration_test` — expected PASS with no files requiring formatting.
- **C2 — analysis:** `flutter analyze && dart analyze` — expected PASS with no analyzer errors.
- **C3 — full app/widget suite:** `flutter test` — expected PASS.
- **C4 — integration suite:** `flutter test integration_test -d flutter-tester` — expected PASS.

If a check fails, record its exact output and do not report it as passed. Do not waive a failure merely because another task or the base branch passes.

## Tasks

### Task 1: Restyle the public welcome screen

**Files:**
- Modify: `app/lib/features/onboarding/presentation/welcome_page.dart`
- Test: `app/test/features/onboarding/welcome_page_test.dart`

**Interfaces:**
- Consumes: `WelcomeView(onStart, onSignIn)`, current `context.l10n` welcome strings, existing `FluiColors`, `PageFrame`, `StickyCtaDock`, `FluiLogo`, and existing proof assets/primitives.
- Produces: editorial welcome presentation only; callbacks continue to be invoked as before by `WelcomePage` (`/intro` and existing login route).

- [ ] **Step 1: Audit the existing theme and brand sources before source edits.** Inspect actual tokens in `app/lib/core/theme/` and `docs/brand.md`, record the token mapping for paper/ink/deep green/sparse yellow and the readable text/focus pairings, and disregard conflicting prose in `docs/redesign/01-design-system.md`. If the approved direction cannot be expressed with existing tokens without inventing values, stop and report that gap before writing visual code.
- [ ] **Step 2: Add a failing welcome presentation test** asserting the audited editorial treatment, existing headline/support, primary and sign-in actions, and no full-bleed saturated hero. Keep route expectations on the existing callbacks.
- [ ] **Step 3: Run the focused test to observe RED.**

  Run from `app/`: `flutter test test/features/onboarding/welcome_page_test.dart`

  Expected: FAIL on the old full-bleed presentation assertion while existing action semantics still pass.
- [ ] **Step 4: Implement the smallest `WelcomeView` layout change** using the audited existing tokens and a compact SVG/glyph/code-native proof; preserve localization and dock callbacks. Add no new asset by default or navigation behavior; follow the conditional asset rule above only if visual proof identifies a specific gap.
- [ ] **Step 5: Run the focused test to observe GREEN, then refactor.**

  Run from `app/`: `flutter test test/features/onboarding/welcome_page_test.dart`

  Expected: PASS with no overflow at 320, 360, and 432 logical pixels; the dock remains reachable and scroll content is not covered.
- [ ] **Step 6: Run C1–C4 from Task-Closure Verification and record each result.** Expected: all four PASS before commit.
- [ ] **Step 7: Commit this work unit.**

  ```bash
  git add app/lib/features/onboarding/presentation/welcome_page.dart app/test/features/onboarding/welcome_page_test.dart
  git commit -m "feat(onboarding): refresh public welcome presentation"
  ```

  Rollback boundary: revert this commit alone to restore the previous welcome presentation without changing route behavior.

### Task 2: Make the three benefit steps horizontally navigable

**Files:**
- Modify: `app/lib/features/onboarding/presentation/intro_page.dart`
- Test: `app/test/features/onboarding/intro_page_test.dart`

**Interfaces:**
- Consumes: existing first three `OnboardingStep` values and current localization strings.
- Produces: one visible benefit page at a time, navigable by swipe or explicit back/next controls, with understandable step progress; answer steps 4–6 remain unchanged in this task.

- [ ] **Step 1: Add failing tests** for swipe and explicit-control navigation across the first three pages, single-page visibility, accessible current/total progress, back and skip behavior, and immediate static presentation under reduced motion. Keep the existing first-three-step copy meaning.
- [ ] **Step 2: Run the focused test to observe RED.**

  Run from `app/`: `flutter test test/features/onboarding/intro_page_test.dart`

  Expected: FAIL on horizontal navigation/progress assertions while the existing six-step and route assertions remain as baseline guards.
- [ ] **Step 3: Implement the smallest change in `IntroPage`** to make the existing benefit states horizontally navigable while retaining explicit controls, current order, back-to-welcome behavior, skip policy, and the existing answer/lesson state owners. Apply the specified 220 ms transition and reduced-motion final state.
- [ ] **Step 4: Run the focused test to observe GREEN, then refactor.**

  Run from `app/`: `flutter test test/features/onboarding/intro_page_test.dart`

  Expected: PASS; only the current benefit page is exposed, swiping is not the sole navigation method, and progress updates without animation dependence.
- [ ] **Step 5: Run C1–C4 from Task-Closure Verification and record each result.** Expected: all four PASS before commit.
- [ ] **Step 6: Commit this work unit.**

  ```bash
  git add app/lib/features/onboarding/presentation/intro_page.dart app/test/features/onboarding/intro_page_test.dart
  git commit -m "feat(onboarding): add horizontal benefit progression"
  ```

  Rollback boundary: revert this commit alone to restore the existing benefit-step navigation without changing questions or lesson behavior.

### Task 3: Refresh answer cards and the micro-lesson presentation

**Files:**
- Modify: `app/lib/features/onboarding/presentation/intro_page.dart`
- Modify: `app/lib/features/onboarding/presentation/widgets/onboarding_questions.dart`
- Modify: `app/lib/features/onboarding/presentation/widgets/micro_lesson_view.dart`
- Test: `app/test/features/onboarding/intro_page_test.dart`

**Interfaces:**
- Consumes: existing `OnboardingAnswersController`, `ContextsQuestion`, `ToneQuestion`, `MicroLessonView`, localization keys, and Task 2's benefit progression.
- Produces: editorial answer cards and visually continuous lesson; callbacks, saved answer values, lesson correctness, feedback/retry, and final `/plan` transition remain unchanged.

- [ ] **Step 1: Add failing tests** for empty-context gating and re-disabling after deselecting the last context; multi-select persistence; exclusive tone replacement/persistence; selected semantics that do not rely on color; wrong-answer feedback/retry and correct-answer-only completion; back/skip behavior; and narrow/reduced-motion final state.
- [ ] **Step 2: Run the focused test to observe RED.**

  Run from `app/`: `flutter test test/features/onboarding/intro_page_test.dart`

  Expected: FAIL for new selected-card/editorial/semantic assertions while existing domain and lesson behavior assertions continue to guard unchanged semantics.
- [ ] **Step 3: Restyle the existing question and lesson widgets and their intro composition.** Keep context controls multi-select and tone controls single-select; preserve all existing labels, hints, persistence calls, lesson source exercise, feedback, retries, and skip policy. Use selection motion only with an immediate reduced-motion state.
- [ ] **Step 4: Run the focused test to observe GREEN, then refactor.**

  Run from `app/`: `flutter test test/features/onboarding/intro_page_test.dart`

  Expected: PASS; no context cannot proceed, multiple contexts remain selected, one tone is selected, and an incorrect lesson answer cannot unlock completion.
- [ ] **Step 5: Run C1–C4 from Task-Closure Verification and record each result.** Expected: all four PASS before commit.
- [ ] **Step 6: Commit this work unit.**

  ```bash
  git add app/lib/features/onboarding/presentation/intro_page.dart app/lib/features/onboarding/presentation/widgets/onboarding_questions.dart app/lib/features/onboarding/presentation/widgets/micro_lesson_view.dart app/test/features/onboarding/intro_page_test.dart
  git commit -m "feat(onboarding): refresh answer and lesson cards"
  ```

  Rollback boundary: revert this commit alone to restore the previous answer/lesson visuals while retaining the horizontally navigable benefit task.

### Task 4: Refine the personalized plan summary

**Files:**
- Modify: `app/lib/features/subscription/presentation/widgets/paywall_flow.dart`
- Test: `app/test/features/subscription/presentation/paywall_page_test.dart`

**Interfaces:**
- Consumes: existing preview-mode `PaywallFlow`, `OnboardingAnswers`, current localization and daily-rhythm copy, and existing dock/navigation callbacks.
- Produces: a compact summary based only on saved answers; trial, plan-choice, checkout, and route behavior remain unchanged by this task.

- [ ] **Step 1: Add failing tests** for complete, missing, and partial saved answers; assert only selected context/tone values are reflected and the existing anonymous/general fallback appears when absent. Assert the daily-rhythm statement, `/plan` progression, and narrow/short viewport dock reachability.
- [ ] **Step 2: Run the focused test to observe RED.**

  Run from `app/`: `flutter test test/features/subscription/presentation/paywall_page_test.dart`

  Expected: FAIL on the new compact/editorial summary hierarchy or layout assertions; existing answer and navigation assertions remain baseline guards.
- [ ] **Step 3: Implement the summary-only presentation change** in the existing preview step. Do not add a form, category recommendation, new personalization state, or new copy that implies an unselected preference.
- [ ] **Step 4: Run the focused test to observe GREEN, then refactor.**

  Run from `app/`: `flutter test test/features/subscription/presentation/paywall_page_test.dart`

  Expected: PASS for complete and incomplete answers with current fallback and rhythm copy, without hidden/covered content at 320 px.
- [ ] **Step 5: Run C1–C4 from Task-Closure Verification and record each result.** Expected: all four PASS before commit.
- [ ] **Step 6: Commit this work unit.**

  ```bash
  git add app/lib/features/subscription/presentation/widgets/paywall_flow.dart app/test/features/subscription/presentation/paywall_page_test.dart
  git commit -m "feat(subscription): refine personalized plan summary"
  ```

  Rollback boundary: revert this commit alone to restore the prior summary presentation without affecting trial or plan-card work.

### Task 5: Refine the trial timeline presentation

**Files:**
- Modify: `app/lib/features/subscription/presentation/widgets/paywall_flow.dart`
- Modify: `app/lib/features/subscription/presentation/widgets/trial_timeline.dart`
- Test: `app/test/features/subscription/presentation/paywall_page_test.dart`

**Interfaces:**
- Consumes: existing `TrialTimeline.nodesOf`, localized trial/reminder disclosures, and current trial step/dock/navigation.
- Produces: a clearer sequential rendering of the existing three milestones; node copy, reminder behavior, terms, and step progression remain unchanged.

- [ ] **Step 1: Add failing tests** for the three current milestone labels/bodies, reminder-enabled versus honest reminder-disabled copy, full current price/trial/billing/cancellation disclosure, semantic scan order, and short-screen/reduced-motion final state. Assert exact existing localized strings/facts rather than introducing policy values.
- [ ] **Step 2: Run the focused test to observe RED.**

  Run from `app/`: `flutter test test/features/subscription/presentation/paywall_page_test.dart`

  Expected: FAIL only on the timeline readability/sequence or short-screen presentation assertions; disclosure values remain exact baseline assertions.
- [ ] **Step 3: Refine existing timeline nodes and their trial-page presentation.** Reuse current `FluiMotion` timing/curve and node sequence; do not add a new animation feature or timed gate. Keep reminder-off copy honest and all legal/commercial terms plainly reachable around the dock.
- [ ] **Step 4: Run the focused test to observe GREEN, then refactor.**

  Run from `app/`: `flutter test test/features/subscription/presentation/paywall_page_test.dart`

  Expected: PASS for both reminder states and all existing disclosures; reduced motion shows every readable milestone immediately and the dock does not obscure terms.
- [ ] **Step 5: Run C1–C4 from Task-Closure Verification and record each result.** Expected: all four PASS before commit.
- [ ] **Step 6: Commit this work unit.**

  ```bash
  git add app/lib/features/subscription/presentation/widgets/paywall_flow.dart app/lib/features/subscription/presentation/widgets/trial_timeline.dart app/test/features/subscription/presentation/paywall_page_test.dart
  git commit -m "feat(subscription): refine trial timeline presentation"
  ```

  Rollback boundary: revert this commit alone to restore the prior timeline presentation while retaining the summary task.

### Task 6: Present catalog plans as comparable selected cards

**Files:**
- Modify: `app/lib/features/subscription/presentation/widgets/paywall_flow.dart`
- Modify: `app/lib/features/subscription/presentation/widgets/plan_card.dart`
- Test: `app/test/features/subscription/presentation/paywall_page_test.dart`

**Interfaces:**
- Consumes: existing `List<SubscriptionPlan>`, `PlanCard(plan, selected, recommended, onSelected)`, `recommendedPlanId`, `formatPrice`, selected ID callback, and `PaywallMode` finish behavior.
- Produces: comparable plan-card hierarchy and an unambiguous non-color selected state; preview still persists the chosen ID then routes to registration, and checkout keeps its existing action/loading/error behavior.

- [ ] **Step 1: Add failing tests** with multiple distinct catalog plans asserting each displayed name, formatted price, interval, and only supplied savings/equivalent-price facts; recommended-plan ordering; selection semantics that distinguish exactly one selected plan; selected-ID persistence and preview registration handoff; checkout action and loading/error behavior unchanged; and cards/legal copy reachable at 320 px.
- [ ] **Step 2: Run the focused test to observe RED.**

  Run from `app/`: `flutter test test/features/subscription/presentation/paywall_page_test.dart`

  Expected: FAIL for comparable card hierarchy/selection presentation while fixture-sourced price and checkout baseline assertions continue to guard business behavior.
- [ ] **Step 3: Restyle `PlanCard` and its existing `_ChoosePage` composition** with the same facts hierarchy across plans, selected border/icon/semantics, restrained surface depth, and reduced-motion immediate selection. Keep formatting, savings logic, recommendation ordering, persistence, registration handoff, checkout, and terms data unchanged.
- [ ] **Step 4: Run the focused test to observe GREEN, then refactor.**

  Run from `app/`: `flutter test test/features/subscription/presentation/paywall_page_test.dart`

  Expected: PASS; rendered facts equal supplied catalog plans, only the active plan is selected, preview and checkout retain separate actions, and cards/terms are reachable on narrow screens.
- [ ] **Step 5: Run C1–C4 from Task-Closure Verification and record each result.** Expected: all four PASS before commit.
- [ ] **Step 6: Commit this work unit.**

  ```bash
  git add app/lib/features/subscription/presentation/widgets/paywall_flow.dart app/lib/features/subscription/presentation/widgets/plan_card.dart app/test/features/subscription/presentation/paywall_page_test.dart
  git commit -m "feat(subscription): refresh catalog plan cards"
  ```

  Rollback boundary: revert this commit alone to restore prior plan-card styling while retaining the summary/timeline commits.

## Final Visual Proof

After all six work-unit commits, review the full public flow at 320, 360, and 432 logical pixels and on Android API 36 emulator. Verify welcome actions; all six steps; answer and lesson gates; summary fallback/personalization; trial reminder honesty and disclosures; plan facts/selection/handoff; dock reachability, keyboard/focus/semantics, text scaling, and reduced animations. On the emulator, verify safe areas and touch interactions and use TalkBack to hear step progression and selection. Use the fake backend. Do not use remote credentials or execute remote operations.

A physical TECNO CM5 visual pass is required only after explicit authorization names that device and the install/interaction operation. Without it, do not install or interact with the phone; record the physical-device proof as pending and report the limitation.

## Spec Coverage Self-Review

- **Welcome:** Task 1 covers light editorial canvas, compact proof, primary start and sign-in route.
- **Intro benefit progression:** Task 2 covers the first three steps, swipe and explicit controls, progress, back/skip, responsive layout, and reduced motion.
- **Personalization and micro-lesson:** Task 3 covers steps four through six, multi-select contexts, single-select tone, persistence, feedback/retry/gate, dock, responsive layout, and reduced motion.
- **Plan-ready summary:** Task 4 covers saved-answer-only personalization, existing fallback, rhythm, progress/dock, and no category recommendation.
- **Trial explanation:** Task 5 covers the three source-defined milestones, current disclosure wording, reminder-enabled/disabled honesty, sequential readability, and no timed gate.
- **Plan choice and signed-in paywall:** Task 6 covers catalog-only facts, comparable cards, selected semantics, persistence, preview registration and unchanged checkout action/loading/error semantics.
- **Optional registration continuity:** `/register` was not identified as rejected and no evidence requires a continuity adjustment, so it remains unchanged; preserve it if later review identifies a specific inconsistency.
- **Visual system/motion/accessibility:** Global constraints, Task 1 token audit, task-level tests, and final visual proof cover actual token mapping, no default new assets or dependencies, conditional asset review, motion targets/reduced-motion end states, AA contrast, semantics, keyboard/touch, responsive layout, and emulator/device proof.
- **Non-goals:** Route owners, auth/access boundaries, `/today/time`, `/today` deck, catalog/domain, backend, terms, ARBs, and brand/redesign docs remain unchanged.
- **Known source-evidence limit:** If the approved visual direction cannot be matched to existing tokens during Task 1's audit, pause for a scoped decision instead of inventing a color or token.
