import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_motion.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:material_ui/material_ui.dart';

/// Progress, 0 to 1. The fill is yellow — one of its four roles — and it
/// eases into its new value in 400 ms with a short glow.
class FluiProgressBar extends StatelessWidget {
  const new({
    required this.value,
    required this.semanticLabel,
    super.key,
    this.height = 8,
    this.onDark = false,
  });

  final double value;
  final String semanticLabel;
  final double height;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    final track = onDark ? FluiColors.greenSecondary : FluiColors.greenTint;
    return Semantics(
      label: semanticLabel,
      value: '${(clamped * 100).round()} %',
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: clamped),
        duration: FluiMotion.resolve(context, FluiMotion.progress),
        curve: FluiMotion.enter,
        builder: (context, animated, _) => CustomPaint(
          size: Size(double.infinity, height),
          painter: _BarPainter(value: animated, track: track, height: height),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  const new({required this.value, required this.track, required this.height});

  final double value;
  final Color track;
  final double height;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(height / 2);
    final rect = Offset.zero & Size(size.width, height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()..color = track,
    );
    if (value <= 0) return;
    final filled = RRect.fromRectAndRadius(
      Offset.zero & Size(size.width * value, height),
      radius,
    );
    canvas
      // The glow is what a milestone feels like without a confetti burst.
      ..drawRRect(
        filled,
        Paint()
          ..color = FluiColors.yellowElectric.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      )
      ..drawRRect(filled, Paint()..color = FluiColors.yellowElectric);
  }

  @override
  bool shouldRepaint(_BarPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.track != track ||
      oldDelegate.height != height;
}

/// The round rail used inside cards, where a full bar would be too loud.
class FluiProgressDots extends StatelessWidget {
  const new({
    required this.total,
    required this.filled,
    required this.semanticLabel,
    super.key,
    this.onDark = false,
  });

  final int total;
  final int filled;
  final String semanticLabel;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < total; index++) ...[
            if (index > 0) const SizedBox(width: 4),
            AnimatedContainer(
              duration: FluiMotion.resolve(context, FluiMotion.quick),
              curve: FluiMotion.enter,
              width: index < filled ? 18 : 8,
              height: 6,
              decoration: BoxDecoration(
                color: index < filled
                    ? FluiColors.yellowElectric
                    : (onDark
                          ? FluiColors.greenSecondary
                          : FluiColors.greenTint),
                borderRadius: FluiRadii.pill,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
