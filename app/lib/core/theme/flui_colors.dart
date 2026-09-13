import 'package:material_ui/material_ui.dart';

/// Brand palette from docs/brand.md plus derived tints.
///
/// Rules: one yellow highlight per screen, never yellow text on cream.
abstract final class FluiColors {
  // Brand colors.
  static const cream = Color(0xFFF8F8F6);
  static const greenDeep = Color(0xFF0B3D34);
  static const greenSecondary = Color(0xFF165A4B);
  static const charcoal = Color(0xFF0F0F0F);
  static const yellowElectric = Color(0xFFFFD60A);
  static const gray = Color(0xFF687280);

  // Derived tints and roles.
  /// Cards and elevated surfaces on the cream background.
  static const surface = Color(0xFFFFFFFF);

  /// Soft green for selected cards and info backgrounds (text: greenDeep).
  static const greenTint = Color(0xFFE2EDE9);

  /// Soft yellow for hint backgrounds (text: charcoal).
  static const yellowTint = Color(0xFFFFF3C4);

  /// Hairlines and input borders (decorative, not text).
  static const outline = Color(0xFFD5DBD8);

  /// Disabled fills.
  static const disabled = Color(0xFFE6E8E5);

  /// Form validation messages. Warm and readable, never an alarming red.
  static const alert = Color(0xFF9C3D1B);

  /// Dark surface for the progress area ("Tu progreso").
  static const progressSurface = Color(0xFF08302A);
}
