import 'dart:math' as math;

import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_motion.dart';
import 'package:material_ui/material_ui.dart';

enum VoiceOrbState { listening, recording, analyzing, success }

class VoiceOrb extends StatefulWidget {
  const new({
    required this.state,
    required this.amplitude,
    required this.semanticLabel,
    super.key,
    this.onTap,
    this.size = 188,
  });

  final VoiceOrbState state;
  final double amplitude;
  final String semanticLabel;
  final VoidCallback? onTap;
  final double size;

  @override
  State<VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<VoiceOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (FluiMotion.reduced(context)) {
      _controller.stop();
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
    final reduced = FluiMotion.reduced(context);
    Widget orb(double phase) => CustomPaint(
      size: Size.square(widget.size),
      painter: _VoiceOrbPainter(
        state: widget.state,
        amplitude: widget.amplitude.clamp(0, 1),
        phase: phase,
      ),
    );
    final painted = reduced
        ? orb(0)
        : AnimatedBuilder(
            animation: _controller,
            builder: (_, _) => orb(_controller.value * math.pi * 2),
          );
    return Semantics(
      label: widget.semanticLabel,
      button: widget.onTap != null,
      child: GestureDetector(onTap: widget.onTap, child: painted),
    );
  }
}

class _VoiceOrbPainter extends CustomPainter {
  const new({
    required this.state,
    required this.amplitude,
    required this.phase,
  });

  final VoiceOrbState state;
  final double amplitude;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final pulse = math.sin(phase) * 3;
    final energy = state == VoiceOrbState.recording ? amplitude * 12 : 0.0;
    final radius = size.shortestSide * .36 + pulse + energy;

    canvas.drawCircle(
      center,
      radius + 18,
      Paint()
        ..shader = RadialGradient(
          colors: [
            FluiColors.electricBlue.withValues(alpha: .28),
            FluiColors.aqua.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius + 20)),
    );

    final colors = switch (state) {
      VoiceOrbState.listening => const [
        FluiColors.aqua,
        FluiColors.electricBlue,
      ],
      VoiceOrbState.recording => const [
        FluiColors.electricBlue,
        FluiColors.coral,
      ],
      VoiceOrbState.analyzing => const [
        FluiColors.lavender,
        FluiColors.electricBlue,
      ],
      VoiceOrbState.success => const [FluiColors.acidLime, FluiColors.aqua],
    };
    final path = Path();
    const points = 72;
    for (var index = 0; index <= points; index++) {
      final angle = index / points * math.pi * 2;
      final wobble =
          math.sin(angle * 3 + phase) * (3 + energy * .22) +
          math.sin(angle * 5 - phase * .7) * 2;
      final r = radius + wobble;
      final point = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
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
      ..drawCircle(
        center - const Offset(24, 28),
        radius * .34,
        Paint()..color = Colors.white.withValues(alpha: .24),
      )
      ..drawCircle(
        center,
        radius * .18,
        Paint()..color = FluiColors.ink.withValues(alpha: .88),
      );
  }

  @override
  bool shouldRepaint(_VoiceOrbPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.amplitude != amplitude ||
      oldDelegate.state != state;
}
