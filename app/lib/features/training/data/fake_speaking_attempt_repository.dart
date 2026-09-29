import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/core/fake/fake_remote.dart';
import 'package:flui/features/training/domain/speaking_attempt.dart';
import 'package:flui/features/training/domain/speaking_attempt_repository.dart';
import 'package:flui/features/training/domain/training_context.dart';

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

  /// When true, [insert] always fails with a [NetworkFailure] until reset
  /// back to false — unlike a single-shot `nextFailure` field, this stays
  /// on across the controller's automatic retry too, so a real-path test
  /// can deterministically reach and then recover from the "not saved"
  /// state (`TrainingLoopController.retrySave`).
  bool failInserts = false;

  /// Every attempt recorded so far for the signed-in user, insertion order.
  List<SpeakingAttempt> get attemptsForCurrentUser =>
      List.unmodifiable(_attemptsByUser[currentUserId()] ?? const []);

  /// Replaces attempt [attemptId]'s `audio` field in place, wherever it
  /// lives — a no-op if no attempt with that id is known. A real
  /// `speaking_attempts` row is the single source of truth for both its
  /// content AND its `audio_status`, so `FakeAttemptAudioStore` calls this
  /// (via its `onAudioChanged` callback, wired in `bootstrap.dart`) to
  /// mirror that: two independently-constructed fakes would otherwise
  /// silently disagree about whether an attempt's audio is still stored
  /// after `AttemptAudioStore.upload`/`delete` (U18b).
  void updateAudio(String attemptId, AudioRetention audio) {
    for (final attempts in _attemptsByUser.values) {
      final index = attempts.indexWhere((a) => a.id == attemptId);
      if (index == -1) continue;
      attempts[index] = attempts[index].copyWith(audio: audio);
      return;
    }
  }

  @override
  Future<Result<SpeakingAttempt>> insert(SpeakingAttempt attempt) async {
    if (await simulateCall() case final failure?) return Result.err(failure);
    if (failInserts) return const Result.err(NetworkFailure());
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

  @override
  Future<Result<Set<String>>> usedChallengeIdsSince(LocalDate since) async {
    if (await simulateCall() case final failure?) return Result.err(failure);
    final userId = currentUserId();
    if (userId == null) return const Result.err(notSignedInFailure);

    final attempts = _attemptsByUser[userId] ?? const [];
    return Result.ok({
      for (final attempt in attempts)
        if (attempt.challengeId != null && !attempt.localDate.isBefore(since))
          attempt.challengeId!,
    });
  }

  @override
  Future<Result<List<SpeakingAttempt>>> latestDiagnosisAttempts() async {
    if (await simulateCall() case final failure?) return Result.err(failure);
    final userId = currentUserId();
    if (userId == null) return const Result.err(notSignedInFailure);

    final diagnosisAttempts = <SpeakingAttempt>[
      for (final attempt
          in _attemptsByUser[userId] ?? const <SpeakingAttempt>[])
        if (attempt.context == TrainingContext.diagnosis) attempt,
    ];
    if (diagnosisAttempts.isEmpty) return const Result.ok(<SpeakingAttempt>[]);
    // Diagnosis is a single mandatory in-flight session at a time (the gate
    // blocks everything else), so the most recently inserted diagnosis
    // attempt's session id is always the newest session.
    final newestSessionId = diagnosisAttempts.last.sessionId;
    return Result.ok(<SpeakingAttempt>[
      for (final attempt in diagnosisAttempts)
        if (attempt.sessionId == newestSessionId) attempt,
    ]);
  }

  @override
  Future<Result<List<SpeakingAttempt>>> recentAttemptsSince(
    LocalDate since,
  ) async {
    if (await simulateCall() case final failure?) return Result.err(failure);
    final userId = currentUserId();
    if (userId == null) return const Result.err(notSignedInFailure);

    final attempts = <SpeakingAttempt>[
      for (final attempt
          in _attemptsByUser[userId] ?? const <SpeakingAttempt>[])
        if (!attempt.localDate.isBefore(since)) attempt,
    ]..sort((a, b) => b.localDate.compareTo(a.localDate));
    return Result.ok(attempts);
  }

  @override
  Future<Result<List<SpeakingAttempt>>> attemptsForSession(
    String sessionId,
  ) async {
    if (await simulateCall() case final failure?) return Result.err(failure);
    final userId = currentUserId();
    if (userId == null) return const Result.err(notSignedInFailure);

    return Result.ok(<SpeakingAttempt>[
      for (final attempt
          in _attemptsByUser[userId] ?? const <SpeakingAttempt>[])
        if (attempt.sessionId == sessionId) attempt,
    ]);
  }

  @override
  Future<Result<SpeakingAttempt?>> latestStoredMilestone() async {
    if (await simulateCall() case final failure?) return Result.err(failure);
    final userId = currentUserId();
    if (userId == null) return const Result.err(notSignedInFailure);

    SpeakingAttempt? latest;
    for (final attempt
        in _attemptsByUser[userId] ?? const <SpeakingAttempt>[]) {
      final week = attempt.milestoneWeek;
      if (week == null || attempt.audio is! AudioRetentionStored) continue;
      final latestWeek = latest?.milestoneWeek;
      if (latestWeek == null || week.isAfter(latestWeek)) latest = attempt;
    }
    return Result.ok(latest);
  }

  @override
  Future<Result<Set<String>>> storedAudioAttemptIds() async {
    if (await simulateCall() case final failure?) return Result.err(failure);
    final userId = currentUserId();
    if (userId == null) return const Result.err(notSignedInFailure);

    return Result.ok({
      for (final attempt
          in _attemptsByUser[userId] ?? const <SpeakingAttempt>[])
        if (attempt.audio is AudioRetentionStored) attempt.id,
    });
  }
}
