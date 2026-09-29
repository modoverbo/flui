import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/core/fake/fake_remote.dart';
import 'package:flui/core/supabase/data_error_mapper.dart';
import 'package:flui/core/supabase/paged_query.dart';
import 'package:flui/features/daily/data/dtos/daily_session_dto.dart';
import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:flui/features/daily/domain/daily_session_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// `daily_sessions` of the signed-in user.
///
/// [includeTrainingPlan] MUST stay `false` unless the caller has confirmed
/// the U7 migration (`focus_area`/`challenge_id`/`woven_word_ids`) is
/// actually live — production migrations are applied manually, so nothing
/// guarantees it. `false` (the default) selects/writes the exact pre-U15a
/// column set, byte-identical to `main`; PostgREST 400s on an unknown
/// column, so a stray extra column here would break HOY for every
/// production user, flag or no flag. Wired from `speakingGymEnabledProvider`
/// in `bootstrap.dart`.
final class SupabaseDailySessionRepository implements DailySessionRepository {
  const new(
    this._client, {
    required this.currentUserId,
    this.includeTrainingPlan = false,
  });

  final SupabaseClient _client;
  final String? Function() currentUserId;
  final bool includeTrainingPlan;

  @override
  Future<Result<List<DailySession>>> fetchSessions() async {
    try {
      final rows = await fetchAllPages(
        (from, to) => _client
            .from('daily_sessions')
            .select(
              DailySessionDto.columns(includeTrainingPlan: includeTrainingPlan),
            )
            .order('local_date', ascending: true)
            .range(from, to),
      );
      return Result.ok([
        for (final row in rows) DailySessionDto.fromJson(row).toDomain(),
      ]);
    } on Object catch (error) {
      return Result.err(mapDataError(error));
    }
  }

  @override
  Future<Result<void>> saveSession(DailySession session) async {
    final userId = currentUserId();
    if (userId == null) return const Result.err(notSignedInFailure);
    try {
      final payload = DailySessionDto.fromDomain(
        session,
        userId: userId,
      ).toJson();
      if (!includeTrainingPlan) {
        DailySessionDto.trainingPlanKeys.forEach(payload.remove);
      }
      await _client
          .from('daily_sessions')
          .upsert(payload, onConflict: 'user_id,local_date');
      return const Result.ok(null);
    } on Object catch (error) {
      return Result.err(mapDataError(error));
    }
  }

  @override
  Future<Result<void>> completeSession({
    required LocalDate localDate,
    required DateTime completedAt,
  }) async {
    final userId = currentUserId();
    if (userId == null) return const Result.err(notSignedInFailure);
    try {
      await _client
          .from('daily_sessions')
          .update({'completed_at': completedAt.toUtc().toIso8601String()})
          .eq('user_id', userId)
          .eq('local_date', localDate.toIso());
      return const Result.ok(null);
    } on Object catch (error) {
      return Result.err(mapDataError(error));
    }
  }
}
