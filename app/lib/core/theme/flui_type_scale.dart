import 'package:material_ui/material_ui.dart';

/// The bundled families (OFL-1.1 static TTFs, no runtime font fetching).
abstract final class FluiFonts {
  static const String display = 'PlusJakartaSans';
  static const String text = 'Inter';
}

/// The eight roles of the flui type scale. A screen picks a role, never a
/// size: that is what keeps the hierarchy from collapsing into one headline.
enum FluiTypeRole {
  wordHero,
  displayL,
  titleL,
  titleM,
  bodyL,
  body,
  label,
  phonetic,
}

// Text roles do not change with the viewport: reading measure and a
// comfortable body size do not depend on the window.
const _bodyL = TextStyle(
  fontFamily: FluiFonts.text,
  fontWeight: FontWeight.w400,
  fontSize: 18,
  height: 28 / 18,
  letterSpacing: 0,
);

const _body = TextStyle(
  fontFamily: FluiFonts.text,
  fontWeight: FontWeight.w400,
  fontSize: 16,
  height: 26 / 16,
  letterSpacing: 0,
);

const _label = TextStyle(
  fontFamily: FluiFonts.text,
  fontWeight: FontWeight.w600,
  fontSize: 13,
  height: 16 / 13,
  letterSpacing: 13 * 0.06,
);

const _phonetic = TextStyle(
  fontFamily: FluiFonts.text,
  fontWeight: FontWeight.w400,
  fontSize: 15,
  height: 20 / 15,
  letterSpacing: 0,
  fontFeatures: [FontFeature.tabularFigures()],
);

/// The flui type scale, in its two viewport variants.
///
/// Two rules hold in both and are enforced by tests: display leading is
/// `<= 1.05`, body leading is `>= 1.55`.
enum FluiTypeScale {
  /// Phone and narrow windows.
  compact(
    wordHero: TextStyle(
      fontFamily: FluiFonts.display,
      fontWeight: FontWeight.w800,
      fontSize: 72,
      height: 68 / 72,
      letterSpacing: 72 * -0.03,
    ),
    displayL: TextStyle(
      fontFamily: FluiFonts.display,
      fontWeight: FontWeight.w700,
      fontSize: 44,
      height: 46 / 44,
      letterSpacing: 44 * -0.02,
    ),
    titleL: TextStyle(
      fontFamily: FluiFonts.display,
      fontWeight: FontWeight.w700,
      fontSize: 28,
      height: 32 / 28,
      letterSpacing: 28 * -0.015,
    ),
    titleM: TextStyle(
      fontFamily: FluiFonts.display,
      fontWeight: FontWeight.w600,
      fontSize: 22,
      height: 28 / 22,
      letterSpacing: 22 * -0.01,
    ),
  ),

  /// Web and wide windows.
  wide(
    wordHero: TextStyle(
      fontFamily: FluiFonts.display,
      fontWeight: FontWeight.w800,
      fontSize: 112,
      height: 104 / 112,
      letterSpacing: 112 * -0.03,
    ),
    displayL: TextStyle(
      fontFamily: FluiFonts.display,
      fontWeight: FontWeight.w700,
      fontSize: 64,
      height: 62 / 64,
      letterSpacing: 64 * -0.02,
    ),
    titleL: TextStyle(
      fontFamily: FluiFonts.display,
      fontWeight: FontWeight.w700,
      fontSize: 34,
      height: 38 / 34,
      letterSpacing: 34 * -0.015,
    ),
    titleM: TextStyle(
      fontFamily: FluiFonts.display,
      fontWeight: FontWeight.w600,
      fontSize: 24,
      height: 30 / 24,
      letterSpacing: 24 * -0.01,
    ),
  );

  new({
    required this.wordHero,
    required this.displayL,
    required this.titleL,
    required this.titleM,
  });

  /// Roles whose leading must stay at or below 1.05.
  static const Set<FluiTypeRole> displayRoles = {
    FluiTypeRole.wordHero,
    FluiTypeRole.displayL,
  };

  /// Roles whose leading must stay at or above 1.55.
  static const Set<FluiTypeRole> bodyRoles = {
    FluiTypeRole.bodyL,
    FluiTypeRole.body,
  };

  /// The word itself, the only place this size is allowed.
  final TextStyle wordHero;

  /// Page-owning statement: welcome, onboarding slide, paywall headline.
  final TextStyle displayL;

  /// Screen title.
  final TextStyle titleL;

  /// Card and section title.
  final TextStyle titleM;

  /// Lead paragraph and exercise sentences.
  TextStyle get bodyL => _bodyL;

  /// Running text.
  TextStyle get body => _body;

  /// Eyebrow above a section. Always rendered through [labelText].
  TextStyle get label => _label;

  /// Syllables and IPA, with tabular figures.
  TextStyle get phonetic => _phonetic;

  TextStyle styleOf(FluiTypeRole role) => switch (role) {
    FluiTypeRole.wordHero => wordHero,
    FluiTypeRole.displayL => displayL,
    FluiTypeRole.titleL => titleL,
    FluiTypeRole.titleM => titleM,
    FluiTypeRole.bodyL => bodyL,
    FluiTypeRole.body => body,
    FluiTypeRole.label => label,
    FluiTypeRole.phonetic => phonetic,
  };

  /// Labels are set in caps; the copy stays sentence case in the ARB file.
  static String labelText(String value) => value.toUpperCase();

  /// Material's text theme, so framework widgets inherit the scale.
  TextTheme textTheme(Color color, Color secondaryColor) => TextTheme(
    displayLarge: wordHero.copyWith(color: color),
    displayMedium: displayL.copyWith(color: color),
    displaySmall: displayL.copyWith(color: color),
    headlineLarge: titleL.copyWith(color: color),
    headlineMedium: titleL.copyWith(color: color),
    headlineSmall: titleM.copyWith(color: color),
    titleLarge: titleM.copyWith(color: color),
    titleMedium: body.copyWith(color: color, fontWeight: FontWeight.w600),
    titleSmall: label.copyWith(color: color),
    bodyLarge: bodyL.copyWith(color: color),
    bodyMedium: body.copyWith(color: color),
    bodySmall: body.copyWith(
      color: secondaryColor,
      fontSize: 14,
      height: 22 / 14,
    ),
    labelLarge: body.copyWith(color: color, fontWeight: FontWeight.w600),
    labelMedium: label.copyWith(color: color),
    labelSmall: label.copyWith(color: secondaryColor),
  );
}
