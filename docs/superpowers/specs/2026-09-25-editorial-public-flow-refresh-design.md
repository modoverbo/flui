# Editorial refresh for the public onboarding and plan flow

This design replaces the rejected public-flow presentation with a calmer, more professional editorial experience while keeping Flui's existing onboarding answers, subscription facts, authentication boundary, and route behavior intact. It is a review artifact, not approval to implement: the user approved the direction, but must review this written spec before implementation planning begins.

## Decision at a glance

| Area | Decision |
|---|---|
| Visual direction | Paper and ink surfaces, deep green for primary actions, and yellow used sparingly for emphasis or progress. Prefer the existing scalable SVG, glyph, and code-native geometry; introduce no dependency. |
| Onboarding | Keep the existing six-step progression and answer meaning. Present the three benefit steps as a short horizontal sequence, followed by the existing context selection, tone selection, and interactive micro-lesson. |
| Personalization | Use clear selectable cards with visible selected state; preserve multi-select contexts, single-select tone, and current persistence behavior. |
| Plan and trial | Keep the existing plan summary, trial explanation, and plan-choice sequence. Present the trial as a sequential day-by-day line and compare real catalog plans in equivalent cards. |
| Motion | Motion explains progression or selection; reduced-motion settings render the same end state immediately. |
| Boundaries | Keep the existing signed-out/signed-in route and access boundaries. Category decks and word cards remain exclusively in signed-in Inicio/catalog, never in public onboarding, account setup, plan preview, or paywall. The signed-in daily time-budget screen is explicitly outside this redesign. |

## Context and current evidence

The current welcome, six-step intro, plan-ready summary, trial timeline, and pricing visuals were rejected in phone screenshots. The supplied video reference demonstrates horizontal onboarding, progress, skip, sticky actions, and saturated illustrations; its movement pattern is useful, but the saturated visual treatment is not the target. This design interprets it as restrained editorial motion rather than copying its color or illustration style.

The separately discussed screenshot #6 is not an onboarding/setup screen and was not rejected: it is the signed-in daily time-budget screen at `/today/time`, with time choices, “Tema de hoy”, recommended themes, and “Empezar”. It is explicitly out of scope here. Choosing “Empezar” routes to `/today`, where signed-in Inicio renders the category deck. This explains where the cards appear without redesigning the time-budget screen, theme recommendations, or category deck.

The current source establishes these constraints:

- `AppRoutes` separates public `/welcome`, `/intro`, `/plan`, `/register` from signed-in `/paywall` and the authenticated app shell. The refresh must not merge these route states or change their owners.
- `IntroPage` currently has six steps: three benefit statements, context selection, tone selection, and a micro-lesson. The first three are informational; contexts are multi-select; tone is single-select; the lesson gates the final continue action. The completed flow navigates to `/plan`.
- `PlanPreviewPage` renders the same plan/trial/choose flow before account creation, displays catalog-provided real plans, persists the selected plan, then navigates to registration. The signed-in paywall is a distinct checkout mode and must keep its current semantics.
- The `/today/time` time-budget flow is signed-in behavior, not public onboarding: after “Empezar” it returns to `/today`, whose signed-in Inicio renders the category deck. Neither surface is part of this refresh.
- Existing Spanish source copy includes the trial milestones “Hoy”, “Día 5”, and “Día 8”, states that no charge is made today, and says cancellation before day 8 avoids payment. Preserve the exact current localized legal and commercial wording and any backend-provided dates/prices; this spec does not create or infer business terms.
- The existing onboarding answer controller writes context and tone changes through its store. The visual refresh must not change answer types, defaults, persistence, or downstream plan-summary inputs.
- Existing `docs/redesign/01-design-system.md` describes a palette that conflicts with its referenced brand palette and with the current approved direction. Do not treat that prose as a resolved source of colors. Implementation must reconcile against actual theme tokens and the approved palette before adding or changing tokens; this spec does not edit that document.

Relevant source: `app/lib/app/router/app_routes.dart`, `app/lib/features/onboarding/presentation/intro_page.dart`, `app/lib/features/onboarding/presentation/widgets/onboarding_questions.dart`, `app/lib/features/onboarding/presentation/widgets/micro_lesson_view.dart`, `app/lib/features/onboarding/presentation/providers/onboarding_providers.dart`, `app/lib/features/subscription/presentation/pages/plan_preview_page.dart`, `app/lib/features/subscription/presentation/widgets/paywall_flow.dart`, `app/lib/features/subscription/presentation/widgets/trial_timeline.dart`, and `app/lib/core/l10n/app_es.arb`.

