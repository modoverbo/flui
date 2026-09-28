import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/core/supabase/data_error_mapper.dart';
import 'package:flui/features/training/data/dtos/speaking_attempt_dto.dart';
import 'package:flui/features/training/domain/speaking_attempt.dart';
import 'package:flui/features/training/domain/speaking_attempt_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// `public.speaking_attempts` of the signed-in user (RLS scopes rows to the
/// owner; insert requires `has_access`, enforced server-side).
final class SupabaseSpeakingAttemptRepository
    implements SpeakingAttemptRepository {
  const new(this._client);

  /// Postgres error code for a unique-constraint violation — here, the
  /// `(user_id, milestone_week)` index (design part-3 §5).
  static const _uniqueViolation = '23505';

  final SupabaseClient _client;

  @override
  Future<Result<SpeakingAttempt>> insert(SpeakingAttempt attempt) async {
    try {
      return Result.ok(await _insertRow(attempt));
    } on PostgrestException catch (error) {
      if (error.code != _uniqueViolation) {
        return Result.err(mapDataError(error));
      }
      // Another attempt already claimed this milestone week: retry once,
      // downgraded, keeping the already-analyzed transcript/metrics.
      final downgraded = attempt.copyWith(
        audio: const AudioRetention.none(),
        milestoneWeek: null,
      );
      try {
        return Result.ok(await _insertRow(downgraded));
      } on Object catch (retryError) {
        return Result.err(mapDataError(retryError));
      }
    } on Object catch (error) {
      return Result.err(mapDataError(error));
    }
  }

  Future<SpeakingAttempt> _insertRow(SpeakingAttempt attempt) async {
    final row = await _client
        .from('speaking_attempts')
        .insert(SpeakingAttemptDto.fromDomain(attempt).toJson())
        .select(SpeakingAttemptDto.columns)
        .single();
    return SpeakingAttemptDto.fromJson(row).toDomain();
  }

  @override
  Future<Result<Set<String>>> usedChallengeIdsSince(LocalDate since) async {
    try {
      final rows = await _client
          .from('speaking_attempts')
          .select('challenge_id')
          .gte('local_date', since.toIso());
      return Result.ok({
        for (final row in rows)
          if (row['challenge_id'] case final String id) id,
      });
    } on Object catch (error) {
      return Result.err(mapDataError(error));
    }
  }

  @override
  Future<Result<List<SpeakingAttempt>>> latestDiagnosisAttempts() async {
    try {
      final rows = await _client
          .from('speaking_attempts')
          .select(SpeakingAttemptDto.columns)
          .eq('context', 'diagnosis')
          .order('created_at', ascending: false)
          .limit(3);
      return Result.ok([
        for (final row in rows) SpeakingAttemptDto.fromJson(row).toDomain(),
      ]);
    } on Object catch (error) {
      return Result.err(mapDataError(error));
    }
  }
}
