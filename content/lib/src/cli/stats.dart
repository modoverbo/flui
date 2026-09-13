import 'package:content/src/model/theme.dart';
import 'package:content/src/model/word.dart';

/// How far a theme is from being able to run on its own for a quarter.
final class ThemeGap {
  const ThemeGap({
    required this.slug,
    required this.approved,
    required this.missingForNinetyDays,
  });

  final String slug;
  final int approved;
  final int missingForNinetyDays;
}

/// Catalog counts used by `dart run content:stats`.
final class CatalogStats {
  const CatalogStats({
    required this.totalWords,
    required this.byStatus,
    required this.byTheme,
    required this.byPartOfSpeech,
    required this.totalExercises,
    required this.totalReadings,
    required this.estimatedDays,
    required this.gaps,
  });

  final int totalWords;
  final Map<WordStatus, int> byStatus;
  final Map<String, int> byTheme;
  final Map<PartOfSpeech, int> byPartOfSpeech;
  final int totalExercises;
  final int totalReadings;

  /// Approved words, one introduced per day.
  final int estimatedDays;
  final List<ThemeGap> gaps;

  double get exercisesPerWord =>
      totalWords == 0 ? 0 : totalExercises / totalWords;

  Map<String, Object?> toJson() => {
    'totalWords': totalWords,
    'byStatus': {for (final e in byStatus.entries) e.key.name: e.value},
    'byTheme': byTheme,
    'byPartOfSpeech': {
      for (final e in byPartOfSpeech.entries) e.key.name: e.value,
    },
    'totalExercises': totalExercises,
    'totalReadings': totalReadings,
    'exercisesPerWord': exercisesPerWord,
    'estimatedDays': estimatedDays,
    'gaps': [
      for (final gap in gaps)
        {
          'slug': gap.slug,
          'approved': gap.approved,
          'missingForNinetyDays': gap.missingForNinetyDays,
        },
    ],
  };

  String format() {
    final buffer = StringBuffer()
      ..writeln('flui content catalog')
      ..writeln('  words                 $totalWords')
      ..writeln(
        '  exercises             $totalExercises '
        '(${exercisesPerWord.toStringAsFixed(1)} per word)',
      )
      ..writeln('  readings              $totalReadings')
      ..writeln('  days of content       $estimatedDays (1 new word per day)')
      ..writeln()
      ..writeln('by status');
    for (final status in WordStatus.values) {
      buffer.writeln('  ${status.name.padRight(12)} ${byStatus[status] ?? 0}');
    }
    buffer
      ..writeln()
      ..writeln('by part of speech');
    for (final pos in PartOfSpeech.values) {
      buffer.writeln('  ${pos.name.padRight(12)} ${byPartOfSpeech[pos] ?? 0}');
    }
    buffer
      ..writeln()
      ..writeln('by theme');
    final themes = byTheme.keys.toList()..sort();
    for (final theme in themes) {
      buffer.writeln('  ${theme.padRight(26)} ${byTheme[theme]}');
    }
    if (gaps.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('coverage gaps (approved words, still needed for 90 days)');
      for (final gap in gaps) {
        buffer.writeln(
          '  ${gap.slug.padRight(26)} ${gap.approved.toString().padLeft(4)} '
          '   +${gap.missingForNinetyDays}',
        );
      }
    }
    return buffer.toString();
  }
}

/// A theme needs 90 introductions plus the 3-candidate margin the scheduling
/// simulation demands on the last day.
const ninetyDayTarget = 93;

CatalogStats catalogStats(List<Word> words, ThemeTaxonomy taxonomy) {
  final byStatus = <WordStatus, int>{};
  final byTheme = <String, int>{};
  final byPartOfSpeech = <PartOfSpeech, int>{};
  final approvedByTheme = <String, int>{};
  var exercises = 0;
  var readings = 0;

  for (final word in words) {
    byStatus[word.status] = (byStatus[word.status] ?? 0) + 1;
    byPartOfSpeech[word.partOfSpeech] =
        (byPartOfSpeech[word.partOfSpeech] ?? 0) + 1;
    exercises += word.exercises.length;
    readings += word.readings.length;
    for (final theme in word.themes) {
      byTheme[theme.slug] = (byTheme[theme.slug] ?? 0) + 1;
      if (word.status == WordStatus.approved) {
        approvedByTheme[theme.slug] = (approvedByTheme[theme.slug] ?? 0) + 1;
      }
    }
  }

  final gaps = <ThemeGap>[];
  for (final theme in taxonomy.themes) {
    final approved = approvedByTheme[theme.slug] ?? 0;
    if (approved >= ninetyDayTarget) continue;
    gaps.add(
      ThemeGap(
        slug: theme.slug,
        approved: approved,
        missingForNinetyDays: ninetyDayTarget - approved,
      ),
    );
  }

  return CatalogStats(
    totalWords: words.length,
    byStatus: byStatus,
    byTheme: byTheme,
    byPartOfSpeech: byPartOfSpeech,
    totalExercises: exercises,
    totalReadings: readings,
    estimatedDays: byStatus[WordStatus.approved] ?? 0,
    gaps: gaps,
  );
}
