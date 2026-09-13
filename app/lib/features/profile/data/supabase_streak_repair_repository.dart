import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/core/fake/fake_remote.dart';
import 'package:flui/core/supabase/data_error_mapper.dart';
import 'package:flui/features/profile/domain/streak_repair_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// `streak_repairs` of the signed-in user (insert and select only).
final class SupabaseStreakRepairRepository implements StreakRepairRepository {
  const new(this._client, {required this.currentUserId});

  final SupabaseClient _client;
  final String? Function() currentUserId;

  @override
  Future<Result<List<LocalDate>>> fetchRepairs() async {
    try {
      final rows = await _client
          .from('streak_repairs')
          .select('repaired_date')
          .order('repaired_date', ascending: true);
      return Result.ok([
        for (final row in rows) LocalDate.parse(row['repaired_date'] as String),
      ]);
    } on Object catch (error) {
      return Result.err(mapDataError(error));
    }
  }

  @override
  Future<Result<void>> repairDay(LocalDate date) async {
    final userId = currentUserId();
    if (userId == null) return const Result.err(notSignedInFailure);
    try {
      await _client.from('streak_repairs').insert({
        'user_id': userId,
        'repaired_date': date.toIso(),
      });
      return const Result.ok(null);
    } on Object catch (error) {
      return Result.err(mapDataError(error));
    }
  }
}
