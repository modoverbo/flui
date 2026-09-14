import 'package:flui/features/themes/domain/theme.dart';
import 'package:flui/features/vocabulary/domain/word.dart';

/// How close two themes are, measured by the words they share.
///
/// Step (b) of the exhaustion cascade: when a theme runs out of new words, the
/// next word should come from the theme whose vocabulary overlaps it most,
/// because that is the theme most likely to still be useful for the same job.
/// Overlap is counted over the whole catalog, not over what is left, so
/// "nearest" does not drift as the user learns.
abstract final class ThemeNeighbours {
  /// Offered themes that share at least one catalog word with [theme], most
  /// shared words first, then catalog order. [theme] itself is never in it.
  static List<Theme> nearest({
    required Theme theme,
    required List<Theme> themes,
    required List<Word> catalog,
  }) {
    final overlap = <String, int>{};
    for (final word in catalog) {
      if (!word.themeIds.contains(theme.id)) continue;
      for (final other in word.themeIds) {
        if (other == theme.id) continue;
        overlap[other] = (overlap[other] ?? 0) + 1;
      }
    }

    final neighbours = [
      for (final other in themes)
        if (other.id != theme.id &&
            other.isOffered &&
            (overlap[other.id] ?? 0) > 0)
          other,
    ];
    return neighbours..sort((a, b) {
      final byOverlap = overlap[b.id]!.compareTo(overlap[a.id]!);
      if (byOverlap != 0) return byOverlap;
      return a.sortOrder.compareTo(b.sortOrder);
    });
  }

  /// [nearest], as the ids the planner takes.
  static List<String> nearestIds({
    required Theme theme,
    required List<Theme> themes,
    required List<Word> catalog,
  }) => [
    for (final neighbour in nearest(
      theme: theme,
      themes: themes,
      catalog: catalog,
    ))
      neighbour.id,
  ];
}
