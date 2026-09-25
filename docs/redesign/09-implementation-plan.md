# 09 — Implementation Plan

> **Historical implementation plan.** Its tasks and risks describe the pre-implementation proposal and are not a live backlog. Several listed changes have since shipped, while others were not selected. Use [10 — Shipped User Flows](10-shipped-user-flows.md) for current user-facing behavior and the active task ledger for ongoing work.

Ordered by priority, per the founder's stated sequence: card stack → speaking → bubble → transitions → vocabulary cards → home/progress. Each step is sized (S = &lt;1 day, M = 2–4 days, L = &gt;1 week, roughly, for one engineer) with required tests and its main risk. This is a plan for a *future* implementation phase — no code is written as part of this Phase 0 document.

## 1. Card stack — `CardStack`, `TrainingCard`, `CardTransition` (L)

**Scope**: build the three structural components (`07-component-hierarchy.md`), wire `SessionPage` to feed them from `SessionFlow`'s lookahead, implement the spring-driven transition (`03-card-stack-spec.md` §3), gestures (§2), and reduced-motion fallback (§6).

**Tests**:
- Unit: `CardTransition` interpolation math — given `from`/`to` position descriptors and a spring, assert interpolated scale/y/opacity at fixed animation progress values (0%, 50%, 100%) without pumping a real animation clock.
- Widget: `CardStack` renders exactly 3 positions (or fewer at session start/end), `IgnorePointer` correctly applied to positions 1/2, tap on position 1/2 has no effect.
- Widget: swipe gesture enabled only for `DiscoverStep`/`ReadingsStep`/`SeedingReadingStep`/resolved `FinalCheckStep`, disabled for answer-required steps — this is a correctness-critical test, since a bug here would let users skip exercises.
- Integration: a full `SessionFlow` run-through (existing `SessionFlow`/`SessionController` tests should already cover the domain sequencing — this integration test only needs to confirm the *visual* stack stays in sync with `flow.index` advancing, not re-test the sequencing itself).
- Golden: reduced-motion state renders only the front card, full-bleed.

**Risk**: highest in the whole plan. `SessionFlow`'s domain advance is synchronous and immediate, but the card stack's visual transition is meant to be decoupled (per `03-card-stack-spec.md` §4) — getting the interruption/replay semantics wrong (e.g., a rapid double-tap advancing the domain state twice before the first visual transition finishes) is the likeliest source of a confusing or broken-looking bug. Budget explicit time for testing rapid-input edge cases, not just the happy path.

## 2. Speaking — wrap the existing feature (M)

**Scope**: `FeedbackCard`, `TrainingTimer`, restyle `SpeakingChallengePage`'s phase-to-widget mapping, promote `/speaking/challenge` into the shell as Habla (`02-navigation-model.md` decision A). Confirm the `comparison` phase's actual completeness first (flagged as unverified in `04-speaking-spec.md` §2) — this affects sizing, since building out a stub vs. restyling a working screen are very different amounts of work.

**Tests**:
- Widget: `FeedbackCard` renders correctly with `SpeechCoaching` present, absent (degrade path), and with a `previousAttempt` for the Compare view.
- Widget: `TrainingTimer` fires `onCap` at exactly 45s, correctly reflects `running` toggling.
- Integration: shell-branch promotion doesn't break the guard chain (`AuthStatus → AccessGate → DailyGate`) — Habla is a route already covered by `AppRoutes.needsDailyBudget`'s membership rules; verify it still redirects to `/today/time` correctly from its new position.
- Manual: web smoke test of `onAmplitudeChanged` (flagged as unverified in `05-bubble-state-machine.md` §1) — do this *before* investing in the reactive bubble's polish, so a web-specific amplitude problem is caught while cheap to fix.

**Risk**: the shell-promotion (root-navigator route → branch) is a go_router structural change touching `AppShell`/`AppShellScaffold` and the branch count (3→4) — moderate risk of regressing the existing 3-tab navigation state-preservation behaviour (each branch keeps its own navigator stack) if not tested carefully across all 4 branches, not just the new one.

## 3. Bubble — `OrganicBlob`, `SpeakingBubble`, `AudioReactiveBubble` (L)

**Scope**: build the shape primitive, the state machine wrapper, and the shader/painted dual-path renderer (`05-bubble-state-machine.md`, `07-component-hierarchy.md`). Ships after speaking's structural work (step 2) is stable, since the bubble's most demanding consumer (`recording` state, amplitude-reactive) needs a working host screen to validate against.

