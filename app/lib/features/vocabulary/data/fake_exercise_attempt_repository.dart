import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/core/fake/fake_remote.dart';
import 'package:flui/features/vocabulary/domain/exercises/exercise_attempt.dart';
import 'package:flui/features/vocabulary/domain/exercises/exercise_attempt_repository.dart';

/// In-memory `exercise_attempts`, append-only, per user.
final class FakeExerciseAttemptRepository
    with FakeRemote
    implements ExerciseAttemptRepository {
  new({
    required this.currentUserId,
    this.latency = Duration.zero,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final String? Function() currentUserId;
  final DateTime Function() _now;

  @override
  final Duration latency;

  final _rows = <String, List<ExerciseAttempt>>{};

  @override
  Future<Result<List<ExerciseAttempt>>> fetchAttempts({
    LocalDate? since,
  }) async {
    if (await simulateCall() case final failure?) return Result.err(failure);
    final userId = currentUserId();
    if (userId == null) return const Result.err(notSignedInFailure);
    return Result.ok([
      for (final attempt in _rows[userId] ?? const <ExerciseAttempt>[])
        if (since == null || !attempt.localDate.isBefore(since)) attempt,
    ]);
  }

  @override
  Future<Result<void>> recordAttempt(ExerciseAttempt attempt) async {
    if (await simulateCall() case final failure?) return Result.err(failure);
    final userId = currentUserId();
    if (userId == null) return const Result.err(notSignedInFailure);
    _rows
        .putIfAbsent(userId, () => [])
        .add(attempt.copyWith(createdAt: attempt.createdAt ?? _now()));
    return const Result.ok(null);
  }
}
