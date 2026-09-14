import 'package:flui/core/error/result.dart';
import 'package:flui/core/supabase/data_error_mapper.dart';
import 'package:flui/core/supabase/paged_query.dart';
import 'package:flui/features/themes/data/dtos/theme_dto.dart';
import 'package:flui/features/themes/domain/theme.dart';
import 'package:flui/features/themes/domain/theme_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The published theme taxonomy. RLS returns published themes to any
/// signed-in user; `status` decides which of them today's picker offers.
final class SupabaseThemeRepository implements ThemeRepository {
  const new(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<List<Theme>>> fetchThemes() async {
    try {
      final rows = await fetchAllPages(
        (from, to) => _client
            .from('themes')
            .select(ThemeDto.columns)
            .eq('published', true)
            .order('sort_order', ascending: true)
            .range(from, to),
      );
      return Result.ok([
        for (final row in rows) ThemeDto.fromJson(row).toDomain(),
      ]);
    } on Object catch (error) {
      return Result.err(mapDataError(error));
    }
  }
}
