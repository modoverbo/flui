import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/vocabulary/domain/exercises/exercise_attempt.dart';
import 'package:flui/features/vocabulary/domain/grade.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'exercise_attempt_dto.freezed.dart';
part 'exercise_attempt_dto.g.dart';

/// An `exercise_attempts` row.
@freezed
abstract class ExerciseAttemptDto with _$ExerciseAttemptDto {
  @JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
  const factory({
    required String exerciseId,
    required String wordId,
    required int attempts,
    required bool revealed,
    required String grade,
    required String localDate,
    String? userId,
    int? durationMs,
    DateTime? createdAt,
  }) = _ExerciseAttemptDto;

  factory fromJson(Map<String, dynamic> json) =>
      _$ExerciseAttemptDtoFromJson(json);

  /// Insert payload: `id` and `created_at` come from database defaults.
  factory fromDomain(ExerciseAttempt attempt, {required String userId}) =>
      ExerciseAttemptDto(
        userId: userId,
        exerciseId: attempt.exerciseId,
        wordId: attempt.wordId,
        attempts: attempt.attempts,
        revealed: attempt.revealed,
        grade: attempt.grade.name,
        localDate: attempt.localDate.toIso(),
        durationMs: attempt.durationMs,
      );

  const new _();

  static const columns =
      'exercise_id, word_id, attempts, revealed, grade, local_date, '
      'duration_ms, created_at';

  ExerciseAttempt toDomain() => ExerciseAttempt(
    exerciseId: exerciseId,
    wordId: wordId,
    attempts: attempts,
    revealed: revealed,
    grade: Grade.values.byName(grade),
    localDate: LocalDate.parse(localDate),
    durationMs: durationMs,
    createdAt: createdAt,
  );
}
