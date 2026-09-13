import 'package:material_ui/material_ui.dart';

/// Type hierarchy from docs/brand.md. Fonts are bundled assets (OFL-1.1).
abstract final class FluiTypography {
  static const displayFamily = 'PlusJakartaSans';
  static const textFamily = 'Inter';

  static const featuredWord = TextStyle(
    fontFamily: displayFamily,
    fontWeight: FontWeight.w800,
    fontSize: 40,
    height: 48 / 40,
    letterSpacing: -0.5,
  );

  static const h1 = TextStyle(
    fontFamily: displayFamily,
    fontWeight: FontWeight.w800,
    fontSize: 28,
    height: 36 / 28,
    letterSpacing: -0.25,
  );

  static const h2 = TextStyle(
    fontFamily: displayFamily,
    fontWeight: FontWeight.w700,
    fontSize: 22,
    height: 28 / 22,
  );

  static const h3 = TextStyle(
    fontFamily: displayFamily,
    fontWeight: FontWeight.w700,
    fontSize: 18,
    height: 24 / 18,
  );

  static const body = TextStyle(
    fontFamily: textFamily,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 24 / 16,
  );

  static const bodyEmphasis = TextStyle(
    fontFamily: textFamily,
    fontWeight: FontWeight.w600,
    fontSize: 16,
    height: 24 / 16,
  );

  static const label = TextStyle(
    fontFamily: textFamily,
    fontWeight: FontWeight.w600,
    fontSize: 14,
    height: 20 / 14,
  );

  static const caption = TextStyle(
    fontFamily: textFamily,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    height: 16 / 12,
  );

  /// Material text theme built from the brand hierarchy.
  static TextTheme textTheme(Color color, Color secondaryColor) {
    return TextTheme(
      displaySmall: featuredWord.copyWith(color: color),
      headlineMedium: h1.copyWith(color: color),
      headlineSmall: h2.copyWith(color: color),
      titleLarge: h3.copyWith(color: color),
      titleMedium: bodyEmphasis.copyWith(color: color),
      titleSmall: label.copyWith(color: color),
      bodyLarge: body.copyWith(color: color),
      bodyMedium: body.copyWith(color: color, fontSize: 14, height: 20 / 14),
      bodySmall: caption.copyWith(color: secondaryColor),
      labelLarge: label.copyWith(color: color),
      labelMedium: label.copyWith(color: color, fontSize: 12, height: 16 / 12),
      labelSmall: caption.copyWith(color: secondaryColor),
    );
  }
}
