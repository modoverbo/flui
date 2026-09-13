import 'dart:math' as math;

import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/shared/widgets/flui_symbol.dart';
import 'package:material_ui/material_ui.dart';

/// Loading indicator: the flui waves breathing in sequence.
///
/// Honors "reduce motion" (`MediaQuery.disableAnimations`).
class LoadingWave extends StatefulWidget {
  const new({
    required this.semanticLabel,
    super.key,
    this.size = 64,
    this.color = FluiColors.greenDeep,
  });

  final String semanticLabel;
  final double size;
  final Color color;

  @override
  State<LoadingWave> createState() => _LoadingWaveState();
}

class _LoadingWaveState extends State<LoadingWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0.25;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      liveRegion: true,
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: _WavesPainter(animation: _controller, color: widget.color),
        ),
      ),
    );
  }
}

class _WavesPainter extends CustomPainter {
  new({required this.animation, required this.color})
    : super(repaint: animation);

  final Animation<double> animation;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / FluiSymbolGeometry.viewBox;
    canvas.scale(scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = FluiSymbolGeometry.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    const waves = FluiSymbolGeometry.waves;
    for (var i = 0; i < waves.length; i++) {
      final phase = (animation.value - i / waves.length) * 2 * math.pi;
      final factor = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(phase));
      canvas.drawPath(
        FluiSymbolGeometry.path(
          waves[i],
          amplitude: waves[i].amplitude * 1.2 * factor,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WavesPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.animation != animation;
}
