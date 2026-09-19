# 05 — Bubble State Machine

The liquid-glass bubble is both the logo mark and the speaking-recording indicator — one object, two contexts (welcome screen, recording). This document specifies its states and answers the critical open question with evidence.

## 1. Critical open question: does the current recording implementation expose live amplitude?

**Yes — already implemented, already wired to a bubble widget, cross-platform including web.** Evidence:

- `app/pubspec.yaml:28` → `record: ^7.1.1` (already a dependency, not something to add).
- `SpeechRecorder` interface (`app/lib/features/speaking/domain/speech_recorder.dart`) declares `Stream<double> get amplitude` as part of its contract.
- `RecordSpeechRecorder` (`app/lib/features/speaking/data/record_speech_recorder.dart:53-56`) implements it directly against the package:
  ```dart
  @override
  Stream<double> get amplitude => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 120))
      .map((value) => value.current);
  ```
- Consumed today in `SpeakingChallengePage` (`presentation/speaking_challenge_page.dart:71-73`): `_amplitudeSubscription = _recorder.amplitude.listen((value) { setState(() => _amplitude = value); });`
- Normalized at `speaking_challenge_page.dart:258`: `final level = ((amplitude + 60) / 60).clamp(0.08, 1.0);` — treats the raw value as dBFS-ish, roughly −60…0 range, mapped to 0.08…1.0.
- Fed into the existing bubble: `VoiceOrb` (`presentation/widgets/voice_orb.dart`), whose `CustomPainter` already computes `energy = state == recording ? amplitude * 12 : 0.0` and wobbles a path with it. `VoiceOrb` already honors `FluiMotion.reduced(context)` by freezing rotation phase instead of stopping outright.

