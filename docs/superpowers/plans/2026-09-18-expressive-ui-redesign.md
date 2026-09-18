# Flui Expressive UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform Flui into a colorful, motion-led communication gym with a reactive voice orb and presenter cue cards.

**Architecture:** Extend the existing token-based theme and shared-widget system, then consume those primitives in the shell, Today and speaking flows. Keep motion code-native and state-driven so live microphone amplitude can drive the flagship interaction without adding a paid dependency.

**Tech Stack:** Flutter, Material 3, Riverpod, go_router, CustomPainter, existing motion utilities.

**Spec:** `docs/superpowers/specs/2026-09-18-expressive-ui-redesign-design.md`

## Global Constraints

- Preserve all domain flows and speech-analysis contracts.
- No paid visual runtime or remote dependency.
- Honor `MediaQuery.disableAnimations` everywhere.
- Maintain semantic labels, 44 px targets and 130% text-scale compatibility.
- Use color by skill meaning and verified foreground contrast.

---

### Task 1: Expressive design foundations

**Files:**
- Modify: `app/lib/core/theme/flui_colors.dart`
- Modify: `app/lib/core/theme/flui_theme.dart`
- Modify: `app/lib/core/theme/flui_motion.dart`
- Create: `app/lib/shared/widgets/expressive_card.dart`
- Test: `app/test/core/theme/flui_theme_test.dart`
- Test: `app/test/shared/widgets/expressive_card_test.dart`

**Interfaces:**
- Produces: `SkillColor`, `FluiColors.skill(SkillColor)`, `ExpressiveCard`, `PressableScale`.

- [ ] Write failing tests proving every skill surface has readable foregrounds, cards expose their tone, and reduced motion removes press animation.
- [ ] Run the focused tests and confirm the missing interfaces fail.
- [ ] Add the palette, expressive card and tactile press primitive.
- [ ] Run focused theme and shared-widget tests.
- [ ] Commit the foundation.

### Task 2: Living navigation and connected transitions

**Files:**
- Modify: `app/lib/app/shell/app_shell_scaffold.dart`
- Modify: `app/lib/app/router/flui_transitions.dart`
- Test: `app/test/app/shell/app_shell_test.dart`
- Test: `app/test/app/router/app_redirect_test.dart`

**Interfaces:**
- Consumes: `PressableScale`, expressive palette.
- Produces: floating adaptive navigation dock and shared-axis page transition.

- [ ] Write failing widget assertions for the floating dock, selected-destination expansion and reduced-motion transition.
- [ ] Run the focused shell tests and confirm failure.
- [ ] Implement the dock and directional shared-axis route transitions.
- [ ] Run shell, routing and accessibility tests.
- [ ] Commit navigation and transitions.

### Task 3: Today card-stack dashboard

**Files:**
- Modify: `app/lib/features/daily/presentation/today_page.dart`
- Modify: `app/lib/shared/widgets/bento_grid.dart`
- Create: `app/lib/shared/widgets/card_stack.dart`
- Test: `app/test/features/daily/presentation/today_page_test.dart`
- Test: `app/test/shared/widgets/card_stack_test.dart`

**Interfaces:**
- Consumes: `ExpressiveCard`, skill palette and `PressableScale`.
- Produces: `CardStack`, colorful oral-training hero and expressive progress tiles.

- [ ] Write failing tests for the stacked oral hero, card semantics and phone layout at 130% text scale.
- [ ] Run the focused tests and verify the intended failures.
- [ ] Build the card stack and redesign Today while preserving every action and data branch.
- [ ] Run Today and layout tests.
- [ ] Commit the dashboard.

### Task 4: Reactive voice orb and presenter cue cards

**Files:**
- Create: `app/lib/features/speaking/presentation/widgets/voice_orb.dart`
- Create: `app/lib/features/speaking/presentation/widgets/speaker_cue_cards.dart`
- Modify: `app/lib/features/speaking/presentation/speaking_challenge_page.dart`
- Test: `app/test/features/speaking/presentation/voice_orb_test.dart`
- Test: `app/test/features/speaking/presentation/speaking_challenge_page_test.dart`

**Interfaces:**
- Produces: `VoiceOrb(state, amplitude, onTap)`, `SpeakerCueCards(revealedCount, onReveal)`.

- [ ] Write failing tests for orb states, amplitude response, reduced motion and the three optional cue cards.
- [ ] Run the focused speaking tests and confirm failure.
- [ ] Implement the painter, state animations, cue cards and redesigned phase layouts.
- [ ] Run speaking tests, including recording and retry flows.
- [ ] Commit the flagship speaking experience.

### Task 5: Cross-app polish and validation

**Files:**
- Modify: `app/lib/features/vocabulary/presentation/words_page.dart`
- Modify: `app/lib/features/profile/presentation/progress_page.dart`
- Modify: `app/lib/features/onboarding/presentation/welcome_page.dart`
- Modify: `app/lib/shared/widgets/flui_button.dart`
- Test: relevant existing page and accessibility tests.

**Interfaces:**
- Consumes: all expressive foundations.
- Produces: consistent primary tabs and entry experience.

- [ ] Add failing visual-contract tests for skill colors and expressive primary actions.
- [ ] Apply the system to Words, Progress, onboarding and buttons without altering business logic.
- [ ] Run page-level and accessibility tests.
- [ ] Run `flutter test`, `flutter analyze` and a web build.
- [ ] Manually exercise Today → speaking → recording → cue cards → feedback at phone and desktop widths.
- [ ] Commit the final polish.
