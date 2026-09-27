import 'package:flui/core/error/result.dart';
import 'package:flui/features/training/domain/challenge.dart';

/// Published `challenges` (diagnosis + training-lab prompts, D10: readable
/// without an access gate — content itself is not the paid cost).
abstract interface class ChallengeRepository {
  /// Every published challenge, sorted by `sortOrder`.
  Future<Result<List<Challenge>>> fetchCatalog();
}
