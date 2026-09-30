import 'package:flui/features/themes/domain/theme.dart';

/// Picks the themes the daily prompt opens on, in catalog order.
///
/// Why three, and why an "Explorar" door next to them: Patall, Cooper and
/// Robinson (2008) found the motivational benefit of choice is largest at
/// **two to four** options and falls away when a list grows past that;
/// Scheibehenne, Greifeneder and Todd (2010) then showed in a meta-analysis
/// that long lists are not actively *harmful*, merely not helpful. So the
/// prompt shows [recommendedCount] cards plus a full list for anyone who wants
/// it, and the user keeps at most [maxUserThemes] themes of their own. There
/// is no minimum streak on a theme: changing it any day is free.
abstract final class ThemeRecommender {
  /// Cards shown in the daily prompt, next to "Explorar" and "Sorpréndeme".
  static const recommendedCount = 3;

  /// "Tus temas" never grows past this: a shortlist is a shortlist.
  static const maxUserThemes = 3;

  /// Every offered theme, in catalog order.
  static List<Theme> rank({required List<Theme> themes}) {
    final offered = [
      for (final theme in themes)
        if (theme.isOffered) theme,
    ];
    return offered..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// The top [recommendedCount] themes, or fewer when the catalog is smaller.
  static List<Theme> recommend({required List<Theme> themes}) =>
      rank(themes: themes).take(recommendedCount).toList();
}
