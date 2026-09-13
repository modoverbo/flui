import 'package:flui/core/error/result.dart';
import 'package:flui/core/fake/fake_remote.dart';
import 'package:flui/core/supabase/data_error_mapper.dart';
import 'package:flui/core/supabase/paged_query.dart';
import 'package:flui/features/vocabulary/data/dtos/word_progress_dto.dart';
import 'package:flui/features/vocabulary/domain/word_progress.dart';
import 'package:flui/features/vocabulary/domain/word_progress_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// `word_progress` of the signed-in user (RLS scopes rows to the owner).
final class SupabaseWordProgressRepository implements WordProgressRepository {
  const new(this._client, {required this.currentUserId});

  static const pageSize = 1000;

  final SupabaseClient _client;
  final String? Function() currentUserId;

  @override
  Future<Result<List<WordProgress>>> fetchProgress() async {
    try {
      final rows = await fetchAllPages(
        (from, to) => _client
            .from('word_progress')
            .select(WordProgressDto.columns)
            .order('word_id', ascending: true)
            .range(from, to),
      );
      return Result.ok([
        for (final row in rows) WordProgressDto.fromJson(row).toDomain(),
      ]);
    } on Object catch (error) {
      return Result.err(mapDataError(error));
    }
  }

  @override
  Future<Result<void>> saveProgress(WordProgress progress) async {
    final userId = currentUserId();
    if (userId == null) return const Result.err(notSignedInFailure);
    try {
      await _client
          .from('word_progress')
          .upsert(
            WordProgressDto.fromDomain(progress, userId: userId).toJson(),
            onConflict: 'user_id,word_id',
          );
      return const Result.ok(null);
    } on Object catch (error) {
      return Result.err(mapDataError(error));
    }
  }
}
