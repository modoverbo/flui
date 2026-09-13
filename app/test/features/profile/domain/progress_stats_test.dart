import 'package:flui/features/exercises/domain/exercise_attempt.dart';
import 'package:flui/features/profile/domain/achievements.dart';
import 'package:flui/features/profile/domain/progress_stats.dart';
import 'package:flui/features/vocabulary/domain/grade.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/learning_builders.dart';

void main() {
  ExerciseAttempt attempt(int attempts, {bool revealed = false}) =>
      ExerciseAttempt(
        exerciseId: 'e',
        wordId: 'w',
        attempts: attempts,
        revealed: revealed,
        grade: Grade.fromOutcome(attempts: attempts, revealed: revealed),
        localDate: day(13),
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
      );

      expect(stats.firstTryPrecisionPercent, 50);
    });

    test('precision rounds to a whole percent', () {
      final stats = ProgressStats.compute(
        progress: const [],
        attempts: [attempt(1), attempt(1), attempt(2)],
        activeDates: const {},
      );

      expect(stats.firstTryPrecisionPercent, 67);
    });

    test('precision is unknown without attempts', () {
      final stats = ProgressStats.compute(
        progress: const [],
        attempts: const [],
        activeDates: const {},
      );

      expect(stats.firstTryPrecisionPercent, isNull);
    });
  });

  group('Achievements', () {
    test('all in progress for a new user', () {
      final achievements = Achievements.compute(
        progress: const [],
        activeDays: 0,
      );

      expect(achievements.map((a) => a.kind), AchievementKind.values);
      expect(achievements.every((a) => !a.isCompleted), isTrue);
      expect(achievements.map((a) => a.target), [1, 1, 5, 10, 1]);
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
        ))
          achievement.kind: achievement,
      };

      expect(achievements[AchievementKind.firstWord]!.isCompleted, isTrue);
      expect(achievements[AchievementKind.firstOwnedWord]!.isCompleted, isTrue);
      expect(achievements[AchievementKind.fiveActiveDays]!.current, 5);
      expect(achievements[AchievementKind.fiveActiveDays]!.isCompleted, isTrue);
      expect(achievements[AchievementKind.tenWords]!.current, 3);
      expect(achievements[AchievementKind.tenWords]!.fraction, 0.3);
      expect(
        achievements[AchievementKind.firstOwnSentence]!.isCompleted,
        isTrue,
      );
    });
  });
}