## Screen design and interaction

### 1. Welcome (`/welcome`)

- Use a light paper canvas, ink typography, restrained green action, and one small brand accent. Avoid a full-bleed saturated hero.
- Lead with the existing promise and a compact product proof made from current word/glyph content or simple vector geometry. The proof is illustrative, not a category preview or a new content surface.
- Keep the primary start action and existing sign-in path obvious and reachable. Start enters `/intro`; sign-in enters the existing login flow.
- Spanish example hierarchy: “Habla como quieres sonar.” as the headline; a brief supporting sentence; primary action “Empezar”; secondary action “Ya tengo una cuenta”. Treat these as examples, not a request to change approved localization strings.

### 2. Intro and personalization (`/intro`)

Retain six meaningful steps and the existing order. A single progress indicator communicates position; step text is available to assistive technology. Skip remains available according to the current flow, including the existing lesson-step behavior. Back returns to the previous step, and back from the first step returns to welcome.

| Step | Content and interaction | State that must remain unchanged |
|---|---|---|
| 1–3: benefits | Three concise horizontal pages explain the current promise, adaptable daily rhythm, and learning through use. One page is visible at a time; users may swipe or use explicit next/back controls. Keep the current meaning, not necessarily the rejected visual treatment. | No new required answer; progress and skip stay understandable. |
| 4: contexts | Present existing `Scene` choices as comfortable selectable cards. Multiple contexts can be selected; selection is not exclusive. Keep the current hint and do not advance until at least one is selected. | Same `Set<Scene>`, toggle semantics, persistence, and localized labels. |
| 5: tone | Present existing speaking-tone options as radio-like cards with title and explanation. | Same single `SpeakingTone` value, labels, and persistence. |
| 6: micro-lesson | Keep a real interactive example using the bundled demo word and its exercise. Show feedback in the card context; a correct answer enables continuing to the plan. | Same answer correctness, feedback, retry behavior, offline/fake-backend behavior, and lesson completion gate. |

Keep the sticky primary action in a stable bottom dock, separated from scrollable content. At narrow widths, benefit pages and choice cards stack without clipped text; context cards use one column when a two-column layout would compress labels. The page remains useful with large text and a short viewport by allowing content to scroll above the dock.

Spanish example labels: “¿En qué conversaciones quieres sentirte más seguro/a?” and “¿Cómo quieres sonar?”. Preserve the existing copy keys and neutral Spanish style unless a later approved copy review changes them.

### 3. Plan-ready summary (`/plan`, first step)

- Open with a compact personalized summary, not a celebratory or oversized hero. Show selected context and tone when present, plus the current daily rhythm statement.
- Missing answers use the existing anonymous/general fallback copy; never invent a preference or imply the user selected one.
- Keep the step progress and sticky action. The summary is a confirmation of current inputs, not a new form or category recommendation.
- Example headline: “Tu plan está listo.” Supporting lines should reflect only saved answers.

### 4. Trial explanation (`/plan`, second step)

- Use a vertical day-by-day line with three source-defined milestones. Animate the connector and reveal milestone content in order so the user can understand when access starts, when the reminder occurs (only if enabled), and when billing begins.
- Preserve existing honest reminder copy when reminders are unavailable. Do not make the reminder look guaranteed if it is not enabled.
- Keep the full localized price, trial length, billing start, cancellation, and reminder disclosures readable adjacent to the timeline. The currently localized copy says today costs US$0 and refers to day 5/day 8; implementation must preserve current source/backend terms exactly rather than copy those values into new hard-coded UI or this design as a new policy.
- Continue/back controls and the persistent dock remain available; the timeline is explanatory, not a timed gate.

### 5. Plan choice (`/plan`, final step) and signed-in paywall (`/paywall`)

- Render each actual subscription plan from the existing catalog as a comparable card with the same information hierarchy: plan name, billing interval, current price, and any existing equivalent-price or savings facts. Only show claims supplied by the current catalog/logic; do not invent discounts, popularity, or savings.
- Selected plan state is indicated by more than color: clear border/selection icon and accessible selected semantics. Use a restrained shadow/elevation or slight surface shift to add depth without dramatic scaling.
- Selecting a card updates the same selected plan ID and persistence path. Before account creation, the final action still moves to registration with the chosen plan. In checkout mode, keep the existing checkout action and loading/error behavior.
- Keep trial and billing terms visible when the user makes the plan decision. Do not place essential terms only behind a tooltip or below a permanently obscuring dock.

