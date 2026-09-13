import 'package:flui/core/theme/flui_colors.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

/// The ten custom glyphs, drawn on the wave motif of the logo.
///
/// Everything else in the app uses Lucide on purpose: these ten are the
/// concepts only flui has, so only they get a drawing of their own.
enum FluiGlyph {
  onda('onda'),
  wordOfTheDay('palabra-del-dia'),
  replaces('reemplaza'),
  streak('racha'),
  inContext('en-contexto'),
  register('matiz-registro'),
  microphone('microfono'),
  goal('meta'),
  achievement('logro'),
  review('repaso');

  new(this.assetName);

  final String assetName;

  String get asset => '${FluiGlyphGeometry.assetDirectory}/$assetName.svg';
}

/// Shared geometry of the family. `tool/generate_glyphs.mjs` writes the SVGs
/// from these numbers and a test checks every asset against them.
abstract final class FluiGlyphGeometry {
  static const assetDirectory = 'assets/icons';
  static const double grid = 24;
  static const double strokeWidth = 2;
  static const String lineCap = 'round';
  static const String lineJoin = 'round';
}

/// The three — and only three — icon sizes of the app.
enum FluiIconSize {
  /// Tab bar and navigation rail.
  tab(22),

  /// Section headers.
  section(20),

  /// Inline, next to a line of text.
  inline(18);

  new(this.value);

  final double value;
}

/// A flui glyph. Icons are never placed inside a tinted square.
class FluiGlyphIcon extends StatelessWidget {
  const new(
    this.glyph, {
    super.key,
    this.size = FluiIconSize.section,
    this.color,
    this.semanticLabel,
  });

  final FluiGlyph glyph;
  final FluiIconSize size;

  /// Defaults to the surrounding [IconTheme], then to charcoal.
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final resolved =
        color ?? IconTheme.of(context).color ?? FluiColors.charcoal;
    final dimension = size.value;
    return SvgPicture.asset(
      glyph.asset,
      width: dimension,
      height: dimension,
      colorFilter: ColorFilter.mode(resolved, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
