import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/core/fake/fake_remote.dart';
import 'package:flui/core/supabase/data_error_mapper.dart';
import 'package:flui/core/supabase/paged_query.dart';
import 'package:flui/features/exercises/data/dtos/exercise_attempt_dto.dart';
import 'package:flui/features/exercises/domain/exercise_attempt.dart';
import 'package:flui/features/exercises/domain/exercise_attempt_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// `exercise_attempts` of the signed-in user (insert and select only).
final class SupabaseExerciseAttemptRepository
    implements ExerciseAttemptRepository {
  const new(this._client, {required this.currentUserId});

  final SupabaseClient _client;
  final String? Function() currentUserId;

  @override
  Future<Result<List<ExerciseAttempt>>> fetchAttempts({
    LocalDate? since,
  }) async {
    try {
      final rows = await fetchAllPages(
        (from, to) =>
            (since == null
                    ? _client
                          .from('exercise_attempts')
                          .select(ExerciseAttemptDto.columns)
                    : _client
                          .from('exercise_attempts')
                          .select(ExerciseAttemptDto.columns)
                          .gte('local_date', since.toIso()))
                .order('created_at', ascending: true)
                .range(from, to),
      );
      return Result.ok([
        for (final row in rows) ExerciseAttemptDto.fromJson(row).toDomain(),
      ]);
    } on Object catch (error) {
      return Result.err(mapDataError(error));
    }
  }

  @override
  Future<Result<void>> recordAttempt(ExerciseAttempt attempt) async {
    final userId = currentUserId();
    if (userId == null) return const Result.err(notSignedInFailure);
    try {
      await _client
          .from('exercise_attempts')
          .insert(
            ExerciseAttemptDto.fromDomain(attempt, userId: userId).toJson(),
          );
      return const Result.ok(null);
    } on Object catch (error) {
      return Result.err(mapDataError(error));
    }
  }
}
