import 'package:content/src/model/catalogue.dart';
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
    required this.confusions,
    required this.confusionsResolved,
    required this.oneDirectionalPairs,
  });

  final int totalWords;
  final Map<WordStatus, int> byStatus;
  final Map<String, int> byTheme;
  final Map<PartOfSpeech, int> byPartOfSpeech;
  final int totalExercises;
  final int totalReadings;

  /// Confusions declared by the approved words — the ones the seed emits.
  final int confusions;

  /// How many of them name another approved word, so `content:emit` can write
  /// `word_confusions.confused_word_id` and the app can match on the row
  /// instead of on a lemma string.
  final int confusionsResolved;

  /// Pairs of approved words where only one of the two files declares the
  /// other. `confusion_symmetry` blocks these; this is the same count without
  /// running the validator.
  final int oneDirectionalPairs;

  /// Confusions whose word is not in the catalog. Most of them are: a paronym
  /// is usually a word flui never teaches.
  int get confusionsUnresolved => confusions - confusionsResolved;

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
    'confusions': confusions,
    'confusionsResolved': confusionsResolved,
    'confusionsUnresolved': confusionsUnresolved,
    'oneDirectionalPairs': oneDirectionalPairs,
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
      ..writeln(
        '  confusions            $confusions '
        '($confusionsResolved linked to a catalog word, '
        '$confusionsUnresolved unresolved)',
      )
      ..writeln(
        '  one-directional       $oneDirectionalPairs '
        '(pairs only one file declares)',
      )
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

  final links = confusionLinks(words);

  return CatalogStats(
    totalWords: words.length,
    byStatus: byStatus,
    byTheme: byTheme,
    byPartOfSpeech: byPartOfSpeech,
    totalExercises: exercises,
    totalReadings: readings,
    estimatedDays: byStatus[WordStatus.approved] ?? 0,
    gaps: gaps,
    confusions: links.declared,
    confusionsResolved: links.resolved,
    oneDirectionalPairs: links.oneDirectional,
  );
}

/// How the confusions of the approved words relate to the catalog itself.
///
/// `resolved` is the number `content:emit` turns into a `confused_word_id`;
/// `oneDirectional` is what `confusion_symmetry` blocks on.
({int declared, int resolved, int oneDirectional}) confusionLinks(
  List<Word> words,
) {
  final approved = [
    for (final word in words)
      if (word.status == WordStatus.approved) word,
  ];
  final catalogue = Catalogue.of(approved);

  var declared = 0;
  var resolved = 0;
  final pairs = <String, Set<String>>{
    for (final word in approved) word.slug: <String>{},
  };
  for (final word in approved) {
    for (final confusion in word.confusions) {
      declared++;
      final other = catalogue.confusableOf(word, confusion);
      if (other == null) continue;
      resolved++;
      pairs[word.slug]!.add(other.slug);
    }
  }

  var oneDirectional = 0;
  for (final entry in pairs.entries) {
    for (final other in entry.value) {
      if (!pairs[other]!.contains(entry.key)) oneDirectional++;
    }
  }

  return (
    declared: declared,
    resolved: resolved,
    oneDirectional: oneDirectional,
  );
}
