import 'package:content/src/cli/stats.dart';
import 'package:content/src/model/word.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';
import '../support/validation_harness.dart';

Word themed(String slug, List<String> themes, {String status = 'approved'}) {
  final map = validWordMap()
    ..['slug'] = slug
    ..['lemma'] = slug
    ..['syllables'] = [slug]
    ..['stressed_syllable'] = 1
    ..['status'] = status
    ..['themes'] = [
      for (final theme in themes) {'slug': theme, 'relevance': 3},
    ];
  return Word.fromMap(map);
}

void main() {
  test('counts words by status, theme and part of speech', () {
    final stats = catalogStats(
      [
        themed('uno', ['reuniones']),
        themed('dos', ['reuniones', 'entrevistas']),
        themed('tres', ['entrevistas'], status: 'draft'),
      ],
      testTaxonomy,
    );

    expect(stats.totalWords, 3);
    expect(stats.byStatus[WordStatus.approved], 2);
    expect(stats.byStatus[WordStatus.draft], 1);
    expect(stats.byTheme['reuniones'], 2);
    expect(stats.byTheme['entrevistas'], 2);
    expect(stats.byPartOfSpeech[PartOfSpeech.adjetivo], 3);
  });

  test('reports exercises and readings per word', () {
    final stats = catalogStats([
      themed('uno', ['reuniones']),
    ], testTaxonomy);

    expect(stats.totalExercises, 8);
    expect(stats.exercisesPerWord, 8.0);
    expect(stats.totalReadings, 3);
  });

  test('estimates days of content from approved words at one per day', () {
    final stats = catalogStats(
      [
        themed('uno', ['reuniones']),
        themed('dos', ['reuniones']),
        themed('tres', ['reuniones'], status: 'gated'),
      ],
      testTaxonomy,
    );

    expect(stats.estimatedDays, 2);
  });

  test('every theme short of the 90-day target is a gap', () {
    final stats = catalogStats([
      themed('uno', ['reuniones']),
    ], testTaxonomy);

    expect(stats.gaps, hasLength(testTaxonomy.themes.length));
    final reuniones = stats.gaps.firstWhere((g) => g.slug == 'reuniones');
    expect(reuniones.approved, 1);
    expect(reuniones.missingForNinetyDays, 92);
    final empty = stats.gaps.firstWhere((g) => g.slug == 'negociacion');
    expect(empty.approved, 0);
  });

  test('a gap keeps the shortfall against the 90-day target', () {
    final stats = catalogStats([
      themed('uno', ['entrevistas']),
    ], testTaxonomy);
    final gap = stats.gaps.firstWhere((g) => g.slug == 'reuniones');

    expect(gap.missingForNinetyDays, 93);
  });

  group('confusion links', () {
    Word confusable(
      String slug,
      List<String> confusedWith, {
      String status = 'approved',
      List<String> family = const [],
    }) => Word.fromMap(
      validWordMap()
        ..['slug'] = slug
        ..['lemma'] = slug
        ..['syllables'] = [slug]
        ..['stressed_syllable'] = 1
        ..['status'] = status
        ..['family'] = family
        ..['confusions'] = [
          for (final other in confusedWith)
            {
              'confused_with': other,
              'difference': 'Una diferencia clara entre las dos palabras.',
              'memory_trick': 'Un truco corto para recordarla.',
            },
        ],
    );

    test('counts how many confusions reach a catalogue word', () {
      final stats = catalogStats([
        confusable('talante', ['tajante', 'semblante']),
        confusable('tajante', ['talante']),
      ], testTaxonomy);

      expect(stats.confusions, 3);
      expect(stats.confusionsResolved, 2);
      expect(stats.confusionsUnresolved, 1);
    });

    test('a draft is not part of the catalogue', () {
      final stats = catalogStats([
        confusable('talante', ['tajante']),
        confusable('tajante', ['talante'], status: 'draft'),
      ], testTaxonomy);

      expect(stats.confusions, 1);
      expect(stats.confusionsResolved, 0);
      expect(stats.confusionsUnresolved, 1);
    });

    test('counts the pairs only one side declares', () {
      final stats = catalogStats([
        confusable('aludir', ['insinuar']),
        confusable('insinuar', ['insistir']),
        confusable('cesion', ['concesion']),
        confusable('concesion', ['cesion']),
      ], testTaxonomy);

      expect(stats.confusionsResolved, 3);
      expect(stats.oneDirectionalPairs, 1);
    });

    test('reports the counts in text and in JSON', () {
      final stats = catalogStats([
        confusable('talante', ['tajante']),
        confusable('tajante', ['semblante']),
      ], testTaxonomy);

      expect(stats.format(), contains('confusions'));
      expect(stats.format(), contains('unresolved'));
      expect(stats.toJson()['confusions'], 2);
      expect(stats.toJson()['confusionsResolved'], 1);
      expect(stats.toJson()['confusionsUnresolved'], 1);
      expect(stats.toJson()['oneDirectionalPairs'], 1);
    });
  });

  test('renders a text report', () {
    final report = catalogStats(
      [
        themed('uno', ['reuniones']),
      ],
      testTaxonomy,
    ).format();

    expect(report, contains('reuniones'));
    expect(report, contains('adjetivo'));
    expect(report, contains('days of content'));
  });

  test('renders JSON', () {
    final json = catalogStats(
      [
        themed('uno', ['reuniones']),
      ],
      testTaxonomy,
    ).toJson();

    expect(json['totalWords'], 1);
    expect((json['byTheme']! as Map<String, Object?>)['reuniones'], 1);
  });
}
