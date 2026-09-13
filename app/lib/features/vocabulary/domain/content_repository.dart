import 'package:flui/core/error/result.dart';
import 'package:flui/features/vocabulary/domain/word.dart';

/// Published learning content (readable only with access).
abstract interface class ContentRepository {
  /// Published words with confusions, exercises and readings, by
  /// `sort_order`.
  Future<Result<List<Word>>> fetchCatalog();
}