### 6. Account setup (`/register`) — optional visual continuity

- The setup screen was not identified as a rejected screenshot. It is only in scope for a minimal presentation adjustment if necessary to keep visual continuity after plan selection; otherwise leave `/register` unchanged.
- If that limited adjustment is needed, preserve the existing fields, validation, privacy/auth semantics, selected-plan handoff, loading/errors, and back behavior. Keep the selected plan and its trial/billing terms visible or plainly reachable; do not add onboarding fields or alter account creation.
- Do not show category decks or word-card collections before account creation. Category content remains inside signed-in Inicio and catalog.

## Visual system and reusable pieces

Prefer existing `FluiColors`, `FluiSpacing`, typography, `PageFrame`, `StickyCtaDock`, `FluiButton`, progress, and motion primitives when their actual token values fit the approved paper/ink/deep-green/sparse-yellow direction. First audit `app/lib/core/theme/` and `docs/brand.md`; do not silently repurpose theme/category colors or duplicate tokens from stale design prose.

If implementation needs shared composition, extract only reusable pieces that serve multiple flow states: a horizontally navigable benefit pager/step rail, a selectable answer card with single/multi-select semantics, a trial milestone line, and a comparable subscription plan card. Keep screen-specific copy and business logic with their current feature boundaries. Do not add a component framework, animation dependency, generated raster art, category-preview subsystem, or new design-token layer for this refresh.

Use existing SVG/glyph assets and code-native geometry first. AI-generated raster imagery is optional and should be considered only if a specific hero demonstrably needs it after the native treatment is evaluated; any such asset requires its own later review and must not carry essential text or information.

## Motion specification

Motion is short, purposeful, and never required to understand state. Use existing `FluiMotion` tokens where possible; durations below are target ceilings for the new treatment, not a requirement to replace a working shared motion system.

| Motion | Purpose and start → end | Timing and curve | Reduced-motion result |
|---|---|---|---|
| Benefit page change | Communicate horizontal progression: current page settles out and next page enters from the navigation direction. No looping or autoplay. | 220 ms, ease-out; one page transition at a time. | Swap directly to the selected page; preserve focus and progress update. |
| Progress update | Confirm step advancement without competing with content. | 180 ms, ease-out fill to the new fraction. | Set final fraction immediately. |
| Answer-card selection | Confirm selected/unselected state: neutral surface/border → selected surface/border/icon. | 160 ms, ease-out; no bounce or positional shift. | Set selected styling immediately. |
| Trial timeline refinement | The existing `TrialTimeline` already animates its yellow connector. Preserve that behavior and improve node emphasis/readability so the three milestones are easier to scan in sequence; do not introduce a new timeline animation feature. | Reuse the existing `FluiMotion` timing/curve. Any added per-node emphasis must remain subtle and fit within the existing timeline entrance. | Render connector and every milestone in their readable final state immediately. |
| Plan-card selection | Show which plan owns the current choice: neutral → selected border, subtle elevation/surface depth. | 160 ms, ease-out; scale change, if any, capped at 1.01. | Render selected card directly, with no movement. |

No screen automatically advances. Avoid parallax, pulsing, elastic overshoot, continuous shimmer, and repeated or flashing effects. Honor Flutter's reduced-animation setting (`MediaQuery.disableAnimationsOf` or equivalent) at every animated surface, and test the static final state rather than merely shortening a long animation.

## Accessibility and responsive behavior

- Keep all controls operable by touch and keyboard; provide visible focus, logical order, and usable back/skip/next actions. Interactive targets should be at least 44 logical pixels where feasible and never below the platform/WCAG minimum.
- Announce step changes and selection state with meaningful semantics; label the progress indicator with current step and total. Do not make a swipe gesture the only way to change pages.
- Expose multi-select context cards as toggles and tone/plan choices as single-selection groups. Selection must be communicated through text/semantics and shape/border, not color alone.
- Maintain readable contrast: normal text at least 4.5:1, large text and essential UI boundaries/focus at least 3:1. Verify actual rendered token pairings; do not assume a color name guarantees contrast.
- Preserve screen-reader reading order and dynamic status announcements for validation, loading, selected plan, and errors. Keep form labels and validation tied to their fields on account setup.
- Support text scaling and scrolling without clipping or horizontal overflow. The CTA dock may reserve space, but must not cover the last card, legal disclosure, form error, or focused control.

