import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:flui/features/daily/domain/session_plan.dart';
import 'package:flui/features/daily/domain/theme_outcome.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/learning_builders.dart';

void main() {
  final onTheme = buildWord(id: 'on', themeIds: const ['reuniones']);
  final neighbour = buildWord(id: 'near', themeIds: const ['negociacion']);
  final stranger = buildWord(id: 'far', themeIds: const ['cocina']);
  final untagged = buildWord(id: 'none');
  final wordsById = {
    for (final word in [onTheme, neighbour, stranger, untagged]) word.id: word,
  };

  DailySession sessionWith(List<String> planned, {String? themeId}) =>
      DailySession(
        localDate: day(13),
        minutes: 10,
        plannedWordIds: planned,
        themeId: themeId,
      );

  ThemeOutcome outcomeOf(
    DailySession session, {
    List<Word> practiceWords = const [],
    List<String> neighbours = const ['negociacion'],
  }) => ThemeOutcome.of(
    session: session,
    wordsById: wordsById,
    practiceWords: practiceWords,
    neighbourThemeIds: neighbours,
  );

  group('ThemeOutcome.of', () {
    test('a day planned without a theme has nothing to explain', () {
      final outcome = outcomeOf(sessionWith(['far']));

      expect(outcome.fallback, isNull);
      expect(outcome.otherThemeId, isNull);
    });

    test('a word from the chosen theme is not a fallback', () {
      final outcome = outcomeOf(sessionWith(['on'], themeId: 'reuniones'));

      expect(outcome.fallback, isNull);
    });

    test('names the neighbour that lent the word', () {
      final outcome = outcomeOf(sessionWith(['near'], themeId: 'reuniones'));

      expect(outcome.fallback, ThemeFallback.neighbourTheme);
      expect(outcome.otherThemeId, 'negociacion');
    });

    test('a word from nowhere near is the catalog, and says so', () {
      final outcome = outcomeOf(sessionWith(['far'], themeId: 'reuniones'));

      expect(outcome.fallback, ThemeFallback.globalCatalog);
      expect(outcome.otherThemeId, 'cocina');
    });

    test('an untagged word leaves the other theme unnamed', () {
      final outcome = outcomeOf(sessionWith(['none'], themeId: 'reuniones'));

      expect(outcome.fallback, ThemeFallback.globalCatalog);
      expect(outcome.otherThemeId, isNull);
    });

    test('no new word plus words in practica is themed recombination', () {
      final outcome = outcomeOf(
        sessionWith(const [], themeId: 'reuniones'),
        practiceWords: [onTheme, stranger],
      );

      expect(outcome.fallback, ThemeFallback.themedPractice);
      expect(outcome.recombinationWordIds, ['on']);
    });

    test('no new word and nothing in the theme is an ordinary empty day', () {
      final outcome = outcomeOf(
        sessionWith(const [], themeId: 'reuniones'),
        practiceWords: [stranger],
      );

      expect(outcome.fallback, isNull);
      expect(outcome.recombinationWordIds, isEmpty);
    });

    test('caps recombination at the new words a day can hold', () {
      final many = [
        for (var i = 0; i < 6; i++)
          buildWord(id: 'k$i', themeIds: const ['reuniones']),
      ];

      final outcome = outcomeOf(
        sessionWith(const [], themeId: 'reuniones'),
        practiceWords: many,
      );

      expect(outcome.recombinationWordIds, hasLength(3));
    });

    test('ignores planned ids the catalog no longer has', () {
      final outcome = outcomeOf(sessionWith(['gone'], themeId: 'reuniones'));

      expect(outcome.fallback, isNull);
    });
  });
}
