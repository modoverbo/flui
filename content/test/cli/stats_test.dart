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

    expect(stats.gaps, hasLength(16));
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
