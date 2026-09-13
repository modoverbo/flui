import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/features/exercises/domain/exercise_attempt.dart';

/// The signed-in user's `exercise_attempts` (append-only).
abstract interface class ExerciseAttemptRepository {
  /// Attempts on or after [since], oldest first. The table grows by one row
  /// per answer for ever, so the app never asks for the whole history: it
  /// only needs enough for today's resume, the rolling precision window and
  /// the longest review interval.
  Future<Result<List<ExerciseAttempt>>> fetchAttempts({LocalDate? since});

  Future<Result<void>> recordAttempt(ExerciseAttempt attempt);
}
