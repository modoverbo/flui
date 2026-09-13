import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/vocabulary/domain/grade.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'exercise_attempt.freezed.dart';

/// One answered cloze (`exercise_attempts` row, append-only).
@freezed
abstract class ExerciseAttempt with _$ExerciseAttempt {
  const factory({
    required String exerciseId,
    required String wordId,

    /// 1 to 3.
    required int attempts,
    required bool revealed,
    required Grade grade,
    required LocalDate localDate,
    int? durationMs,
    DateTime? createdAt,
  }) = _ExerciseAttempt;

  const new _();

  bool get firstTry => attempts == 1 && !revealed;
}
