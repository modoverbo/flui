# 03 — Card Stack Spec

The mental-model shift: `screen → content → button → next screen` becomes a stack of physical cards. This document specifies geometry, gestures, the enter/exit transition, how it's fed from `SessionFlow`, and the reduced-motion fallback.

## 1. Geometry

Three visible positions at any time: **front** (position 0, interactive), **next** (position 1), **next+1** (position 2). Anything beyond position 2 is not composited (see §5 performance note).

| Position | Scale | Y offset | Opacity | Interactive |
|---|---|---|---|---|
| 0 (front) | 1.00 | 0 | 1.00 | yes |
| 1 (next) | 0.94 | 18 | 0.85 | no (`IgnorePointer`) |
| 2 (next+1) | 0.89 | 34 | 0.55 | no (`IgnorePointer`) |

Y offset is in logical pixels, applied as a **downward** translation (positions behind sit lower, peeking out from beneath the front card, consistent with the founder's brief). Scale and opacity are the only other per-position properties — no per-position rotation at rest (rotation only appears transiently during the transition itself, §3).

All three positions share the same horizontal center and the same card width (`FluiSpacing.contentMaxWidth`-constrained, same as today's `SessionPage` content). Cards are `FluiCard`-radius (16, see `01-design-system.md` §3) — kept close to the existing card radius so the stack still reads as "the same card system," not a new shape.

Shadow: front card gets a new `cardStackShadow` token — larger blur/lower opacity than the existing `ctaDockShadow`, tuned so positions 1 and 2 read as *behind* the front card without needing their own shadows (a single shadow under position 0, cast onto positions 1/2, sells the stack — matches how a real stack of cards or photos looks, and keeps to "at most one new shadow concept" discipline from `01-design-system.md` §3).

```dart
static const cardStackShadow = [
  BoxShadow(color: Color(0x1F151426), blurRadius: 32, offset: Offset(0, 12)),
];
```

## 2. Gestures

| Gesture | Target | Effect |
|---|---|---|
| Tap (on an interactive element inside the front card — an option, a text field, `FluiButton`) | front card only | normal in-card interaction; does not move the stack by itself |
| Swipe (horizontal drag past a distance/velocity threshold) | front card only | **only enabled on step types the founder confirms are swipe-appropriate** — see below |
| Drag (below threshold, released) | front card only | card springs back to position 0 (`fluiSpringFast`, §4) |

**Swipe is not universal.** Most `SessionStep` variants (`ClozeView`, `FormRecallView`, `ProductionView`) require an explicit answer/choice before advancing — a swipe that bypasses answering would let a user skip the actual exercise, which breaks the learning loop's integrity (spaced review depends on recording whether the user got it right). Swipe-to-advance is only enabled for **read-only steps**: `DiscoverStep` and `ReadingsStep`/`SeedingReadingStep` (nothing to answer, just content to read) and `FinalCheckStep`'s result screen (already resolved). For every other step, the card advances only when `SessionController.continueStep()`/`answerCloze()` succeeds — the button/option tap remains the only trigger, exactly as today; the stack visualizes that advance, it doesn't add a new way to trigger it.

Drag physics: `fluiSpringFast` (`01-design-system.md` §5) drives both the springback-on-release-below-threshold and the fling-out-on-release-above-threshold, seeded with the drag's actual release velocity (`DragEndDetails.velocity.pixelsPerSecond`) — this is the concrete reason the card stack needed spring tokens at all (curve+duration can't take a starting velocity).

## 3. Enter/exit transition — exact values

Triggered whenever `SessionFlow` advances (`completeStep()`/`completeCloze()` returns a new flow with `index + 1`), regardless of whether the trigger was a tap or a swipe.

**Exiting card (was position 0):**
- Translates further down and off-screen: Y from 0 → 420 (enough to clear the viewport on all supported widths).
- Slight rotation: 0° → ±6° (sign matches swipe direction if swipe-triggered; if button-triggered, always −6°, i.e. a consistent gentle counter-clockwise exit — a small deliberate "hand-off" tell rather than a neutral straight drop).
- Scale: 1.00 → 0.86 (shrinks slightly as it recedes, consistent with y-depth perspective).
- Opacity: 1.00 → 0 over the back 40% of the motion only (stays fully opaque for the first 60%, so it reads as physically leaving, not fading).
- Driven by `fluiSpringStandard`, target values above, duration is whatever the spring settles in (typically ~380–450ms at these parameters, not a fixed duration — springs are open-loop).

**Promoted cards (position 1 → 0, position 2 → 1):**
- Interpolate scale, Y, opacity from their old position's values to their new position's values (table in §1), same `fluiSpringStandard`.
- A slight **overshoot** is expected and intentional (damping ratio ≈0.69, per `01-design-system.md` §5) — the incoming front card should overshoot scale 1.00 by roughly 2–3% and settle back, giving the "caught" feel the founder asked for. This is a property of the spring constants, not a hand-authored overshoot curve.
- Position 1 → 0 becomes interactive (`IgnorePointer` lifted) only once its animation crosses ~90% completion, not at trigger time — prevents accidental double-taps landing on a card that hasn't visually arrived yet.

**New card entering position 2** (from the lookahead, previously not composited): fades/scales in from position 2's rest values with no animation from "nothing" — it simply becomes present at position 2's target state with a quick (`quick`, 200ms, `enter` curve) opacity fade-in, since there's no physical "before" state for a card that wasn't rendered yet. This is deliberately curve-based, not spring-based — it's not a continuous physical motion, just a compositing entrance.

**Never a fade or a route push** for the front-card transition itself, per the founder's brief — the opacity fade above is a *supporting* property of the physical exit, not the mechanism.

## 4. Feed from `SessionFlow`

No changes to `SessionFlow`'s domain logic (`features/daily/domain/session_flow.dart`) or `SessionController` (`features/daily/presentation/controllers/session_controller.dart`) are required — the card stack is a presentation-layer concern that reads state already exposed:

```dart
// Inside SessionPage's build, reading SessionController's state:
final flow = state.flow;
final visible = flow.steps.skip(flow.index).take(3).toList();
// visible[0] = front card content, visible[1] = next, visible[2] = next+1
```

Each card's identity/key stays `ValueKey('${flow.index + offset}-${step.runtimeType})')` — the same keying `_StepContent` already uses today, extended with a position offset so React/Flutter's element-diffing correctly treats a promoted card as the *same* element moving, not a new one being built (critical for the spring animation to animate *from* the card's current on-screen state rather than snapping).

`CardStack` (see `07-component-hierarchy.md`) owns the animation/position bookkeeping; it receives `visible` as input and a callback for "front card's exit animation completed" which is when `SessionController` is told to actually commit the already-computed next state (the domain advance already happened synchronously on button-press; the *visual* stack transition is decoupled from it and can be interrupted/replayed without re-querying domain state — this matters for the reduced-motion fallback in §6, where the promotion is instant and the domain state and visual state change in the same frame).

## 5. Performance

- Only positions 0–2 are composited; anything from `visible[3]` onward is not built at all (`ListView`-style laziness, not just clipped).
- Only `Transform` (scale, translate, rotate) and `Opacity` change per animation frame — no layout passes mid-animation. Card *content* (text, images) is laid out once when a card enters position 2 and never re-laid-out as it moves through positions 2 → 1 → 0 → exit.
- Target 60 fps on the drag gesture specifically (the most demanding case — every `PointerMoveEvent` must produce a frame): position 0's `Transform` follows the pointer 1:1 during an active drag, with position 1/2 offsets computed as a function of the drag's progress (a cheap interpolation, not their own spring simulations) so the whole stack reads as "shifting" during a drag preview, at zero extra animation-controller cost.

## 6. Reduced-motion fallback

When `FluiMotion.reduced(context)` is true:

- Positions 1 and 2 are **not rendered at all** — reduced motion also means reduced visual complexity/parallax, not just faster animation (a static stack peeking out is still motion-adjacent visual noise for a user who asked for less). Only the front card renders, full-bleed, matching today's single-screen presentation as closely as possible.
- Card-to-card advance is an instant swap (`Duration.zero`), no exit animation, no promotion animation — the new front card simply appears. `SessionController`'s domain advance and the visual swap happen in the same frame (no decoupling needed, since there's no animation to decouple from).
- Swipe gesture is disabled entirely when reduced motion is on, even for the step types that normally allow it (§2) — a swipe gesture implies a continuous physical response, which reduced motion opts out of; the button/tap path remains the only trigger.
- This fallback is a hard `if (reduced) { ... } else { ... }` branch in `CardStack`, not a parameter-tuned-down version of the same animation — consistent with how `VoiceOrb` already handles reduced motion today (freezing rotation phase rather than slowing it down).
