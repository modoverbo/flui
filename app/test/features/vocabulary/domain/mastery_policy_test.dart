import 'package:flui/features/vocabulary/domain/grade.dart';
import 'package:flui/features/vocabulary/domain/mastery_policy.dart';
import 'package:flui/features/vocabulary/domain/word_progress.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/learning_builders.dart';

void main() {
  final now = DateTime(2026, 9, 13, 10);

  group('practica -> tuya criteria (learning-method §5 test table)', () {
    final cases =
        <(List<int> days, bool recall, bool production, Grade last, bool tuya)>[
          ([1, 4, 11], true, true, Grade.good, true),
          ([1, 4, 7], true, true, Grade.good, false),
          ([1, 11], true, true, Grade.good, false),
          ([1, 4, 11], false, true, Grade.good, false),
          ([1, 4, 11], true, false, Grade.good, false),
          ([1, 4, 11], true, true, Grade.hard, false),
        ];
    for (final (days, recall, production, last, tuya) in cases) {
      test('days $days, recall $recall, production $production, '
          'last $last -> ${tuya ? 'tuya' : 'practica'}', () {
        final progress = buildProgress(
          successDays: {for (final d in days) day(d)},
          formRecallDone: recall,
          productionDone: production,
          lastGrade: last,
        );

        expect(MasteryPolicy.meetsTuyaCriteria(progress), tuya);
        expect(
          MasteryPolicy.evaluateTuya(progress).state,
          tuya ? WordState.tuya : WordState.practica,
        );
      });
    }

    test('only practica words are promoted to tuya', () {
      final nueva = buildProgress(
        state: WordState.nueva,
        successDays: {day(1), day(4), day(11)},
        formRecallDone: true,
        productionDone: true,
        lastGrade: Grade.good,
      );

      expect(MasteryPolicy.evaluateTuya(nueva).state, WordState.nueva);
    });
  });

  group('nueva -> practica at the end-of-session check', () {
    WordProgress introduced() =>
        WordProgress.introduced(wordId: 'w1', today: day(13));

    test('discovery completed and first-try correct moves to practica', () {
      final progress = MasteryPolicy.afterSessionCheck(
        introduced(),
        discoveryCompleted: true,
        grade: Grade.good,
        today: day(13),
      );

      expect(progress.state, WordState.practica);
      expect(progress.ladderStep, 0);
      expect(progress.nextDueOn, day(14));
      // The introduction day is not a review day.
      expect(progress.firstTrySuccessDays, isEmpty);
    });

    test('a second-try or forced answer keeps nueva, due tomorrow', () {
      for (final grade in [Grade.hard, Grade.again]) {
        final progress = MasteryPolicy.afterSessionCheck(
          introduced(),
          discoveryCompleted: true,
          grade: grade,
          today: day(13),
        );
        expect(progress.state, WordState.nueva);
        expect(progress.nextDueOn, day(14));
      }
    });

    test('an incomplete discovery flow keeps nueva', () {
      final progress = MasteryPolicy.afterSessionCheck(
        introduced(),
        discoveryCompleted: false,
        grade: Grade.good,
        today: day(13),
      );

      expect(progress.state, WordState.nueva);
    });

    test('never demotes a word that already left nueva', () {
      final practica = buildProgress(ladderStep: 2, nextDueOn: day(20));

      final progress = MasteryPolicy.afterSessionCheck(
        practica,
        discoveryCompleted: true,
        grade: Grade.again,
        today: day(13),
      );

      expect(progress, practica);
    });
  });

  group('reviews', () {
    test('a nueva word with a first-try review success moves to practica', () {
      final progress = MasteryPolicy.review(
        buildProgress(state: WordState.nueva, nextDueOn: day(13)),
        grade: Grade.good,
        today: day(13),
        now: now,
      );

      expect(progress.state, WordState.practica);
      expect(progress.ladderStep, 0);
      expect(progress.nextDueOn, day(14));
      expect(progress.firstTrySuccessDays, {day(13)});
    });

    test('a nueva word that fails its review stays nueva', () {
      final progress = MasteryPolicy.review(
        buildProgress(state: WordState.nueva, nextDueOn: day(13)),
        grade: Grade.hard,
        today: day(13),
        now: now,
      );

      expect(progress.state, WordState.nueva);
      expect(progress.nextDueOn, day(14));
    });

    test('again resets the ladder and keeps practica', () {
      final progress = MasteryPolicy.review(
        buildProgress(ladderStep: 3),
        grade: Grade.again,
        today: day(13),
        now: now,
      );

      expect(progress.state, WordState.practica);
      expect(progress.ladderStep, 0);
    });

    test('tuya -> practica on again, keeping history', () {
      final tuya = buildProgress(
        state: WordState.tuya,
        successDays: {day(1), day(4), day(11)},
        formRecallDone: true,
        productionDone: true,
        ladderStep: 4,
        lastGrade: Grade.good,
      );

      final progress = MasteryPolicy.review(
        tuya,
        grade: Grade.again,
        today: day(13),
        now: now,
      );

      expect(progress.state, WordState.practica);
      expect(progress.firstTrySuccessDays, tuya.firstTrySuccessDays);
      expect(progress.formRecallDone, isTrue);
      expect(progress.productionDone, isTrue);
    });

    test('a good review that completes the criteria makes the word tuya', () {
      final progress = MasteryPolicy.review(
        buildProgress(
          successDays: {day(1), day(4)},
          formRecallDone: true,
          productionDone: true,
          ladderStep: 2,
          lastGrade: Grade.hard,
        ),
        grade: Grade.good,
        today: day(11),
        now: now,
      );

      expect(progress.state, WordState.tuya);
    });

    test('a tuya word returns to tuya after a good review', () {
      final refreshed = buildProgress(
        successDays: {day(1), day(4), day(11)},
        formRecallDone: true,
        productionDone: true,
        lastGrade: Grade.again,
      );

      final progress = MasteryPolicy.review(
        refreshed,
        grade: Grade.good,
        today: day(14),
        now: now,
      );

      expect(progress.state, WordState.tuya);
    });

    test('a hard review never makes a word tuya', () {
      final progress = MasteryPolicy.review(
        buildProgress(
          successDays: {day(1), day(4), day(11)},
          formRecallDone: true,
          productionDone: true,
          lastGrade: Grade.good,
        ),
        grade: Grade.hard,
        today: day(14),
        now: now,
      );

      expect(progress.state, WordState.practica);
    });
  });
}
