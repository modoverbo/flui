import 'package:flui/features/themes/domain/theme.dart';
import 'package:flui/features/vocabulary/domain/word.dart';

/// Groups the supplied published catalog by the families of each word's themes.
///
/// The caller supplies the published catalog; this projection does not filter
/// catalog entries by publication status.
Map<ThemeFamily, List<Word>> projectPublishedWordsByFamily({
  required List<Theme> themes,
  required List<Word> catalog,
}) {
  final familyByThemeId = {for (final theme in themes) theme.id: theme.family};
  final wordsByFamily = {
    for (final family in ThemeFamily.values) family: <Word>[],
  };
  final wordIdsByFamily = {
    for (final family in ThemeFamily.values) family: <String>{},
  };

  for (final word in catalog) {
    final matchingFamilies = <ThemeFamily>{
      for (final themeId in word.themeIds) ?familyByThemeId[themeId],
    };

    for (final family in matchingFamilies) {
      if (wordIdsByFamily[family]!.add(word.id)) {
        wordsByFamily[family]!.add(word);
      }
    }
  }

  return Map.unmodifiable({
    for (final family in ThemeFamily.values)
      family: List<Word>.unmodifiable(wordsByFamily[family]!),
  });
}
