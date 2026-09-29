import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/features/diagnosis/domain/skill_profile_repository.dart';
import 'package:flui/features/diagnosis/presentation/providers/diagnosis_providers.dart';
import 'package:flui/features/profile/domain/before_now_audio.dart';
import 'package:flui/features/profile/domain/progress_evidence.dart';
import 'package:flui/features/training/domain/speaking_attempt.dart';
import 'package:flui/features/training/presentation/providers/training_providers.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'progress_evidence_overview.g.dart';

/// PROGRESO's speaking-evidence view model (U18b): the per-skill before→now
/// trends plus the audio pair, if any, to play back alongside them.
@immutable
final class ProgressEvidenceOverview {
  const new({required this.evidence, required this.audio});

  final ProgressEvidence evidence;
  final BeforeNowAudio audio;

  static const empty = ProgressEvidenceOverview(
    evidence: ProgressEvidence(beforeNow: BeforeNowInsufficientEvidence()),
    audio: BeforeNowAudioUnavailable(),
  );
}

/// Computes [ProgressEvidenceOverview] from already-persisted attempts and
/// profiles (spec `progress`, decision #429, design part-3 §5).
///
/// The "before" window is always the ORIGINAL diagnosis baseline, never
/// just "the newest diagnosis session" — once a retake exists,
/// `latestDiagnosisAttempts()` points at the retake instead, so the
/// baseline session's own rows are fetched by id via `attemptsForSession`.
/// The "now" window is the completed retake's attempts when one exists
/// (formal comparison, decision #429), or the last 14 days of any-context
/// attempts otherwise (indicative comparison).
@riverpod
Future<ProgressEvidenceOverview> progressEvidenceOverview(Ref ref) async {
  final profileRepository = ref.watch(skillProfileRepositoryProvider);
  final attemptRepository = ref.watch(speakingAttemptRepositoryProvider);

  final history =
      (await profileRepository.history()).valueOrNull ??
      const <SkillProfileRecord>[];
  if (history.isEmpty) return ProgressEvidenceOverview.empty;

  // `history()` is most-recent-first; the baseline is the oldest `baseline`
  // record (there is exactly one per user, the very first diagnosis).
  var baselineProfile = history.last;
  for (final record in history) {
    if (record.kind == SkillProfileKind.baseline) {
      baselineProfile = record;
      break;
    }
  }
  final isRetake = history.first.kind == SkillProfileKind.retake;

  final baselineAttempts = isRetake
      ? (await attemptRepository.attemptsForSession(baselineProfile.id))
                .valueOrNull ??
            const <SpeakingAttempt>[]
      : (await attemptRepository.latestDiagnosisAttempts()).valueOrNull ??
            const <SpeakingAttempt>[];

  final List<SpeakingAttempt> nowAttempts;
  if (isRetake) {
    // A completed retake IS the newest closed diagnosis session, so this is
    // exactly the same query the resume flow (U14c) already relies on.
    nowAttempts =
        (await attemptRepository.latestDiagnosisAttempts()).valueOrNull ??
        const <SpeakingAttempt>[];
  } else {
    final since = ref.watch(clockProvider).localToday().addDays(-14);
    nowAttempts =
        (await attemptRepository.recentAttemptsSince(since)).valueOrNull ??
        const <SpeakingAttempt>[];
  }

  final evidence = ProgressEvidence.compute(
    baselineAttempts: baselineAttempts,
    nowAttempts: nowAttempts,
    isRetake: isRetake,
  );

  // The then-vs-now audio pair is independent of the trend window above: it
  // is always the baseline's own audio vs. the single latest weekly
  // milestone, regardless of whether a retake has since been analyzed
  // (design part-3 §5's "Milestones", deferred from U18a).
  final milestone =
      (await attemptRepository.latestStoredMilestone()).valueOrNull;
  final audio = const BeforeNowAudioSelector().select(
    baselineAttempts: baselineAttempts,
    latestMilestone: milestone,
  );

  return ProgressEvidenceOverview(evidence: evidence, audio: audio);
}

/// The signed-in user's current audio-retention consent — `null` means the
/// question has never been asked (design part-3 §5).
@riverpod
Future<bool?> audioConsent(Ref ref) async {
  final result = await ref.watch(audioConsentRepositoryProvider).read();
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
}

/// Toggles stored audio-retention consent (U18b audio settings). Writing
/// `false` only stops FUTURE uploads — it never deletes audio already
/// stored (spec `speaking-attempt-history`: revocation and deletion are
/// separate actions; deletion is [AudioDeletionController]'s job).
@riverpod
class AudioConsentController extends _$AudioConsentController {
  @override
  bool build() => false; // true while a write is in flight.

  Future<Result<void>> setConsent({required bool granted}) async {
    state = true;
    final result = await ref
        .read(audioConsentRepositoryProvider)
        .write(granted: granted);
    if (ref.mounted) state = false;
    if (result case Ok()) ref.invalidate(audioConsentProvider);
    return result;
  }
}

/// Deletes stored attempt audio — one attempt or every stored attempt for
/// the signed-in user (U18b audio settings, spec `speaking-attempt-history`
/// "User-initiated deletion"). Both operations are idempotent and refresh
/// [progressEvidenceOverviewProvider] on any change so the playback entry
/// degrades gracefully the moment its audio is gone.
@riverpod
class AudioDeletionController extends _$AudioDeletionController {
  @override
  bool build() => false; // true while a delete is in flight.

  /// The exact [UnexpectedFailure.cause] `AttemptAudioStore.delete` returns
  /// when the attempt has no stored audio to remove — treated as the
  /// graceful "nothing to delete" outcome the spec requires, never
  /// surfaced as an error.
  static const _nothingToDelete = 'attempt_not_stored';

  Future<Result<void>> deleteOne(String attemptId) async {
    state = true;
    final result = await ref
        .read(attemptAudioStoreProvider)
        .delete(attemptId: attemptId);
    if (ref.mounted) state = false;
    if (_isNothingToDelete(result)) {
      ref.invalidate(progressEvidenceOverviewProvider);
      return const Result.ok(null);
    }
    if (result case Ok()) ref.invalidate(progressEvidenceOverviewProvider);
    return result;
  }

  Future<Result<void>> deleteAll() async {
    state = true;
    final idsResult = await ref
        .read(speakingAttemptRepositoryProvider)
        .storedAudioAttemptIds();
    final ids = idsResult.valueOrNull ?? const <String>{};
    var firstFailure = switch (idsResult) {
      Ok() => null,
      Err(:final failure) => failure,
    };
    for (final id in ids) {
      final result = await ref
          .read(attemptAudioStoreProvider)
          .delete(attemptId: id);
      if (_isNothingToDelete(result)) continue;
      if (result case Err(:final failure)) firstFailure ??= failure;
    }
    if (ref.mounted) state = false;
    ref.invalidate(progressEvidenceOverviewProvider);
    return firstFailure == null
        ? const Result.ok(null)
        : Result.err(firstFailure);
  }

  bool _isNothingToDelete(Result<void> result) => switch (result) {
    Ok() => false,
    Err(:final failure) =>
      failure is UnexpectedFailure && failure.cause == _nothingToDelete,
  };
}
