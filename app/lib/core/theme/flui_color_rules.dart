import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_theme_colors.dart';
import 'package:material_ui/material_ui.dart';

/// A foreground on a background, with the contrast it has to reach.
@immutable
final class ColorPair {
  const new(this.name, this.foreground, this.background);

  final String name;
  final Color foreground;
  final Color background;
}

/// The four — and only four — places yellow is allowed to appear.
enum YellowRole {
  /// The filled part of a progress bar or meter.
  progressFill,

  /// The "tu palabra de hoy" marker.
  wordOfTheDayMarker,

  /// A streak day or an unlocked achievement.
  streakMoment,

  /// One word of a marketing headline.
  headlineWord,
}

/// Colour rules of the brand, as data, so a test can fail when a pairing
/// drifts. Numbers are WCAG 2.x contrast ratios.
abstract final class FluiColorRules {
  /// Minimum for body text.
  static const double aaText = 4.5;

  /// Minimum for text at 24 px or 18.66 px bold, and for UI borders.
  static const double aaLargeText = 3;

  /// Pairs that must stay readable as text.
  ///
  /// The 28 theme-colour pairs (`paper` on each theme surface, `ink` on
  /// each theme tint) are generated from [FluiThemeColors.all], not
  /// hand-authored — a themes.yml edit that changes a hue can't drift this
  /// table (`01-design-system.md` §1.2).
  static final List<ColorPair> readable = [
    const ColorPair('charcoal on cream', FluiColors.charcoal, FluiColors.cream),
    const ColorPair(
      'charcoal on surface',
      FluiColors.charcoal,
      FluiColors.surface,
    ),
    const ColorPair('gray on cream', FluiColors.gray, FluiColors.cream),
    const ColorPair('alert on cream', FluiColors.alert, FluiColors.cream),
    const ColorPair(
      'cream on greenDeep',
      FluiColors.cream,
      FluiColors.greenDeep,
    ),
    const ColorPair(
      'cream on greenSecondary',
      FluiColors.cream,
      FluiColors.greenSecondary,
    ),
    const ColorPair(
      'cream on progressSurface',
      FluiColors.cream,
      FluiColors.progressSurface,
    ),
    const ColorPair(
      'creamMuted on greenDeep',
      FluiColors.creamMuted,
      FluiColors.greenDeep,
    ),
    const ColorPair(
      'creamMuted on greenSecondary',
      FluiColors.creamMuted,
      FluiColors.greenSecondary,
    ),
    const ColorPair(
      'creamMuted on progressSurface',
      FluiColors.creamMuted,
      FluiColors.progressSurface,
    ),
    const ColorPair(
      'yellow on greenDeep',
      FluiColors.yellowElectric,
      FluiColors.greenDeep,
    ),
    const ColorPair(
      'yellow on progressSurface',
      FluiColors.yellowElectric,
      FluiColors.progressSurface,
    ),
    const ColorPair(
      'charcoal on yellow',
      FluiColors.charcoal,
      FluiColors.yellowElectric,
    ),
    const ColorPair(
      'charcoal on yellowTint',
      FluiColors.charcoal,
      FluiColors.yellowTint,
    ),
    const ColorPair(
      'greenDeep on greenTint',
      FluiColors.greenDeep,
      FluiColors.greenTint,
    ),
    for (final theme in FluiThemeColors.all) ...[
      ColorPair(
        'paper on ${theme.slug} theme surface',
        theme.on,
        theme.surface,
      ),
      ColorPair('ink on ${theme.slug} theme tint', FluiColors.ink, theme.tint),
    ],
  ];

  /// Non-text pairs: borders, icons and the shake outline. They only have to
  /// reach [aaLargeText].
  static const List<ColorPair> borders = [
    ColorPair('amber border on cream', FluiColors.amber, FluiColors.cream),
    ColorPair('amber border on surface', FluiColors.amber, FluiColors.surface),
  ];

  /// Pairs the design must never produce. The test asserts they really are
  /// unreadable, so nobody "fixes" the rule by using them anyway.
  static const List<ColorPair> forbidden = [
    ColorPair('gray on greenDeep', FluiColors.gray, FluiColors.greenDeep),
    ColorPair(
      'gray on progressSurface',
      FluiColors.gray,
      FluiColors.progressSurface,
    ),
    ColorPair('yellow on cream', FluiColors.yellowElectric, FluiColors.cream),
    ColorPair(
      'yellow on surface',
      FluiColors.yellowElectric,
      FluiColors.surface,
    ),
  ];

  /// A yellow surface always carries charcoal, never green.
  static const Color onYellow = FluiColors.charcoal;

  /// Secondary text on any green surface.
  static const Color onGreenSecondaryText = FluiColors.creamMuted;

  /// Secondary text on cream.
  static const Color onCreamSecondaryText = FluiColors.gray;
}
