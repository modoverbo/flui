import 'package:flui/features/vocabulary/domain/spoken_word_use.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/learning_builders.dart';

void main() {
  group('SpokenWordUse.detect', () {
    final importante = buildWord(id: 'w-importante', lemma: 'importante');
    final planteado = buildWord(
      id: 'w-plantear',
      lemma: 'plantear',
      partOfSpeech: PartOfSpeech.verbo,
    );
    final trayectoria = buildWord(id: 'w-trayectoria', lemma: 'trayectoria');
    final wordsById = {
      for (final word in [importante, planteado, trayectoria]) word.id: word,
    };

    test('matches a plain lowercase token', () {
      final used = SpokenWordUse.detect(
        targetWordIds: [importante.id, trayectoria.id],
        wordsById: wordsById,
        transcript: 'Tomé una decisión importante esta mañana.',
      );

      expect(used, [importante.id]);
    });

    test('is accent- and case-insensitive', () {
      final used = SpokenWordUse.detect(
        targetWordIds: [importante.id],
        wordsById: wordsById,
        transcript: 'Fue una decisión IMPORTÁNTE, la más importante de todas.',
      );

      expect(used, [importante.id]);
    });

    test('matches a known inflected form of a verb', () {
      final used = SpokenWordUse.detect(
        targetWordIds: [planteado.id],
        wordsById: wordsById,
        transcript: 'Lo planteé con calma antes de decidir.',
      );

      expect(used, [planteado.id]);
    });

    test('does not claim a word that never appears', () {
      final used = SpokenWordUse.detect(
        targetWordIds: [importante.id, trayectoria.id],
        wordsById: wordsById,
        transcript: 'Organicé mi mañana antes de comenzar.',
      );

      expect(used, isEmpty);
    });

    test('never over-claims a short unrelated word as a stem match', () {
      // "importante" must not match just because the transcript happens to
      // contain a short, unrelated word sharing its first letters.
      final used = SpokenWordUse.detect(
        targetWordIds: [importante.id],
        wordsById: wordsById,
        transcript: 'Importó poco lo que dijeron los demás.',
      );

      expect(used, isEmpty);
    });

    test('a target id missing from the catalog counts as unused, never '
        'throws', () {
      final used = SpokenWordUse.detect(
        targetWordIds: ['unknown-id'],
        wordsById: wordsById,
        transcript: 'Cualquier cosa.',
      );

      expect(used, isEmpty);
    });

    test('empty target ids short-circuits to an empty list', () {
      final used = SpokenWordUse.detect(
        targetWordIds: const [],
        wordsById: wordsById,
        transcript: 'Importante, importante, importante.',
      );

      expect(used, isEmpty);
    });
  });

  group('SpokenWordUse.review', () {
    test('a due word advances the ladder and marks productionDone', () {
      final before = buildProgress(nextDueOn: day(15));

      final after = SpokenWordUse.review(
        before,
        today: day(15),
        now: DateTime(2026, 9, 15, 9),
      );

      expect(after, isNotNull);
      expect(after!.ladderStep, 1);
      expect(after.nextDueOn, day(18)); // ladder day 3 from the review.
      expect(after.productionDone, isTrue);
      expect(after.lastGrade, isNotNull);
    });

    test('a word not due today is left unchanged (returns null)', () {
      final before = buildProgress(nextDueOn: day(20), ladderStep: 2);

      final after = SpokenWordUse.review(
        before,
        today: day(15),
        now: DateTime(2026, 9, 15, 9),
      );

      expect(after, isNull);
    });

    test('a word with no schedule yet (never due) is left unchanged', () {
      final before = buildProgress();

      final after = SpokenWordUse.review(
        before,
        today: day(15),
        now: DateTime(2026, 9, 15, 9),
      );

      expect(after, isNull);
    });
  });
}
