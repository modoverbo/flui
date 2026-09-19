import 'package:flutter/physics.dart';
import 'package:material_ui/material_ui.dart';

/// Motion tokens. Four durations, one entrance curve, one exit curve and an
/// emphasized curve for shared-axis transitions.
///
/// Every animated widget resolves its duration through [resolve] so
/// "reduce motion" turns motion off instead of merely shortening it.
abstract final class FluiMotion {
  static const Duration instant = Duration(milliseconds: 120);
  static const Duration quick = Duration(milliseconds: 200);
  static const Duration standard = Duration(milliseconds: 320);
  static const Duration celebration = Duration(milliseconds: 900);

  /// The whole duration scale, in order.
  static const List<Duration> durations = [
    instant,
    quick,
    standard,
    celebration,
  ];

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeOut;

  /// Material's emphasized curve, for shared-axis route transitions.
  static const Curve emphasized = Cubic(0.2, 0, 0, 1);

  /// Leaving is 0.8x of arriving: things go away faster than they appear.
  static Duration exitOf(Duration duration) =>
      Duration(microseconds: (duration.inMicroseconds * 0.8).round());

  // Named motions of the product.

  /// Word reveal: per-line mask slide-up.
  static const Duration wordReveal = standard;
  static const Duration wordRevealStagger = Duration(milliseconds: 40);
  static const double wordRevealScale = 1.02;

  /// Correct answer: the yellow underline draws left to right.
  static const Duration underlineDraw = Duration(milliseconds: 220);

  /// Wrong answer: three 6 px cycles, amber border, never red.
  static const Duration shake = Duration(milliseconds: 260);
  static const int shakeCycles = 3;
  static const double shakeOffset = 6;

  /// Progress bar, with a brief yellow glow at the end.
  static const Duration progress = Duration(milliseconds: 400);

  /// Web section entrance: fade plus a 12 px rise, staggered.
  static const Duration sectionEntrance = quick;
  static const Duration sectionStagger = Duration(milliseconds: 60);
  static const double sectionRise = 12;

  /// Milestones that deserve the streak celebration.
  // TODO(flui): decide on vector animation separately. Rive community files
  // are CC BY (attribution in-product) and the LottieFiles free plan is
  // non-commercial for authoring, so both need a licence call plus an asset
  // we would have to draw. Until then the celebrations are painted here.
  static const Set<int> streakMilestones = {3, 7, 14, 30};

  static bool isMilestone(int streak) => streakMilestones.contains(streak);

  /// Whether the platform asked for less motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// [duration], or zero when the user asked for reduced motion.
  static Duration resolve(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;

  /// Drives [controller] with [spring] from its current value to [to],
  /// starting at [velocity] — 0 for a programmatic trigger, or a drag
  /// gesture's release velocity. Under reduced motion, skips the
  /// simulation entirely and jumps straight to [to]: the "instant settle"
  /// every spring falls back to (`06-motion-spec.md`).
  static TickerFuture driveSpring(
    BuildContext context,
    AnimationController controller,
    SpringDescription spring, {
    required double to,
    double velocity = 0,
  }) {
    if (reduced(context)) {
      controller.value = to;
      return TickerFuture.complete();
    }
    return controller.animateWith(
      SpringSimulation(spring, controller.value, to, velocity),
    );
  }
}

// Spring tokens (`SpringDescription`): the first physics-based motion in
// the app, used only where the input is a real drag gesture with release
// velocity (or its ambient/looping near-equivalent) rather than a
// programmatic duration+curve tween (`06-motion-spec.md`). Drive them with
// [FluiMotion.driveSpring] or `controller.animateWith(SpringSimulation(...))`
// directly — not `Curves`, which can't express a starting velocity.

/// Snappy — gesture-driven interactions the user's finger is still
/// touching (drag release, swipe-to-dismiss the front card). Underdamped,
/// visible but brief overshoot so a released card feels caught, not just
/// stopped. Damping ratio ≈ 0.67.
const fluiSpringFast = SpringDescription(mass: 1, stiffness: 500, damping: 30);

/// The default — card-to-card advance, the next card moving into front
/// position, feedback card arriving. This is the spring most motion in
/// `03-card-stack-spec.md`/`06-motion-spec.md` refers to unless stated
/// otherwise. Underdamped, slightly softer overshoot than [fluiSpringFast].
/// Damping ratio ≈ 0.69.
const fluiSpringStandard = SpringDescription(
  mass: 1,
  stiffness: 300,
  damping: 24,
);

/// Idle/ambient — bubble breathing, gentle emphasis, anything looping or
/// unprompted by direct touch. Near-critically damped: reaches its target
/// smoothly, no bounce, so a looping breath doesn't read as jittery.
/// Damping ratio ≈ 0.997.
const fluiSpringGentle = SpringDescription(
  mass: 1,
  stiffness: 170,
  damping: 26,
);
