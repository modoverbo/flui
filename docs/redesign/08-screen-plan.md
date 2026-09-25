# 08 — Screen Plan

> **Historical screen plan.** This records proposed work before implementation; statements such as replacing the session renderer or making the speaking page a tab entry point are not current work items. The shipped route and screen behavior is documented in [10 — Shipped User Flows](10-shipped-user-flows.md).

Screen by screen: what changes, what stays, which existing file it lives in. Ordered core loop first, then support.

## Core loop

### `TodayPage` — `features/daily/presentation/today_page.dart`
- **Changes**: becomes the Hoy tab's editorial landing surface — streak/plan numerals promoted to `numeralHero`/`displayL` (`01-design-system.md` §2), `BentoGrid` tiles re-themed to use the 28-colour system where a tile represents a specific theme (e.g. "continue Reuniones") rather than the generic bento tones. Session-summary CTA gains a "practice speaking" secondary CTA deep-linking to Habla (soft integration, per `02-navigation-model.md`).
- **Stays**: `BentoGrid` layout mechanism itself, `TimeBudgetPage` hand-off, `WeekDots` streak visualization, underlying `today_providers`/`learning_data_controller` data flow.

### `TimeBudgetPage` — `features/daily/presentation/time_budget_page.dart`
- **Changes**: minimal — mostly inherits the type-scale and colour updates. `ThemeChoiceCard`/`ThemeExplorerSheet` picker gets the theme colours (currently themeless chips become theme-tinted).
- **Stays**: budget-choice flow, routing to `/session`.

### `SessionPage` — `features/daily/presentation/session_page.dart`
- **Changes**: the largest single change in the app. `_StepContent`'s full-screen switch-and-swap is replaced by `CardStack` (`07-component-hierarchy.md`), fed by `SessionFlow`'s lookahead (`03-card-stack-spec.md` §4). Each existing step widget (`ClozeView`, `FormRecallView`, `ProductionView`, `WordDetailView`, `ReadingsCarousel`) is now hosted inside `TrainingCard` instead of filling the screen.
- **Stays**: `SessionController`/`SessionFlow`/`SessionStep` domain and controller logic entirely unchanged (`03-card-stack-spec.md` §4) — this is a presentation-only rewrite of how the same state is rendered.

### `WordsPage` — `features/vocabulary/presentation/words_page.dart`
- **Changes**: catalogue browse gets theme-colour chips/filters (the 28-colour system's most natural home — this is literally a themed catalogue) and larger, more editorial word-list typography.
- **Stays**: search/filter logic, list virtualization, navigation to `/words/:wordId`.

### `WordDetailPage` / `WordDetailView` — `features/vocabulary/presentation/word_detail_page.dart`, `widgets/word_detail_view.dart`
- **Changes**: `wordHero` treatment for the headword (already the intent of that type role, likely under-used today), theme-colour accent tying the word back to its theme. Since `WordDetailView` is reused inside `SessionPage`'s `DiscoverStep`, this change is shared automatically — no separate work for the in-session vs. standalone presentation.
- **Stays**: `HighlightedText`, `MasteryMeterView`, `WordStateKind` state-chip logic.

### `SpeakingChallengePage` — `features/speaking/presentation/speaking_challenge_page.dart`
- **Changes**: full visual rewrite per `04-speaking-spec.md` and `05-bubble-state-machine.md` — `VoiceOrb` → `SpeakingBubble`/`AudioReactiveBubble`, new `TrainingTimer`, new `FeedbackCard`, becomes the Habla tab's entry point instead of a root-navigator-only route (`02-navigation-model.md`).
- **Stays**: `_Phase` state machine, `SpeechRecorder`/`SpeechAnalysisRepository` usage, amplitude subscription/normalisation logic (smoothing is *added*, not replacing the existing formula — `05-bubble-state-machine.md` §4), `SpeakerCueCards`.

### `ProgressPage` — `features/profile/presentation/progress_page.dart`
- **Changes**: streak/achievement numerals promoted to `numeralHero`, `AchievementTile`s could pick up theme colours where an achievement is theme-specific (not all are — mastery/streak achievements stay neutral-state-coloured per `01-design-system.md` §1.3's rule against overloading colour meaning).
- **Stays**: `WeekDots`, `SubscriptionSummary`, achievement data flow.

## Support

### `SplashPage` — `app/lib/app/pages/splash_page.dart`
- **Changes**: the new bubble (`OrganicBlob`, idle/breathing state) as the loading centerpiece instead of whatever mark it uses today.
- **Stays**: auth/access-gate waiting logic.

### `WelcomePage` / `IntroPage` — `features/onboarding/presentation/*.dart`
- **Changes**: new logo lockup (`FluiLogo` + `OrganicBlob`), editorial typography pass. This is the highest-visibility "does it still parece un banco" test — worth the founder's early review.
- **Stays**: onboarding copy/content structure, `sharedAxisX` transition between steps.

### `LoginPage` / `RegisterPage` / `PasswordResetPage` — `features/auth/presentation/pages/*.dart`
- **Changes**: token/colour pass only (new logo in header, updated `FluiTextField`/`FluiButton` styling if `01-design-system.md` changes their defaults). Not a priority screen for the editorial/organic direction — these are utility screens, over-designing them works against their job.
- **Stays**: form logic, validation, auth flow entirely.

### `PlanPreviewPage` / `PaywallPage` / `CheckoutReturnPage` — `features/subscription/presentation/pages/*.dart`
- **Changes**: token/colour pass, `PlanCard`/`TrialTimeline` could use `numeralHero` for price/day-count callouts.
- **Stays**: payment/Whop flow entirely — out of scope for a design pass and explicitly listed as a capability to preserve.

## Explicit non-changes (confirm scope with founder)

- No screen's *data* or *business logic* changes — every "changes" row above is presentation-layer only, consistent with the architecture constraint (`presentation → domain ← data` preserved everywhere).
- `content/`, `supabase/`, and `app/lib` code itself are untouched by this Phase 0 document — this plan describes *intended* file-level changes for a future implementation phase, it does not make them.
