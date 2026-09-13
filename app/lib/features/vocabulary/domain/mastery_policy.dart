import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/vocabulary/domain/grade.dart';
import 'package:flui/features/vocabulary/domain/review_scheduler.dart';
import 'package:flui/features/vocabulary/domain/word_progress.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';

/// Mastery state machine (docs/learning-method.md §5).
abstract final class MasteryPolicy {
  static const minSuccessDays = 3;
  static const minSuccessSpanDays = 7;

  /// All `practica` → `tuya` criteria.
  static bool meetsTuyaCriteria(WordProgress progress) {
    final days = progress.firstTrySuccessDays.toList()..sort();
    if (days.length < minSuccessDays) return false;
    if (days.first.daysUntil(days.last) < minSuccessSpanDays) return false;
    return progress.formRecallDone &&
        progress.productionDone &&
        progress.lastGrade == Grade.good;
  }

  /// Promotes a `practica` word to `tuya` when the criteria hold.
  static WordProgress evaluateTuya(WordProgress progress) =>
      progress.state == WordState.practica && meetsTuyaCriteria(progress)
      ? progress.copyWith(state: WordState.tuya)
      : progress;

  /// End-of-session check of a word introduced today: `nueva` → `practica`
  /// needs the whole discovery flow and a first-try answer in a sentence not
  /// seen earlier that session. Otherwise the word stays `nueva`, due
  /// tomorrow. Words that already left `nueva` are unchanged.
  static WordProgress afterSessionCheck(
    WordProgress progress, {
    required bool discoveryCompleted,
    required Grade grade,
    required LocalDate today,
  }) {
    if (progress.state != WordState.nueva) return progress;
    if (discoveryCompleted && grade == Grade.good) {
      return ReviewScheduler.startLadder(
        progress.copyWith(state: WordState.practica),
        today: today,
      );
    }
    return progress.copyWith(ladderStep: 0, nextDueOn: today.addDays(1));
  }

  /// The first exercise of a word in a review: schedule, then state.
  static WordProgress review(
    WordProgress progress, {
    required Grade grade,
    required LocalDate today,
    required DateTime now,
  }) {
    final scheduled = ReviewScheduler.schedule(
      progress,
      grade: grade,
      today: today,
      now: now,
    );
    final state = switch (progress.state) {
      WordState.nueva =>
        grade == Grade.good ? WordState.practica : WordState.nueva,
      WordState.practica => WordState.practica,
      WordState.tuya =>
        grade == Grade.again ? WordState.practica : WordState.tuya,
    };
    return evaluateTuya(scheduled.copyWith(state: state));
  }
}
