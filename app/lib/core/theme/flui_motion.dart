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
}
