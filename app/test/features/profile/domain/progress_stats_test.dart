import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/exercises/domain/exercise_attempt.dart';
import 'package:flui/features/profile/domain/achievements.dart';
import 'package:flui/features/profile/domain/progress_stats.dart';
import 'package:flui/features/vocabulary/domain/grade.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/learning_builders.dart';

void main() {
  ExerciseAttempt attempt(
    int attempts, {
    bool revealed = false,
    LocalDate? on,
  }) => ExerciseAttempt(
    exerciseId: 'e',
    wordId: 'w',
    attempts: attempts,
    revealed: revealed,
    grade: Grade.fromOutcome(attempts: attempts, revealed: revealed),
    localDate: on ?? day(13),
  );

  group('ProgressStats', () {
    test('counts words by state', () {
      final stats = ProgressStats.compute(
        progress: [
          buildProgress(wordId: 'a', state: WordState.nueva),
          buildProgress(wordId: 'b'),
          buildProgress(wordId: 'c'),
          buildProgress(wordId: 'd', state: WordState.tuya),
        ],
        attempts: const [],
        activeDates: {day(1)},
        today: day(13),
      );

      expect(stats.nueva, 1);
      expect(stats.practica, 2);
      expect(stats.tuya, 1);
      expect(stats.totalWords, 4);
      expect(stats.activeDays, 1);
    });

    test('precision is the share of first-try answers', () {
      final stats = ProgressStats.compute(
        progress: const [],
        attempts: [
          attempt(1),
          attempt(1),
          attempt(2),
          attempt(3, revealed: true),
        ],
        activeDates: const {},
        today: day(13),
      );

      expect(stats.firstTryPrecisionPercent, 50);
    });

    test('precision rounds to a whole percent', () {
      final stats = ProgressStats.compute(
        progress: const [],
        attempts: [attempt(1), attempt(1), attempt(2)],
        activeDates: const {},
        today: day(13),
      );

      expect(stats.firstTryPrecisionPercent, 67);
    });

    test('precision only counts the last 30 days', () {
      final stats = ProgressStats.compute(
        progress: const [],
        attempts: [
          // A rough start two months ago no longer drags the number down.
          attempt(3, revealed: true, on: day(1, month: 7)),
          attempt(3, revealed: true, on: day(2, month: 7)),
          attempt(1),
          attempt(1),
        ],
        activeDates: const {},
        today: day(13),
      );

      expect(stats.firstTryPrecisionPercent, 100);
    });

    test('precision is unknown when the window has no attempts', () {
      final stats = ProgressStats.compute(
        progress: const [],
        attempts: [attempt(1, on: day(1, month: 7))],
        activeDates: const {},
        today: day(13),
      );

      expect(stats.firstTryPrecisionPercent, isNull);
    });

    test('words in practice are everything not owned yet', () {
      final stats = ProgressStats.compute(
        progress: [
          buildProgress(wordId: 'a', state: WordState.nueva),
          buildProgress(wordId: 'b'),
          buildProgress(wordId: 'c', state: WordState.tuya),
        ],
        attempts: const [],
        activeDates: const {},
        today: day(13),
      );

      expect(stats.inPractice, 2);
    });

    test('precision is unknown without attempts', () {
      final stats = ProgressStats.compute(
        progress: const [],
        attempts: const [],
        activeDates: const {},
        today: day(13),
      );

      expect(stats.firstTryPrecisionPercent, isNull);
    });
  });

  group('Achievements', () {
    test('all in progress for a new user', () {
      final achievements = Achievements.compute(
        progress: const [],
        activeDays: 0,
        catalogSize: 20,
      );

      expect(achievements.map((a) => a.kind), AchievementKind.values);
      expect(achievements.every((a) => !a.isCompleted), isTrue);
      expect(achievements.map((a) => a.target), [1, 1, 5, 10, 1]);
    });

    test('the repertoire target never exceeds the catalog', () {
      final achievements = Achievements.compute(
        progress: [for (var i = 0; i < 8; i++) buildProgress(wordId: 'w$i')],
        activeDays: 0,
        catalogSize: 8,
      );
      final repertoire = achievements.firstWhere(
        (a) => a.kind == AchievementKind.repertoire,
      );

      expect(repertoire.target, 8);
      expect(repertoire.isCompleted, isTrue);
    });

    test('an empty catalog leaves a reachable target', () {
      final achievements = Achievements.compute(
        progress: const [],
        activeDays: 0,
        catalogSize: 0,
      );
      final repertoire = achievements.firstWhere(
        (a) => a.kind == AchievementKind.repertoire,
      );

      expect(repertoire.target, 1);
    });

    test('computed from progress and active days', () {
      final achievements = {
        for (final achievement in Achievements.compute(
          progress: [
            buildProgress(wordId: 'a', productionDone: true),
            buildProgress(wordId: 'b', state: WordState.tuya),
            buildProgress(wordId: 'c', state: WordState.nueva),
          ],
          activeDays: 7,
          catalogSize: 20,
        ))
          achievement.kind: achievement,
      };

      expect(achievements[AchievementKind.firstWord]!.isCompleted, isTrue);
      expect(achievements[AchievementKind.firstOwnedWord]!.isCompleted, isTrue);
      expect(achievements[AchievementKind.fiveActiveDays]!.current, 5);
      expect(achievements[AchievementKind.fiveActiveDays]!.isCompleted, isTrue);
      expect(achievements[AchievementKind.repertoire]!.current, 3);
      expect(achievements[AchievementKind.repertoire]!.fraction, 0.3);
      expect(
        achievements[AchievementKind.firstOwnSentence]!.isCompleted,
        isTrue,
      );
    });
  });
}
