import 'dart:async';
import 'dart:math' as math;

import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_motion.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Right answer: a yellow underline draws under [child], left to right, and
/// the phone gives one light tap.
class DrawUnderline extends StatefulWidget {
  const new({
    required this.child,
    required this.drawn,
    super.key,
    this.color = FluiColors.yellowElectric,
    this.thickness = 4,
    this.haptic = true,
  });

  final Widget child;

  /// Draws when this turns true; erases instantly when it turns false.
  final bool drawn;
  final Color color;
  final double thickness;
  final bool haptic;

  @override
  State<DrawUnderline> createState() => _DrawUnderlineState();
}

class _DrawUnderlineState extends State<DrawUnderline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: FluiMotion.underlineDraw,
    value: widget.drawn ? 1 : 0,
  );

  @override
  void didUpdateWidget(DrawUnderline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.drawn == widget.drawn) return;
    if (!widget.drawn) {
      _controller.value = 0;
      return;
    }
    if (FluiMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
    if (widget.haptic) _tap();
  }

  /// Desktop and web have nothing to vibrate.
  static const Set<TargetPlatform> _hapticPlatforms = {
    TargetPlatform.android,
    TargetPlatform.iOS,
  };

  void _tap() {
    if (!_hapticPlatforms.contains(defaultTargetPlatform)) return;
    unawaited(HapticFeedback.lightImpact());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => CustomPaint(
        foregroundPainter: _UnderlinePainter(
          progress: _controller.value,
          color: widget.color,
          thickness: widget.thickness,
        ),
        child: child,
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: widget.thickness * 2),
        child: widget.child,
      ),
    );
  }
}

class _UnderlinePainter extends CustomPainter {
  const new({
    required this.progress,
    required this.color,
    required this.thickness,
  });

  final double progress;
  final Color color;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final y = size.height - thickness / 2;
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width * progress, y),
      Paint()
        ..color = color
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_UnderlinePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// Wrong answer: three 6 px cycles in 260 ms and an amber border. Never red,
/// never a cross: it is a "todavía no", not a verdict.
class ShakeBox extends StatefulWidget {
  const new({
    required this.child,
    required this.attempt,
    super.key,
    this.borderRadius = FluiRadii.cardAll,
  });

  final Widget child;

  /// Increment to shake. Zero means "nothing has gone wrong yet".
  final int attempt;
  final BorderRadius borderRadius;

  @override
  State<ShakeBox> createState() => _ShakeBoxState();
}

class _ShakeBoxState extends State<ShakeBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: FluiMotion.shake,
  );

  @override
  void didUpdateWidget(ShakeBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.attempt <= oldWidget.attempt) return;
    if (FluiMotion.reduced(context)) {
      // Still mark the attempt: the amber border is the feedback that stays.
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final marked = widget.attempt > 0;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final decay = 1 - t;
        final offset = t == 0 || t == 1
            ? 0.0
            : math.sin(t * FluiMotion.shakeCycles * 2 * math.pi) *
                  FluiMotion.shakeOffset *
                  decay;
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          border: Border.all(
            color: marked ? FluiColors.amber : Colors.transparent,
            width: 2,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}
