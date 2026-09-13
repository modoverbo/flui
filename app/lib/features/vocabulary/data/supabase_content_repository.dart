import 'package:flui/core/error/result.dart';
import 'package:flui/core/supabase/data_error_mapper.dart';
import 'package:flui/core/supabase/paged_query.dart';
import 'package:flui/features/vocabulary/data/dtos/word_dto.dart';
import 'package:flui/features/vocabulary/domain/content_repository.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Words with confusions, exercises (and options) and readings in one
/// request. RLS only returns published words to users with access.
final class SupabaseContentRepository implements ContentRepository {
  const new(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<List<Word>>> fetchCatalog() async {
    try {
      // PostgREST caps a response at `max_rows`: a catalog past that limit
      // would silently lose its tail, and the tail is what a long-time user
      // still has left to learn.
      final rows = await fetchAllPages(
        (from, to) => _client
            .from('words')
            .select(WordDto.columns)
            .eq('published', true)
            .order('sort_order', ascending: true)
            .range(from, to),
      );
      return Result.ok([
        for (final row in rows) WordDto.fromJson(row).toDomain(),
      ]);
    } on Object catch (error) {
      return Result.err(mapDataError(error));
    }
  }
}
