import 'package:supabase_flutter/supabase_flutter.dart';

/// PostgREST caps responses (`max_rows`, 1000 by default): fetch pages of
/// [pageSize] rows until a short page arrives. [query] must be ordered.
Future<List<Map<String, dynamic>>> fetchAllPages(
  PostgrestTransformBuilder<PostgrestList> Function(int from, int to) query, {
  int pageSize = 1000,
}) async {
  final rows = <Map<String, dynamic>>[];
  for (var from = 0; ; from += pageSize) {
    final page = await query(from, from + pageSize - 1);
    rows.addAll(page);
    if (page.length < pageSize) return rows;
  }
}
