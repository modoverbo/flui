# 07 — Component Hierarchy

New presentation-layer components, their responsibilities, inputs, and what existing code they replace or absorb. All live under `app/lib/shared/widgets/` (cross-feature) or `app/lib/shared/motion/` (motion primitives), matching the existing split — nothing here belongs inside a feature's own `presentation/` unless noted.

## Structural

### `CardStack`
- **Responsibility**: owns the 3-position compositing, gesture handling, and enter/exit/promotion animation described in `03-card-stack-spec.md`. Stateful — holds the `AnimationController`s driving each visible position's `Transform`/`Opacity`.
- **Inputs**: `List<TrainingCard>` (already built, length ≤3, from the caller's lookahead — `CardStack` doesn't know about `SessionFlow`), `onFrontCardExitComplete` callback, `swipeEnabled` (bool, set per step-type by the caller per `03-card-stack-spec.md` §2), `reducedMotion` (bool, though it can also read `FluiMotion.reduced(context)` itself).
- **Replaces/absorbs**: `SessionPage`'s current `_StepContent` switch-and-swap body composition. `SessionPage` still owns *which* widget represents each `SessionStep` variant (that mapping doesn't move), but stops doing the transition itself — it hands `CardStack` a list of already-built cards.

### `TrainingCard`
- **Responsibility**: the visual card shell — radius, surface, shadow-per-position (position is passed in, not computed by `TrainingCard` itself), hosts arbitrary content (a `ClozeView`, `WordDetailView`, `ReadingsCarousel`, etc. — whatever `SessionStep` variant it's wrapping).
- **Inputs**: `child` (the existing step widget, unchanged), `position` (0/1/2 — drives scale/y/opacity per `03-card-stack-spec.md` §1), `themeAccent` (Color?, for the top-edge tint from `01-design-system.md` §1.3).
- **Replaces/absorbs**: nothing existing directly — this is a new wrapper *around* the existing step widgets (`ClozeView`, `FormRecallView`, `ProductionView`, `WordDetailView`, `ReadingsCarousel` keep all their own logic unchanged, they're just now hosted inside a `TrainingCard` instead of filling the screen directly).

### `CardTransition`
- **Responsibility**: a lower-level motion primitive — wraps a single child in the spring-driven transform math (scale/translate/rotate/opacity interpolation between two `CardStack` positions, including the exit trajectory). `CardStack` composes three of these; it is not used standalone elsewhere today, but factored out separately so it's independently testable (feed it two position-states and a spring, assert the interpolated values at a given animation progress — this is the kind of thing golden/widget tests should cover per `09-implementation-plan.md`).
- **Inputs**: `from`/`to` position descriptors (scale, y, opacity, rotation), `SpringDescription`, `onComplete`.
- **Replaces/absorbs**: nothing existing.

## Bubble

### `OrganicBlob`
- **Responsibility**: the shape-only primitive — the two-lobed organic form used both as the logo mark (static, on the welcome screen and wordmark lockup) and as the base shape the speaking bubble animates. Pure shape/paint, no state machine, no amplitude awareness.
- **Inputs**: `size`, `wobble` (0.0–1.0, a single scalar driving how much the two lobes deform from rest — the logo passes a constant near-zero value; the speaking bubble drives it from the amplitude pipeline), `fillStyle` (gradient/shader descriptor).
- **Replaces/absorbs**: the logo half of `FluiSymbol`/`FluiWave` (`shared/widgets/flui_symbol.dart`) — the current 3-wave "fluir" mark tied to Tabler Icons' `ripple` (MIT-licensed, noted in `docs/brand.md` for replacement). `FluiLogo` (`flui_logo.dart`) keeps its role as the wordmark+symbol *lockup* container, but the symbol it lays out changes from `FluiSymbol` to `OrganicBlob`.

### `SpeakingBubble`
- **Responsibility**: the state-machine-aware wrapper around `OrganicBlob` — owns the `05-bubble-state-machine.md` states (idle/ready/recording/processing/result/error), picks shader vs. painted rendering per `kIsWeb`, and exposes the breathing/pulse/contraction animations as internal, not caller-driven, behaviour (the caller just sets a `BubbleState` enum value).
- **Inputs**: `state` (new `BubbleState` enum — supersedes `VoiceOrbState`, adds the missing `error` value per `05-bubble-state-machine.md` §3), `amplitude` (double, 0.0–1.0, already-smoothed per the pipeline in `05-bubble-state-machine.md` §4 — smoothing happens in the *caller*, typically a controller/provider, not inside the widget, so it stays testable without a real animation pump), `size`.
- **Replaces/absorbs**: `VoiceOrb` (`presentation/widgets/voice_orb.dart`, currently living inside the `speaking` feature). Because the same bubble object is now also the logo/welcome-screen centerpiece, `SpeakingBubble` moves to `shared/widgets/` — it's no longer speaking-feature-specific. The `speaking` feature keeps its own thin wrapper (mapping `_Phase` → `BubbleState`) rather than depending on internals directly.

### `AudioReactiveBubble`
- **Responsibility**: the platform-branching render layer — chooses the `FragmentProgram` shader path (mobile/desktop, Impeller) or the `CustomPainter` fallback path (web, and as a graceful degrade if shader compilation fails at runtime on a supported platform). This is where `05-bubble-state-machine.md` §2's `kIsWeb` branch actually lives, kept as its own widget rather than inlined into `SpeakingBubble` so the fallback path is unit-testable in isolation (render without a shader, assert the painted output still reacts to `amplitude`).
- **Inputs**: `amplitude`, `wobble` baseline from `OrganicBlob`'s state, `useShader` (bool, resolved once at build time from `kIsWeb` plus a try/catch around shader load — not re-evaluated per frame).
- **Replaces/absorbs**: the `CustomPainter` half of `VoiceOrb` (`_VoiceOrbPainter`) becomes this widget's fallback-path implementation, re-skinned per `01-design-system.md`'s visual language but keeping its existing `energy = amplitude * 12` math for that path specifically (per `05-bubble-state-machine.md` §4).

## Speaking feedback

### `FeedbackCard`
- **Responsibility**: composes `SpeakingMetrics` (always available immediately, local computation) and `SpeechCoaching` (arrives async from the Edge Function, may be null) into one card, per `04-speaking-spec.md` §2's Feedback row. Handles the degrade-to-metrics-only case explicitly (never a raw error state for a partial success).
- **Inputs**: `SpeakingMetrics`, `SpeechCoaching?`, `onRetry` callback, `previousAttempt` (for the Compare phase — `SpeechTranscript?`, null on a first attempt).
- **Replaces/absorbs**: nothing existing — this composition doesn't currently exist as a widget; today's `SpeakingChallengePage` presumably builds this inline (not confirmed by this research pass — verify at implementation time whether extracting `FeedbackCard` is a refactor of existing inline code or genuinely new composition).

### `TrainingTimer`
- **Responsibility**: the 45-second countdown display + soft-cap/auto-stop logic described in `04-speaking-spec.md` §3. Pure presentation — the actual stop-recording call happens in the caller's callback, `TrainingTimer` just fires `onCap` at 45s.
- **Inputs**: `duration` (45s default, configurable), `running` (bool), `onCap` callback.
- **Replaces/absorbs**: nothing existing — no timer widget currently in the codebase per this research pass (not exhaustively confirmed; if one exists inline in `SpeakingChallengePage`, extracting it here is a refactor, not new work).

## Motion primitives

| Primitive | Responsibility | Home |
|---|---|---|
| `CardTransition` | spring-driven position interpolation (see above) | `shared/motion/` |
| `fluiSpringFast` / `fluiSpringStandard` / `fluiSpringGentle` | `SpringDescription` constants | `core/theme/flui_motion.dart` (or new `flui_springs.dart`, re-exported) |
| `SpringMotionBuilder` (new, generic) | a small reusable widget wrapping `AnimationController.animateWith(SpringSimulation(...))` + a builder callback — the thing `CardTransition`, `SpeakingBubble`'s breathing, and any future spring-driven widget all sit on top of, so spring-driving logic exists once | `shared/motion/` |

Existing motion primitives (`DrawUnderline`, `ShakeBox`, `RevealLines`, `SectionEntrance`) are unchanged and untouched by this redesign — they're duration/curve-based and stay that way (`06-motion-spec.md` rows 11–16).

## What is explicitly NOT a new component

- `ClozeView`, `FormRecallView`, `ProductionView`, `WordDetailView`, `ReadingsCarousel`, `ReadingCard`: unchanged, hosted inside `TrainingCard` rather than full-screen.
- `SessionController`, `SessionFlow`, `SessionStep`: unchanged, domain/presentation-controller layer, per `03-card-stack-spec.md` §4.
- `SpeechRecorder`, `SpeechAnalysisRepository`, `SpeechAnalyzer`: unchanged, per `04-speaking-spec.md` §5.
