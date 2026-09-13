import 'package:material_ui/material_ui.dart';

/// Brand palette from docs/brand.md plus derived tints.
///
/// Rules live in `flui_color_rules.dart` and are enforced by a test: yellow
/// has exactly four roles, yellow buttons carry charcoal, gray never touches
/// deep green and yellow is never text or a bare fill on cream.
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

  /// Secondary text on deep green: cream at 70 %, flattened to an opaque
  /// value. Replaces [gray], which is unreadable there (2.49:1).
  static const creamMuted = Color(0xFFB9C4BF);

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

  /// A wrong answer borders in amber, never red: it is a "not yet", not a
  /// failure.
  static const amber = Color(0xFFB26A00);

  /// Dark surface for the progress area ("Tu progreso").
  static const progressSurface = Color(0xFF08302A);

  /// Center of the green plate gradient (see [plateEdge]).
  static const Color plateCenter = greenSecondary;

  /// Edge of the green plate gradient.
  static const Color plateEdge = greenDeep;

  /// Hairline on cream: `rgba(11, 61, 52, .08)`.
  static const Color hairlineOnCream = Color(0x140B3D34);

  /// Hairline on green: `rgba(248, 248, 246, .10)`.
  static const Color hairlineOnGreen = Color(0x1AF8F8F6);
}
