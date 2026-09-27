import 'package:flui/core/error/result.dart';
import 'package:flui/core/supabase/data_error_mapper.dart';
import 'package:flui/core/supabase/paged_query.dart';
import 'package:flui/features/training/data/dtos/challenge_dto.dart';
import 'package:flui/features/training/domain/challenge.dart';
import 'package:flui/features/training/domain/challenge_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// `public.challenges`, published only (RLS enforces this too — D10, no
/// `has_access` gate: the content itself is not the paid cost).
final class SupabaseChallengeRepository implements ChallengeRepository {
  const new(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<List<Challenge>>> fetchCatalog() async {
    try {
      final rows = await fetchAllPages(
        (from, to) => _client
            .from('challenges')
            .select(ChallengeDto.columns)
            .eq('published', true)
            .order('sort_order', ascending: true)
            .range(from, to),
      );
      return Result.ok([
        for (final row in rows) ChallengeDto.fromJson(row).toDomain(),
      ]);
    } on Object catch (error) {
      return Result.err(mapDataError(error));
    }
  }
}
