import 'package:flui/core/error/result.dart';
import 'package:flui/core/id/id_providers.dart';
import 'package:flui/features/daily/presentation/providers/daily_providers.dart';
import 'package:flui/features/diagnosis/domain/diagnosis_resume_policy.dart';
import 'package:flui/features/diagnosis/domain/skill_profile_repository.dart';
import 'package:flui/features/training/domain/challenge.dart';
import 'package:flui/features/training/presentation/providers/training_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'diagnosis_providers.g.dart';

/// Overridden in `bootstrap.dart` (Supabase or fake) and in tests, matching
/// `training_providers.dart`'s established shape for a plain repository
/// port.
final skillProfileRepositoryProvider = Provider<SkillProfileRepository>(
  (ref) => throw UnimplementedError(
    'skillProfileRepositoryProvider must be overridden.',
  ),
);

/// The signed-in user's most recently diagnosed profile, keyed by user id
/// so a new session never sees the previous user's profile — matches
/// `AccessStatusController`'s own shape (`subscription_providers.dart`).
@Riverpod(keepAlive: true)
class LatestSkillProfile extends _$LatestSkillProfile {
  @override
  Future<SkillProfileRecord?> build(String userId) async {
    final result = await ref.read(skillProfileRepositoryProvider).latest();
    return switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
  }

  /// Stores a record obtained elsewhere — the diagnosis flow's own
  /// successful `save()` (U14a) — so `DiagnosisGate` flips to `completed`
  /// immediately, without a second network round-trip.
  void publish(SkillProfileRecord record) => state = AsyncData(record);
}

/// Exactly one challenge per diagnosis slot (design part-3 §5:
/// `diagnosis_slot` 1-3), ordered by slot — the lowest-`sortOrder` one when
/// the content pipeline publishes more than one variant for a slot (U6a:
/// "3 slots x2"), the same tie-break `TrainingLoopController`/
/// `TrainingPlanner`/`training_lab_page.dart`'s own challenge picks use. A
/// real diagnosis session must ask each slot exactly once — never twice,
/// never zero. A slot with no published challenge is simply absent here —
/// `DiagnosisPage` surfaces that as "not enough challenges yet" rather
/// than fabricating one.
@riverpod
Future<List<Challenge>> diagnosisChallenges(Ref ref) async {
  final result = await ref.read(challengeRepositoryProvider).fetchCatalog();
  final catalog = result.valueOrNull ?? const <Challenge>[];
  final bySlot = <int, Challenge>{};
  for (final challenge in catalog) {
    if (challenge.purpose != ChallengePurpose.diagnosis) continue;
    final slot = challenge.diagnosisSlot;
    if (slot == null) continue;
    final current = bySlot[slot];
    if (current == null || challenge.sortOrder < current.sortOrder) {
      bySlot[slot] = challenge;
    }
  }
  final slots = bySlot.keys.toList()..sort();
  return [for (final slot in slots) bySlot[slot]!];
}

/// One diagnosis session id, generated once and kept stable for as long as
/// something watches it (autoDispose) — matches `training_lab_page.dart`'s
/// `labSessionIdProvider` shape (U16). Only used for a FRESH session
/// (`DiagnosisFresh`, [diagnosisResumeProvider]) — a resumed session reuses
/// its own already-persisted `sessionId` instead (design D38, U14c).
// ignore: specify_nonobvious_property_types
final diagnosisSessionIdProvider = Provider.autoDispose<String>(
  (ref) => ref.read(idGeneratorProvider).generate(),
);

/// What the diagnosis intro/live screens (and PROGRESO's paused-retake
/// entry) should do next, computed fresh on every read from already
/// persisted state (design D38, U14c): never a client-owned progress flag.
@riverpod
Future<DiagnosisResumeDecision> diagnosisResume(Ref ref) async {
  final attemptsResult = await ref
      .read(speakingAttemptRepositoryProvider)
      .latestDiagnosisAttempts();
  final attempts = attemptsResult.valueOrNull ?? const [];

  final userId = ref.read(currentUserIdProvider);
  final profile = userId == null
      ? null
      : await ref.read(latestSkillProfileProvider(userId).future);

  final challenges = await ref.read(diagnosisChallengesProvider.future);
  final challengesById = {for (final c in challenges) c.id: c};

  return const DiagnosisResumePolicy().decide(
    latestDiagnosisAttempts: attempts,
    latestProfile: profile,
    challengesById: challengesById,
  );
}