**Tests**:
- Unit: amplitude smoothing pipeline (`05-bubble-state-machine.md` §4) — given a sequence of raw dBFS samples, assert the smoothed/interpolated output matches the expected envelope-follower math (attack vs. release alpha).
- Widget: `AudioReactiveBubble` renders via the painted fallback when `kIsWeb` is forced true in a test, and (where feasible in CI) via the shader path otherwise — at minimum, assert the fallback path never throws and stays reactive to `amplitude` changes.
- Golden: each `BubbleState` (idle, ready, recording, processing, result, error) at a fixed animation frame.
- Manual: shader compilation on real iOS/Android/desktop devices — this cannot be meaningfully unit-tested; budget explicit device-testing time.

**Risk**: shader behaviour is the least-verified part of this entire plan (`05-bubble-state-machine.md` §2 — this research pass found real uncertainty even in the tracking issue's own discussion, not just "untested by us"). Treat the shader path as genuinely experimental: land the painted fallback first as the *default* everywhere, then add the shader as a progressive enhancement behind its own toggle, so a shader problem on a specific device/OS combination doesn't block shipping the rest of the redesign. Do not let "the shader isn't ready" block steps 4–6.

## 4. Transitions — route-level polish (S)

**Scope**: apply the new logo/`OrganicBlob` to `sharedAxisZ`/`sharedAxisX` transition entry points where the bubble is now part of the visual (splash, welcome), confirm `06-motion-spec.md`'s full table is implemented (several rows are "existing, unchanged" and just need a checklist pass, not new code).

**Tests**:
- Golden: splash/welcome screens with the new logo lockup.
- Manual: reduced-motion toggle sweep across every row in `06-motion-spec.md`'s table — this is the natural checkpoint to verify the whole motion inventory, not just what step 4 itself touches.

**Risk**: low — mostly a verification/checklist step over work already done in steps 1–3, plus the logo/`FluiSymbol`→`OrganicBlob` swap in `FluiLogo` (`07-component-hierarchy.md`).

## 5. Vocabulary cards — theme colour rollout (M)

**Scope**: apply the 28-colour system (`01-design-system.md` §1.2) to `WordsPage` (filters/chips), `WordDetailPage`/`WordDetailView` (theme accent), and `ThemeChoiceCard`/`ThemeExplorerSheet`. This is the first real-world test of the generated palette against actual content — a good checkpoint to confirm the family/hue-neighbourhood wayfinding idea (`01-design-system.md` §1.2) actually reads correctly at a glance before rolling it out further.

**Tests**:
- Unit: the palette generator itself (§"Implementation note" in `01-design-system.md`) — assert every one of the 28 generated pairs still clears `aaText`/`aaLargeText`, mirroring `FluiColorRules`'s existing `forbidden`-pairs testing pattern.
- Widget: chip/card rendering with each of the 28 theme colours, at minimum a sampled subset across all 5 families in golden tests (28 individual goldens is likely excessive; sample 2–3 per family).
- Manual: a founder design-review checkpoint here specifically — this is the step where "does multicolour-by-theme actually work as navigation, or does it look chaotic across 410 words" gets answered empirically, before sinking further steps into the same system.

**Risk**: moderate — this is the step most likely to trigger founder-requested palette rework (hue choices, family groupings), since it's the first time the system is seen against real content at scale rather than in the abstract table in `01-design-system.md`.

## 6. Home/progress — `TodayPage`, `ProgressPage` (M)

**Scope**: `numeralHero` rollout, `BentoGrid` theme-tile treatment, streak/achievement visual pass (`08-screen-plan.md`).

**Tests**:
- Widget: `numeralHero` type role renders correctly at both compact/wide breakpoints, text-scaling to 1.3 (accessibility constraint) doesn't break the bento layout.
- Golden: `TodayPage`/`ProgressPage` at compact/wide, light/dark (`progressSurface`), default/1.3 text scale.

**Risk**: low — least structurally risky step, mostly visual/token application over stable existing data flow (`today_providers`, achievement data).

## Cross-cutting, applies to every step

- **Accessibility**: every new/changed screen needs a semantics pass (card identity, bubble state announced to screen readers) — not broken out as its own step because it should be part of each step's definition of done, not a separate late-stage pass.
- **Feature-flag safety**: nothing in this plan currently proposes a flag to gate the rollout — worth a founder decision at kickoff of step 1 (ship card-stack behind a flag vs. direct replacement), since it's the step most likely to need a fast rollback path if the gesture/spring feel doesn't land right in production.
