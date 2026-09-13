import 'package:flui/core/error/result.dart';
import 'package:flui/features/exercises/domain/exercise_attempt.dart';

/// The signed-in user's `exercise_attempts` (append-only).
abstract interface class ExerciseAttemptRepository {
  /// All attempts, oldest first.
  Future<Result<List<ExerciseAttempt>>> fetchAttempts();

  Future<Result<void>> recordAttempt(ExerciseAttempt attempt);
}
