import 'package:flui/core/error/result.dart';
import 'package:flui/features/vocabulary/domain/word_progress.dart';

/// The signed-in user's `word_progress` rows.
abstract interface class WordProgressRepository {
  Future<Result<List<WordProgress>>> fetchProgress();

  /// Inserts or updates the row of `progress.wordId`.
  Future<Result<void>> saveProgress(WordProgress progress);
}
