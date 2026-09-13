import 'package:flui/features/vocabulary/domain/grade.dart';
import 'package:flui/features/vocabulary/domain/review_scheduler.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/learning_builders.dart';

void main() {
  final now = DateTime(2026, 9, 13, 10);

  group('ReviewScheduler ladder (learning-method §2)', () {
    test('uses the 1-3-7-14-30 ladder', () {
      expect(ReviewScheduler.ladderDays, [1, 3, 7, 14, 30]);
    });

    test('moving to practica starts the ladder tomorrow', () {
      final progress = ReviewScheduler.startLadder(
        buildProgress(state: WordState.nueva, ladderStep: 3),
        today: day(13),
      );

      expect(progress.ladderStep, 0);
      expect(progress.nextDueOn, day(14));
    });

    final cases = <(int step, Grade grade, int newStep, int dueInDays)>[
      (0, Grade.good, 1, 3),
      (1, Grade.good, 2, 7),
      (2, Grade.good, 3, 14),
      (3, Grade.good, 4, 30),
      (4, Grade.good, 4, 30),
      (0, Grade.hard, 0, 1),
      (2, Grade.hard, 2, 7),
      (4, Grade.hard, 4, 30),
      (0, Grade.again, 0, 1),
      (3, Grade.again, 0, 1),
    ];
    for (final (step, grade, newStep, dueInDays) in cases) {
      test('step $step graded $grade -> step $newStep, due in $dueInDays', () {
        final progress = ReviewScheduler.schedule(
          buildProgress(ladderStep: step, nextDueOn: day(10)),
          grade: grade,
          today: day(13),
          now: now,
        );

        expect(progress.ladderStep, newStep);
        expect(progress.nextDueOn, day(13).addDays(dueInDays));
        expect(progress.lastGrade, grade);
        expect(progress.lastReviewedAt, now);
      });
    }

    test('intervals count from the day of the review (worked example)', () {
      // The word moved to practica on day 0.
      var progress = ReviewScheduler.startLadder(
        buildProgress(),
        today: day(1),
      );
      final dueDates = [progress.nextDueOn];
      for (var i = 0; i < 5; i++) {
        final reviewDay = progress.nextDueOn!;
        progress = ReviewScheduler.schedule(
          progress,
          grade: Grade.good,
          today: reviewDay,
          now: now,
        );
        dueDates.add(progress.nextDueOn);
      }

      // Day 0 = Sep 1: due days 1, 4, 11, 25, 55, then every 30 days.
      expect(dueDates, [
        day(2),
        day(5),
        day(12),
        day(26),
        day(26).addDays(30),
        day(26).addDays(60),
      ]);
    });

    test('a good review adds today to the distinct success days', () {
      final once = ReviewScheduler.schedule(
        buildProgress(successDays: {day(10)}),
        grade: Grade.good,
        today: day(13),
        now: now,
      );
      final twice = ReviewScheduler.schedule(
        once,
        grade: Grade.good,
        today: day(13),
        now: now,
      );

      expect(twice.firstTrySuccessDays, {day(10), day(13)});
    });

    test('hard and again reviews add no success day', () {
      for (final grade in [Grade.hard, Grade.again]) {
        final progress = ReviewScheduler.schedule(
          buildProgress(),
          grade: grade,
          today: day(13),
          now: now,
        );
        expect(progress.firstTrySuccessDays, isEmpty);
      }
    });

    test('a nueva word under review keeps step 0 and is due tomorrow', () {
      for (final grade in Grade.values) {
        final progress = ReviewScheduler.schedule(
          buildProgress(state: WordState.nueva),
          grade: grade,
          today: day(13),
          now: now,
        );
        expect(progress.ladderStep, 0);
        expect(progress.nextDueOn, day(14));
      }
    });
  });
}
