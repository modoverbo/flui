import 'package:material_ui/material_ui.dart';

/// Corner radii, one per role. A primary call to action is a 14 px
/// rectangle; it is never a pill, and `pill` is for chips only.
abstract final class FluiRadii {
  /// Chips, inputs, inline tags.
  static const double chip = 8;

  /// Primary call to action.
  static const double cta = 14;

  /// Cards and tiles.
  static const double card = 16;

  /// Hero plates, bottom sheets, full-bleed green blocks.
  static const double plate = 28;

  /// Chips only.
  static const double pillRadius = 999;

  static const BorderRadius chipAll = BorderRadius.all(Radius.circular(chip));
  static const BorderRadius ctaAll = BorderRadius.all(Radius.circular(cta));
  static const BorderRadius cardAll = BorderRadius.all(Radius.circular(card));
  static const BorderRadius plateAll = BorderRadius.all(Radius.circular(plate));
  static const BorderRadius pill = BorderRadius.all(
    Radius.circular(pillRadius),
  );
}
