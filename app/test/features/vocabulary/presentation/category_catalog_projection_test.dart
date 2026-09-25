import 'package:flui/features/themes/domain/theme.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/features/vocabulary/presentation/category_catalog_projection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('projectPublishedWordsByFamily', () {
    test('deduplicates a word linked to multiple themes in one family', () {
      final themes = [
        theme('work', ThemeFamily.trabajo),
        theme('meeting', ThemeFamily.trabajo),
      ];
      final catalog = [
        word('clarify', ['work', 'meeting']),
      ];

      final projection = projectPublishedWordsByFamily(
        themes: themes,
        catalog: catalog,
      );

      expect(projection[ThemeFamily.trabajo], hasLength(1));
      expect(projection[ThemeFamily.trabajo]!.single.id, 'clarify');
    });

    test('includes a word once in every matching family', () {
      final themes = [
        theme('work', ThemeFamily.trabajo),
        theme('social', ThemeFamily.social),
      ];
      final catalog = [
        word('clarify', ['work', 'social']),
      ];

      final projection = projectPublishedWordsByFamily(
        themes: themes,
        catalog: catalog,
      );

      expect(projection[ThemeFamily.trabajo]!.single.id, 'clarify');
      expect(projection[ThemeFamily.social]!.single.id, 'clarify');
    });

    test('excludes words without themes', () {
      final projection = projectPublishedWordsByFamily(
        themes: [theme('work', ThemeFamily.trabajo)],
        catalog: [word('solitary', [])],
      );

      expect(projection.values.every((words) => words.isEmpty), isTrue);
    });

    test('preserves the catalog order within each family', () {
      final themes = [
        theme('work', ThemeFamily.trabajo),
        theme('social', ThemeFamily.social),
      ];
      final catalog = [
        word('later-sort-order', ['work'], sortOrder: 30),
        word('earlier-sort-order', ['work', 'social'], sortOrder: 10),
        word('middle-sort-order', ['work'], sortOrder: 20),
      ];

      final projection = projectPublishedWordsByFamily(
        themes: themes,
        catalog: catalog,
      );

      expect(projection[ThemeFamily.trabajo]!.map((item) => item.id), [
        'later-sort-order',
        'earlier-sort-order',
        'middle-sort-order',
      ]);
      expect(projection[ThemeFamily.social]!.map((item) => item.id), [
        'earlier-sort-order',
      ]);
    });

    test('returns an empty list for every family when inputs are empty', () {
      final projection = projectPublishedWordsByFamily(themes: [], catalog: []);

      expect(projection.keys, containsAll(ThemeFamily.values));
      expect(projection.values.every((words) => words.isEmpty), isTrue);
    });
  });
}

Theme theme(String id, ThemeFamily family) => Theme(
  id: id,
  slug: id,
  family: family,
  name: id,
  tagline: id,
  jtbd: id,
  contentType: ThemeContentType.wordDriven,
  status: ThemeStatus.live,
  sortOrder: 0,
);

Word word(String id, List<String> themeIds, {int sortOrder = 0}) => Word(
  id: id,
  slug: id,
  lemma: id,
  partOfSpeech: PartOfSpeech.sustantivo,
  syllables: [id],
  stressedSyllable: 1,
  explanation: id,
  exampleSentence: id,
  register: WordRegister.neutral,
  pedantryRisk: 0,
  sortOrder: sortOrder,
  themeIds: themeIds,
);
