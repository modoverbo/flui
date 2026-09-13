import 'dart:math' as math;

import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/shared/widgets/flui_symbol.dart';
import 'package:material_ui/material_ui.dart';

/// The green plate: the app's only texture.
///
/// The radial field and its 5 % grain are pre-baked WebP assets (1x / 2x /
/// 3x, `tool/generate_texture_plates.mjs`); a live fragment shader would
/// cost a first-frame stall on CanvasKit for a background that never moves.
/// The flat colour underneath means a plate still looks right before the
/// image decodes.
class FluiPlate extends StatelessWidget {
  const new({
    required this.child,
    super.key,
    this.borderRadius = FluiRadii.plateAll,
    this.waveField = true,
    this.padding = EdgeInsets.zero,
  });

  /// A plate that bleeds to the window edges.
  const new fullBleed({
    required this.child,
    super.key,
    this.waveField = true,
    this.padding = EdgeInsets.zero,
  }) : borderRadius = BorderRadius.zero;

  static const asset = 'assets/textures/plate_green.webp';

  final Widget child;
  final BorderRadius borderRadius;

  /// The quiet wave field behind the content, at 6 %.
  final bool waveField;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: FluiColors.plateEdge),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(
              child: Image.asset(
                asset,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                // A missing or still-decoding plate leaves the flat green.
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            if (waveField)
              const Positioned.fill(
                child: ExcludeSemantics(child: _WaveField()),
              ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

/// Rows of the logo wave, very faint, so a green block has a surface.
class _WaveField extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _WaveFieldPainter());
}

class _WaveFieldPainter extends CustomPainter {
  const new();

  static const double opacity = 0.06;
  static const double waveWidth = 96;
  static const double rowHeight = 56;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()
      ..color = FluiColors.cream.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final rows = (size.height / rowHeight).ceil() + 1;
    final columns = (size.width / waveWidth).ceil() + 1;
    const half = waveWidth / 2;
    const amplitude = waveWidth * 0.09;

    for (var row = 0; row < rows; row++) {
      final y = row * rowHeight;
      // Each row is offset, so the field never lines up into a plaid.
      final shift = (row.isEven ? 0.0 : half) - half;
      final path = Path()..moveTo(shift, y);
      for (var column = 0; column <= columns; column++) {
        final x = shift + column * waveWidth;
        path
          ..cubicTo(
            x + half / 3,
            y - amplitude,
            x + 2 * half / 3,
            y - amplitude,
            x + half,
            y,
          )
          ..cubicTo(
            x + 4 * half / 3,
            y + amplitude,
            x + 5 * half / 3,
            y + amplitude,
            x + waveWidth,
            y,
          );
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_WaveFieldPainter oldDelegate) => false;
}

/// The logo wave, blown up and set very faint: the quiet graphic a green
/// screen uses instead of stock imagery.
class PlateWaveMark extends StatelessWidget {
  const new({super.key, this.size = 340, this.opacity = 0.1});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: -math.pi / 18,
          child: FluiSymbol(size: size, color: FluiColors.cream),
        ),
      ),
    );
  }
}
