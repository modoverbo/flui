import 'package:flui/core/error/result.dart';
import 'package:flui/features/training/domain/speaking_attempt.dart';

/// The signed-in user's `speaking_attempts` (append-only).
abstract interface class SpeakingAttemptRepository {
  /// Persists [attempt].
  ///
  /// When [attempt] claims a milestone week (`milestoneWeek` set, `audio` is
  /// [AudioRetentionPending]) but another attempt already claimed that same
  /// week for this user, the unique constraint on `(user_id,
  /// milestone_week)` rejects the insert — this retries exactly once with
  /// the attempt downgraded to `audio: const AudioRetention.none()` and
  /// `milestoneWeek: null`, never losing the already-analyzed transcript,
  /// metrics or observations (design part-3 §5, "Milestones" write order).
  Future<Result<SpeakingAttempt>> insert(SpeakingAttempt attempt);
}
