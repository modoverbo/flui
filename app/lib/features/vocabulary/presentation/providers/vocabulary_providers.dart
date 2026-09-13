import 'package:flui/core/error/result.dart';
import 'package:flui/features/vocabulary/domain/content_repository.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/features/vocabulary/domain/word_progress_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'vocabulary_providers.g.dart';

/// Overridden in `bootstrap.dart` (Supabase or fake) and in tests.
@Riverpod(keepAlive: true)
ContentRepository contentRepository(Ref ref) {
  throw UnimplementedError('contentRepositoryProvider must be overridden.');
}

/// Overridden in `bootstrap.dart` (Supabase or fake) and in tests.
@Riverpod(keepAlive: true)
WordProgressRepository wordProgressRepository(Ref ref) {
  throw UnimplementedError(
    'wordProgressRepositoryProvider must be overridden.',
  );
}

/// Published words with their exercises and readings.
@Riverpod(keepAlive: true)
Future<List<Word>> catalog(Ref ref) async {
  final result = await ref.watch(contentRepositoryProvider).fetchCatalog();
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
}

/// Catalog words by id.
@Riverpod(keepAlive: true)
Future<Map<String, Word>> wordsById(Ref ref) async {
  final words = await ref.watch(catalogProvider.future);
  return {for (final word in words) word.id: word};
}
