import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/core/fake/fake_remote.dart';
import 'package:flui/features/training/domain/speaking_attempt.dart';
import 'package:flui/features/training/domain/speaking_attempt_repository.dart';

/// In-memory `speaking_attempts`, one list per user, append-only.
final class FakeSpeakingAttemptRepository
    with FakeRemote
    implements SpeakingAttemptRepository {
  new({required this.currentUserId, this.latency = Duration.zero});

  final String? Function() currentUserId;

  @override
  final Duration latency;

  final _attemptsByUser = <String, List<SpeakingAttempt>>{};
  final _claimedMilestoneWeeksByUser = <String, Set<LocalDate>>{};

  /// Every attempt recorded so far for the signed-in user, insertion order.
  List<SpeakingAttempt> get attemptsForCurrentUser =>
      List.unmodifiable(_attemptsByUser[currentUserId()] ?? const []);

  @override
  Future<Result<SpeakingAttempt>> insert(SpeakingAttempt attempt) async {
    if (await simulateCall() case final failure?) return Result.err(failure);
    final userId = currentUserId();
    if (userId == null) return const Result.err(notSignedInFailure);

    final claimed = _claimedMilestoneWeeksByUser.putIfAbsent(userId, () => {});
    final week = attempt.milestoneWeek;
    // Mirrors the server's unique (user_id, milestone_week) constraint: a
    // second attempt claiming an already-claimed week is downgraded, never
    // losing its transcript/metrics/observations (design part-3 §5).
    final stored = week != null && claimed.contains(week)
        ? attempt.copyWith(
            audio: const AudioRetention.none(),
            milestoneWeek: null,
          )
        : attempt;
    final storedWeek = stored.milestoneWeek;
    if (storedWeek != null) claimed.add(storedWeek);

    _attemptsByUser.putIfAbsent(userId, () => []).add(stored);
    return Result.ok(stored);
  }
}