## Acceptance and proof matrix

| Check | 320 px | 360 px | 432 px | TECNO CM5 / Android API 36 |
|---|---|---|---|---|
| Welcome and benefit pages | Headline, proof, actions, and progress remain visible or scrollable; no clipped copy. | Same; dock and scroll area remain distinct. | Same; content does not stretch into awkward full-width cards. | Verify actual touch navigation, safe-area insets, system text scaling, and no blocked CTA. |
| Context and tone cards | Long labels stack; selected state and all options remain reachable. | No compressed text or overlapping dock. | Spacing expands without changing selection behavior. | Verify taps toggle multiple contexts and choose exactly one tone. |
| Micro-lesson and plan summary | Exercise feedback and summary scroll above dock; no card overflow. | Same, with progress/continue clear. | Cards remain aligned and summary remains compact. | Verify lesson completion gate and answer-derived summary with the fake backend. |
| Trial and plan choice | All legal/commercial terms and plan facts remain reachable; cards stack. | Timeline and card hierarchy stay readable. | Cards may use more horizontal space but remain comparable. | Verify milestone copy/reminder honesty, exact catalog prices, plan persistence, and registration handoff. |
| Reduced motion and accessibility | Static state is understandable without animation at each width. | Verify keyboard/focus path and semantics. | Verify text scaling does not hide actions. | Enable system reduced animations; verify immediate end state and TalkBack announces progression/selection. |

Required proof for implementation (not performed by this design task): widget tests for the six-step flow, multi-/single-select semantics, persistence, trial copy variants, plan selection and route handoff; accessibility/semantics checks; visual review at the three widths; and a physical-device pass on the named TECNO CM5/API 36. Run the app's configured format, analysis, unit/widget, and integration checks as applicable. Test against the fake backend for this public-flow UI change; do not require remote credentials or alter backend data.

## Risks, rollout, and unresolved source checks

| Risk | Mitigation / proof |
|---|---|
| A refreshed sales screen accidentally changes trial or billing claims. | Keep terms sourced from current localization and plan data; assert exact displayed facts in tests and review each locale/catalog state. |
| Six existing steps feel long when restyled. | Keep the benefit portion short and skippable as today; preserve transparent progress and the existing answer/lesson gates rather than removing steps without approval. |
| Existing theme prose and actual theme tokens disagree. | Audit `app/lib/core/theme/` and `docs/brand.md` before implementation. Record the chosen token mapping and reconcile stale `docs/redesign/01-design-system.md` separately; do not treat that file as approved truth. |
| Persistent CTA hides legal text, options, or focused controls on short screens. | Use scrollable content with reserved dock space; verify every screen and text scale at 320 px and on device. |
| Raster artwork adds visual weight or performance cost. | Start with SVG/glyph/code-native geometry; only introduce a reviewed asset for a demonstrated need. |
| Signed-out personalization leaks into category/content access. | Keep `/plan` and `/register` public and preserve the existing access guard; category deck and word cards remain in signed-in Inicio/catalog only. |

Roll out as a presentation-only refresh within existing routes and state owners. Keep the fake backend and current localization/data sources. Do not migrate stored answers, alter account/access/subscription behavior, add analytics, or introduce a feature flag unless a later implementation review identifies a concrete need and obtains approval.

## Explicit non-goals

- Changing onboarding answer semantics, persistence, order, defaults, or the lesson correctness rule.
- Changing route names, authentication/access boundaries, subscription prices, trial length, reminder behavior, billing/cancellation terms, or plan catalog.
- Redesigning the signed-in `/today/time` daily time-budget screen, its recommended themes, the `/today` category deck, or their navigation/behavior. The deck appears in signed-in Inicio after “Empezar”.
- Showing category deck T14, word cards T15, or category recommendations before account creation; those remain exclusively in signed-in Inicio and category catalog.
- Replacing the fake backend, adding network requirements, or changing backend/database policy.
- Copying the reference video's saturated illustration/color style, generating assets by default, or adding a UI/animation dependency.
- Editing the existing redesign/brand-system documentation as part of this spec-writing task.

## Review order

1. Confirm the preserved route, answer, and commercial-term boundaries.
2. Review screen sequence and interaction states, especially the six-step onboarding and plan-to-registration handoff.
3. Review motion, reduced-motion, accessibility, and narrow-screen requirements.
4. Approve or request changes to this written spec. Only after approval should an implementation plan be created.
