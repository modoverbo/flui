import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/vocabulary/domain/grade.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'word_progress.freezed.dart';

/// Mastery state and review schedule of one word (`word_progress` row).
@freezed
abstract class WordProgress with _$WordProgress {
  const factory({
    required String wordId,
    required WordState state,
    required LocalDate introducedOn,

    /// Distinct dates with a first-try success in a review.
    @Default(<LocalDate>{}) Set<LocalDate> firstTrySuccessDays,
    @Default(false) bool formRecallDone,
    @Default(false) bool productionDone,

    /// Index (0–4) of the ladder interval used for the next review.
    @Default(0) int ladderStep,
    LocalDate? nextDueOn,
    Grade? lastGrade,
    DateTime? lastReviewedAt,
  }) = _WordProgress;

  /// A word introduced [today]. It is due tomorrow, so a session abandoned
  /// halfway still brings the word back as a review.
  factory introduced({required String wordId, required LocalDate today}) =>
      WordProgress(
        wordId: wordId,
        state: WordState.nueva,
        introducedOn: today,
        nextDueOn: today.addDays(1),
      );

  const new _();

  bool isDueOn(LocalDate today) {
    final due = nextDueOn;
    return due != null && !due.isAfter(today);
  }
}
