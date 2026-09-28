import 'package:flui/core/date/local_date.dart';
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

  /// Every distinct non-null `challengeId` the signed-in user attempted
  /// with `localDate >= since`, across every context — the smallest query
  /// `QuickPracticePicker` (U23e, design §19.13) needs for its 7-day
  /// "used recently" exclusion (`TrainingPlanner._pickChallenge` does the
  /// same 7-day exclusion, but composes it from a caller-supplied attempt
  /// list already fetched for the daily plan; quick practice has no such
  /// list to reuse, hence this dedicated query).
  Future<Result<Set<String>>> usedChallengeIdsSince(LocalDate since);

  /// The newest diagnosis session's attempts (at most 3 rows,
  /// `context='diagnosis'`, all sharing the same `sessionId`) — used to
  /// compute the profile once the loop reaches its summary step (U14a)
  /// and, to resume a paused diagnosis (U14c, design D38).
  ///
  /// Explicitly scoped to the newest session's id, never just "the most
  /// recent up-to-3 diagnosis rows": pause/resume means a session can have
  /// fewer than 3 rows while open, and an older abandoned session or a
  /// 30-day retake can leave stale diagnosis rows behind — a plain
  /// top-3-by-recency query would silently mix those into the current run.
  Future<Result<List<SpeakingAttempt>>> latestDiagnosisAttempts();
}
