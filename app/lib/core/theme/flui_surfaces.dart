import 'package:flui/core/theme/flui_colors.dart';
import 'package:material_ui/material_ui.dart';

/// Surfaces are flat. Depth comes from hairlines and from the green plates,
/// never from elevation — with exactly one exception, [ctaDockShadow], which
/// separates the sticky call-to-action dock from the content scrolling
/// behind it.
abstract final class FluiSurfaces {
  static const double hairlineWidth = 1;

  static const BorderSide hairlineOnCream = BorderSide(
    color: FluiColors.hairlineOnCream,
  );

  static const BorderSide hairlineOnGreen = BorderSide(
    color: FluiColors.hairlineOnGreen,
  );

  static Border borderOnCream() => const Border.fromBorderSide(hairlineOnCream);

  static Border borderOnGreen() => const Border.fromBorderSide(hairlineOnGreen);

  /// The only shadow in the app.
  static const List<BoxShadow> ctaDockShadow = [
    BoxShadow(color: Color(0x140B3D34), blurRadius: 24, offset: Offset(0, -8)),
  ];

  /// Hairline for [onDark] surfaces or cream ones.
  static BorderSide hairline({required bool onDark}) =>
      onDark ? hairlineOnGreen : hairlineOnCream;
}
