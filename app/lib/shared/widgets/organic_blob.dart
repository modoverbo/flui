import 'dart:math' as math;

import 'package:flui/core/theme/flui_colors.dart';
import 'package:material_ui/material_ui.dart';

/// Pure shape math for the organic blob's silhouette — no painting, no
/// widgets, so its numeric behaviour is directly unit-testable.
///
/// The blob is never a perfect circle: a low-frequency, 2-lobed term is
/// always present (however small) so it reads as the same liquid-glass
/// object at rest as it does mid-deformation — one shape, two amounts of
/// motion, not two different objects. `wobble` (`0..1`, unclamped on the
/// way in so a caller can overshoot for a brief pulse) scales a higher-
/// frequency layer on top of that resting lobe. `seed` rotates/phase-shifts
/// the whole pattern so consecutive frames drift rather than breathe
/// perfectly symmetrically — the "alive, not mechanical" quality.
abstract final class OrganicBlobShape {
  /// The radius at [angle] (radians), deformed from [baseRadius] by
  /// [wobble] and [seed]. Always finite and positive.
  static double radiusAt(
    double angle, {
    required double baseRadius,
    required double wobble,
    required double seed,
  }) {
    final safeSeed = seed.isFinite ? seed : 0.0;
    final safeWobble = wobble.isFinite ? wobble : 0.0;

    // Always-present two-lobed asymmetry: the resting "logo" silhouette.
    final restLobe = math.cos(2 * angle + safeSeed) * 0.03;

    // Wobble-driven higher-frequency liquid deformation.
    final wobbleTerm =
        safeWobble *
        (math.sin(angle * 3 + safeSeed * 7) * 0.05 +
            math.sin(angle * 5 - safeSeed * 3) * 0.03);

    final factor = 1 + restLobe + wobbleTerm;
    final radius = baseRadius * factor;
    return radius.isFinite && radius > 0 ? radius : baseRadius.abs() + 1;
  }

  /// Builds the closed [Path] for one blob outline at [size], sampling
  /// [points] points around the circle.
  static Path buildPath({
    required Size size,
    required double wobble,
    required double seed,
    required double scale,
    int points = 72,
  }) {
    final center = size.center(Offset.zero);
    final baseRadius = size.shortestSide * 0.36 * scale;
    final path = Path();
    for (var i = 0; i <= points; i++) {
      final angle = i / points * math.pi * 2;
      final r = radiusAt(
        angle,
        baseRadius: baseRadius,
        wobble: wobble,
        seed: seed,
      );
      final point = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }
}

/// The shape-only primitive: a deformable liquid blob, painted with
/// [CustomPainter]. No state machine, no amplitude awareness, no built-in
/// animation — a caller (e.g. `SpeakingBubble`) drives [wobble]/[seed]/
/// [scale] frame to frame and rebuilds this widget. Reused both as the
/// static, near-zero-wobble logo silhouette and as the base shape the
/// speaking bubble animates.
class OrganicBlob extends StatelessWidget {
  const new({
    required this.size,
    super.key,
    this.wobble = 0.0,
    this.seed = 0.0,
    this.scale = 1.0,
    this.colors = const [FluiColors.lavender, FluiColors.electricBlue],
    this.glow = true,
    this.glowStrength = 1.0,
  });

  /// The paint area's side length (square).
  final double size;

  /// `0..1` (can exceed 1 briefly for a pulse): how much the shape deforms
  /// from its resting two-lobed silhouette.
  final double wobble;

  /// Phase/seed driving the deformation pattern's drift.
  final double seed;

  /// Overall scale applied to the base radius (breathing/pulse/contraction).
  final double scale;

  /// Gradient stops for the fill, top-left to bottom-right.
  final List<Color> colors;

  /// Whether to paint the soft outer glow behind the shape.
  final bool glow;

  /// `0..1` glow opacity multiplier, for a pulsing glow (e.g. `ready`).
  final double glowStrength;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: Size.square(size),
      painter: OrganicBlobPainter(
        wobble: wobble,
        seed: seed,
        scale: scale,
        colors: colors,
        glow: glow,
        glowStrength: glowStrength,
      ),
    ),
  );
}

class OrganicBlobPainter extends CustomPainter {
  const new({
    required this.wobble,
    required this.seed,
    required this.scale,
    required this.colors,
    this.glow = true,
    this.glowStrength = 1.0,
  });

  final double wobble;
  final double seed;
  final double scale;
  final List<Color> colors;
  final bool glow;
  final double glowStrength;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final baseRadius = size.shortestSide * 0.36 * scale;

    if (glow) {
      canvas.drawCircle(
        center,
        baseRadius + 18,
        Paint()
          ..shader =
              RadialGradient(
                colors: [
                  colors.first.withValues(
                    alpha: .30 * glowStrength.clamp(0, 1),
                  ),
                  colors.first.withValues(alpha: 0),
                ],
              ).createShader(
                Rect.fromCircle(center: center, radius: baseRadius + 20),
              ),
      );
    }

    final path = OrganicBlobShape.buildPath(
      size: size,
      wobble: wobble,
      seed: seed,
      scale: scale,
    );

    canvas
      ..drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ).createShader(Offset.zero & size),
      )
      // A small specular highlight — keeps the liquid-glass read at rest.
      ..drawCircle(
        center - Offset(baseRadius * .32, baseRadius * .38),
        baseRadius * .16,
        Paint()..color = Colors.white.withValues(alpha: .22),
      );
  }

  @override
  bool shouldRepaint(OrganicBlobPainter oldDelegate) =>
      oldDelegate.wobble != wobble ||
      oldDelegate.seed != seed ||
      oldDelegate.scale != scale ||
      oldDelegate.glow != glow ||
      oldDelegate.glowStrength != glowStrength ||
      !_sameColors(oldDelegate.colors, colors);

  static bool _sameColors(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
