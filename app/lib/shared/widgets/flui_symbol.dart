import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

enum FluiSymbolTone { yellow, green }

/// One wave of the flui symbol, in a 48 x 48 view box.
@immutable
final class FluiWave {
  const new({
    required this.y,
    required this.startX,
    required this.halfWidth,
    required this.amplitude,
  });

  final double y;
  final double startX;
  final double halfWidth;
  final double amplitude;
}

/// Geometry of the symbol: three stacked waves derived from Tabler Icons
/// "ripple" (MIT), with thicker strokes, a left-to-right phase offset and a
/// calmer amplitude towards the bottom. The SVG assets are generated from the
/// same numbers (tool/generate_brand_assets.mjs); a test keeps them in sync.
abstract final class FluiSymbolGeometry {
  static const viewBox = 48.0;
  static const strokeWidth = 5.0;
  static const waves = [
    FluiWave(y: 14, startX: 6, halfWidth: 16, amplitude: 4.4),
    FluiWave(y: 24.5, startX: 8, halfWidth: 16, amplitude: 3.6),
    FluiWave(y: 35, startX: 10, halfWidth: 16, amplitude: 2.8),
  ];

  /// SVG path data: a crest then a trough, as in the source icon.
  static String svgPathData(FluiWave wave) {
    final h = wave.halfWidth;
    final a = wave.amplitude;
    return [
      'M${_n(wave.startX)} ${_n(wave.y)}',
      'c${_n(h / 3)} ${_n(-a)} ${_n(2 * h / 3)} ${_n(-a)} ${_n(h)} 0',
      's${_n(2 * h / 3)} ${_n(a)} ${_n(h)} 0',
    ].join();
  }

  /// The same wave as a [Path], with an optional amplitude override.
  static Path path(FluiWave wave, {double? amplitude}) {
    final h = wave.halfWidth;
    final a = amplitude ?? wave.amplitude;
    final x = wave.startX;
    final y = wave.y;
    return Path()
      ..moveTo(x, y)
      ..cubicTo(x + h / 3, y - a, x + 2 * h / 3, y - a, x + h, y)
      ..cubicTo(x + 4 * h / 3, y + a, x + 5 * h / 3, y + a, x + 2 * h, y);
  }

  static String _n(double value) {
    final fixed = double.parse(value.toStringAsFixed(2));
    return fixed == fixed.roundToDouble()
        ? fixed.toInt().toString()
        : fixed.toString();
  }
}

/// The flui symbol from the brand SVG assets.
///
/// Use [FluiSymbolTone.yellow] only on dark green surfaces.
class FluiSymbol extends StatelessWidget {
  const new({
    super.key,
    this.size = 48,
    this.tone = FluiSymbolTone.green,
    this.color,
    this.semanticLabel,
  });

  static const yellowAsset = 'assets/brand/flui_symbol.svg';
  static const greenAsset = 'assets/brand/flui_symbol_green.svg';

  final double size;
  final FluiSymbolTone tone;

  /// Recolors the symbol (for example cream on deep green).
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final color = this.color;
    return SvgPicture.asset(
      tone == FluiSymbolTone.yellow ? yellowAsset : greenAsset,
      width: size,
      height: size,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
