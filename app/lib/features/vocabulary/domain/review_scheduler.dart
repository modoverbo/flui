import 'dart:math';

import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/vocabulary/domain/grade.dart';
import 'package:flui/features/vocabulary/domain/word_progress.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';

/// Fixed review ladder (docs/learning-method.md §2).
///
/// `ladder_step` is the index of the interval used for the next review.
/// Intervals count from the day the review happens, so overdue words are not
/// penalized twice.
abstract final class ReviewScheduler {
  static const ladderDays = [1, 3, 7, 14, 30];

  static int get maxStep => ladderDays.length - 1;

  /// A word that moves to `practica`: step 0, due tomorrow.
  static WordProgress startLadder(
    WordProgress progress, {
    required LocalDate today,
  }) => progress.copyWith(
    ladderStep: 0,
    nextDueOn: today.addDays(ladderDays.first),
  );

  /// Applies a review [grade]: ladder, due date, last grade and success days.
  ///
  /// A `nueva` word (its end-of-session check failed) stays on step 0 and is
  /// due tomorrow whatever the grade; the mastery policy decides its state.
  static WordProgress schedule(
    WordProgress progress, {
    required Grade grade,
    required LocalDate today,
    required DateTime now,
  }) {
    final reviewed = progress.copyWith(
      lastGrade: grade,
      lastReviewedAt: now,
      firstTrySuccessDays: grade == Grade.good
          ? {...progress.firstTrySuccessDays, today}
          : progress.firstTrySuccessDays,
    );
    if (progress.state == WordState.nueva) {
      return startLadder(reviewed, today: today);
    }
    final current = progress.ladderStep.clamp(0, maxStep);
    final step = switch (grade) {
      Grade.good => min(current + 1, maxStep),
      Grade.hard => current,
      Grade.again => 0,
    };
    return reviewed.copyWith(
      ladderStep: step,
      nextDueOn: today.addDays(ladderDays[step]),
    );
  }
}