**Package survey (for completeness, since the brief asked for it even though a swap isn't needed):**

| Package | Web support | Amplitude API | Verdict |
|---|---|---|---|
| `record` (in use, `^7.1.1`) | Yes — federated `record_web` implementation; pub.dev's own feature matrix lists amplitude/dBFS as supported on all platforms including web | `onAmplitudeChanged(Duration)` stream, `Amplitude.current`/`.max` in dBFS | **Keep — no swap needed** |
| `flutter_sound` | Partial | Raw PCM stream only (Float32/Int16); amplitude would need to be computed manually (RMS/dB) | Not needed; more work for the same result |
| `mic_stream` / `mic_stream_recorder` | No web support | Real-time amplitude, mobile-only | Ruled out — breaks the web requirement |

**One caveat worth flagging, not blocking**: package-level web support for `onAmplitudeChanged` is confirmed via `record`/`record_web`'s published docs and feature matrix on pub.dev, not by running this specific app in a browser during this research pass — `record_speech_recorder.dart` has no web-specific branch or conditional, which is consistent with "it just works the same way," but should get a manual smoke test on web early in implementation (`09-implementation-plan.md`), not treated as a spec-time risk.

## 2. Rendering: shader where possible, painted fallback on web

Verified against Flutter 3.47.4 (stable, matches this project's toolchain) and official docs:

- Fragment shader syntax: `flutter: shaders: - shaders/myshader.frag` in `pubspec.yaml`, loaded via `FragmentProgram.fromAsset`. Source: docs.flutter.dev/ui/design/graphics/fragment-shaders — states both Skia and Impeller backends support custom shaders, but the `ImageFilter`-custom-shader path is Impeller-only, and the page is silent on web.
- **Web verdict: not reliably supported today.** Tracking issue [flutter/flutter#114121](https://github.com/flutter/flutter/issues/114121) ("[web] add FragmentProgram support to CanvasKit") is closed and linked to [PR #118461](https://github.com/flutter/flutter/pull/118461), but the issue's own discussion flags an unresolved blocker: CanvasKit's `RuntimeEffect` API historically didn't accept sampler arguments, with the team noting they might not implement it at all rather than "leave it in a half-working state." This research pass could not confirm from the issue text that sampler-argument support has since shipped and is stable in the CanvasKit renderer. Skwasm (the newer WASM renderer, needs Chrome 119+/Firefox 120+/Safari 18.2+) is a separate track and doesn't resolve the CanvasKit gap.
- The app's own prior art agrees with this caution: `app/README.md`'s decision log already rejected a live shader once, for the static green plate texture — *"A live fragment shader would cost a first-frame stall on CanvasKit for a background that never moves."* That reasoning was about a static, non-reactive background; the bubble is neither static nor on every screen, so it isn't automatically disqualified, but it's evidence the team has already weighed shader cost on this exact renderer and found it wanting once.

**Decision (flag to founder): the bubble is shader-driven on mobile/desktop (Impeller) and painted (`CustomPainter` + `BackdropFilter`) on web**, gated on `kIsWeb` (a platform check, not a capability probe — Flutter has no reliable runtime "can I compile a fragment shader" API to probe against). This is not a downgrade in practice: `VoiceOrb`'s existing `CustomPainter` implementation already produces the amplitude-reactive organic wobble the founder wants, entirely without a shader — it can be the web (and shader-load-failure) fallback almost unchanged, just re-skinned to the liquid-glass look with a `RadialGradient` + `BackdropFilter` blur layered underneath the existing path animation. flui is web-first (`docs/architecture.md`) — the fallback path is not an edge case, it's the primary experience for a large share of users, and must look intentional, not degraded.

## 3. States

| State | Trigger | Visual | Maps to existing |
|---|---|---|---|
| **idle** | Bubble shown with nothing happening yet (welcome screen, or Habla tab before engaging) | Breathing: scale 1.00 → 1.015 over 2–3s, `fluiSpringGentle` (near-critically damped, no overshoot — a breath doesn't bounce), looping | New — no direct precedent in `VoiceOrbState`, which starts at `listening` |
| **ready** | Prompt shown, about to record (`_Phase.ready`) | Idle breathing continues, plus a subtle "invite" cue (e.g. a slightly larger breath amplitude or a soft glow pulse) signalling it's tappable | `VoiceOrbState.listening` |
| **recording** | `_Phase.recording` | Amplitude-reactive wobble, driven by the pipeline in §4 | `VoiceOrbState.recording` |
| **processing** | `_Phase.analyzing` | No amplitude input (mic closed); a self-driven ambient motion — reuse the idle breath cadence but slightly faster (1.00 → 1.02, same spring) so it reads as "still alive, thinking," not frozen | `VoiceOrbState.analyzing` |
| **result** | `_Phase.feedback` and `_Phase.comparison` | A settle-and-hold: one `fluiSpringStandard` pulse to a resting scale, then still (no loop) — the bubble's job here is done, attention should move to the `FeedbackCard`, not compete with it | `VoiceOrbState.success` |
| **error** | `_Phase.error` or `_Phase.denied` | Currently **missing from `VoiceOrbState`** — needs a new enum value. Visual: a brief, small, non-alarming contraction (never red per brand voice; use `amber`) then return to `idle` breathing | New — add to `VoiceOrbState` |

## 4. Amplitude pipeline: normalise → smooth → animate

Current code takes the raw stream straight to `setState` with no smoothing (`speaking_challenge_page.dart:71-73`); at a 120ms sample interval this risks visible jitter on an organic, continuous-looking shape. Add a smoothing stage between normalisation and rendering:

1. **Sample**: `_recorder.amplitude` emits dBFS values (roughly −60…0 in practice) on a 120ms interval — unchanged, this is `record`'s own internal sampling cadence, not something the app controls per-frame.
2. **Normalise** (unchanged, keep the existing formula): `level = ((dBFS + 60) / 60).clamp(0.08, 1.0)`.
3. **Smooth** — asymmetric exponential moving average (an envelope follower, standard for audio-reactive UI): attack faster than release, so the bubble responds promptly to a spike in volume but doesn't flicker during brief pauses between words.
   ```dart
   const attackAlpha = 0.5;   // how fast the smoothed value rises toward a new, louder sample
   const releaseAlpha = 0.15; // how fast it falls toward a new, quieter sample
   final alpha = level > smoothed ? attackAlpha : releaseAlpha;
   smoothed = smoothed + alpha * (level - smoothed);
   ```
4. **Animate**: `smoothed` updates once per 120ms tick, but the widget should render at 60fps — interpolate between the previous and new `smoothed` value over the 120ms window with a driven `AnimationController` (`Tween(begin: previous, end: smoothed).animate(controller)`, `Curves.linear` or `Curves.easeOut`), rather than stepping the visual value only 8.3 times/second.
5. **Feed to the render layer**:
   - Painted fallback (`CustomPainter`, web/no-shader path): keep the existing scale factor, `energy = interpolatedSmoothed * 12`, matching `VoiceOrb`'s current constant so the visual "feel" carries over unchanged.
   - Shader path (mobile/desktop): pass `interpolatedSmoothed` (already 0.0–1.0) directly as a `float` uniform — shaders should receive normalised input, not the painter's `*12` scale, since that scale is an artifact of the painter's own path-wobble math, not a general-purpose amplitude unit.

## 5. Reduced motion

- **idle/ready breathing**: disabled — bubble renders at a fixed rest scale (1.00), no loop.
- **recording**: amplitude reactivity is **not** disabled outright (it's informational — the user needs to see the mic is live — not merely decorative looping), but the motion is capped to a smaller range and driven by opacity/scale steps rather than continuous wobble, consistent with `VoiceOrb`'s existing reduced-motion behaviour of freezing rotation phase rather than removing feedback entirely.
- **processing**: disabled, same as idle.
- **result/error**: the settle-pulse and error-contraction become instant state changes (`Duration.zero`), no spring.
