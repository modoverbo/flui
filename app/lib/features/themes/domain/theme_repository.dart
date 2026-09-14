import 'package:flui/core/error/result.dart';
import 'package:flui/features/themes/domain/theme.dart';

/// The published theme taxonomy (`themes`).
///
/// Readable by any signed-in user, including one who has not started a trial:
/// the taxonomy is the shape of the offer, not the paid content itself.
abstract interface class ThemeRepository {
  /// Published themes by `sort_order`.
  Future<Result<List<Theme>>> fetchThemes();
}
