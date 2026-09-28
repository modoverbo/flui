import 'package:flui/features/diagnosis/domain/skill_profile_repository.dart';
import 'package:flui/features/training/domain/challenge.dart';
import 'package:flui/features/training/domain/speaking_attempt.dart';
import 'package:meta/meta.dart';

/// What a diagnosis screen should do next, derived purely from already
/// persisted `speaking_attempts` rows (design D38) — no new schema, no
/// client-owned progress flag.
@immutable
sealed class DiagnosisResumeDecision {
  const new();
}

/// No open session: start a brand-new diagnosis at slot 1. Covers a
/// first-ever diagnosis (no attempts at all) and a fresh retake (the
/// newest diagnosis session's rows are already closed by a matching
/// `skill_profiles` row).
final class DiagnosisFresh extends DiagnosisResumeDecision {
  const new();
}

/// An open session exists: [sessionId] identifies it, [answered] maps each
/// already-answered slot (1-3) to its attempt, and [nextSlot] is the lowest
/// unanswered slot — or `null` when all 3 slots are already answered and
/// the session is ready to be profiled directly, without recording
/// anything else (design D38: an earlier profile save must have failed).
final class DiagnosisResume extends DiagnosisResumeDecision {
  const new({
    required this.sessionId,
    required this.answered,
    required this.nextSlot,
  });

  final String sessionId;
  final Map<int, SpeakingAttempt> answered;
  final int? nextSlot;
}

/// Pure decision over the diagnosis screens' resume state (design D38,
/// D39, U14c). Never touches the network itself — callers fetch the
/// attempts (`SpeakingAttemptRepository.latestDiagnosisAttempts()`,
/// already scoped to the newest diagnosis session, see D38) and the
/// profile (`SkillProfileRepository.latest()`) beforehand.
final class DiagnosisResumePolicy {
  const new();

  static const totalSlots = 3;

  DiagnosisResumeDecision decide({
    required List<SpeakingAttempt> latestDiagnosisAttempts,
    required SkillProfileRecord? latestProfile,
    required Map<String, Challenge> challengesById,
  }) {
    if (latestDiagnosisAttempts.isEmpty) return const DiagnosisFresh();

    final sessionId = latestDiagnosisAttempts.first.sessionId;
    // A skill_profiles row with id == sessionId closes that diagnosis
    // session (D38) — nothing to resume, the next visit starts fresh.
    if (latestProfile != null && latestProfile.id == sessionId) {
      return const DiagnosisFresh();
    }

    final answered = <int, SpeakingAttempt>{};
    for (final attempt in latestDiagnosisAttempts) {
      // An unknown/unpublished challenge id never fabricates a slot — that
      // slot is simply re-asked.
      final slot = challengesById[attempt.challengeId]?.diagnosisSlot;
      if (slot == null) continue;
      answered[slot] = attempt;
    }

    int? nextSlot;
    for (var slot = 1; slot <= totalSlots; slot++) {
      if (!answered.containsKey(slot)) {
        nextSlot = slot;
        break;
      }
    }

    return DiagnosisResume(
      sessionId: sessionId,
      answered: answered,
      nextSlot: nextSlot,
    );
  }
}
