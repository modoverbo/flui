import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/diagnosis/domain/diagnosis_resume_policy.dart';
import 'package:flui/features/diagnosis/domain/skill_profile_repository.dart';
import 'package:flui/features/training/domain/attempt_kind.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/challenge.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/skill_profile.dart';
import 'package:flui/features/training/domain/speaking_attempt.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:flui/features/training/domain/voice_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

Challenge _challenge({required String id, required int slot}) => Challenge(
  id: id,
  slug: id,
  purpose: ChallengePurpose.diagnosis,
  skill: Skill.thinking,
  difficulty: 1,
  prompt: 'Prompt $id',
  focus: 'Focus $id',
  focusBehaviors: const <BehaviorCode>[],
  transferPrompts: const <String>[],
  targetDuration: const Duration(seconds: 30),
  sortOrder: 1,
  diagnosisSlot: slot,
);

const _metrics = VoiceMetrics(longPauses: 0, usefulPauses: 0, fillerCount: 0);

SpeakingAttempt _attempt({
  required String id,
  required String sessionId,
  String? challengeId,
}) => SpeakingAttempt(
  id: id,
  sessionId: sessionId,
  context: TrainingContext.diagnosis,
  kind: AttemptKind.first,
  localDate: LocalDate(2026, 9, 14),
  transcript: 'Hablé sobre mi rutina diaria.',
  duration: const Duration(seconds: 20),
  metrics: _metrics,
  audio: const AudioRetention.none(),
  challengeId: challengeId,
);

final Challenge _c1 = _challenge(id: 'c1', slot: 1);
final Challenge _c2 = _challenge(id: 'c2', slot: 2);
final Challenge _c3 = _challenge(id: 'c3', slot: 3);
final Map<String, Challenge> _challengesById = {
  'c1': _c1,
  'c2': _c2,
  'c3': _c3,
};

SkillProfileRecord _profile({required String id}) => SkillProfileRecord(
  id: id,
  kind: SkillProfileKind.baseline,
  diagnosedAt: DateTime(2026, 8),
  profile: const SkillProfile(
    topArea: SkillArea.thinking,
    secondArea: SkillArea.language,
    strengths: <BehaviorCode>[],
    evidence: <DiagnosisEvidence>[],
  ),
);

void main() {
  const policy = DiagnosisResumePolicy();

  group('DiagnosisResumePolicy.decide', () {
    test('no attempts yet -> fresh', () {
      final decision = policy.decide(
        latestDiagnosisAttempts: const [],
        latestProfile: null,
        challengesById: _challengesById,
      );

      expect(decision, isA<DiagnosisFresh>());
    });

    test('1 answered slot -> resume at the next unanswered slot', () {
      final decision = policy.decide(
        latestDiagnosisAttempts: [
          _attempt(id: 'a1', sessionId: 's1', challengeId: 'c1'),
        ],
        latestProfile: null,
        challengesById: _challengesById,
      );

      expect(decision, isA<DiagnosisResume>());
      final resume = decision as DiagnosisResume;
      expect(resume.sessionId, 's1');
      expect(resume.answered.keys, {1});
      expect(resume.nextSlot, 2);
    });

    test('2 answered slots -> resume at the last unanswered slot', () {
      final decision = policy.decide(
        latestDiagnosisAttempts: [
          _attempt(id: 'a1', sessionId: 's1', challengeId: 'c1'),
          _attempt(id: 'a2', sessionId: 's1', challengeId: 'c2'),
        ],
        latestProfile: null,
        challengesById: _challengesById,
      );

      final resume = decision as DiagnosisResume;
      expect(resume.answered.keys, {1, 2});
      expect(resume.nextSlot, 3);
    });

    test('3 answered slots but no profile yet -> resume straight to profiling '
        '(nextSlot null, no recording needed)', () {
      final decision = policy.decide(
        latestDiagnosisAttempts: [
          _attempt(id: 'a1', sessionId: 's1', challengeId: 'c1'),
          _attempt(id: 'a2', sessionId: 's1', challengeId: 'c2'),
          _attempt(id: 'a3', sessionId: 's1', challengeId: 'c3'),
        ],
        latestProfile: null,
        challengesById: _challengesById,
      );

      final resume = decision as DiagnosisResume;
      expect(resume.answered.keys, {1, 2, 3});
      expect(resume.nextSlot, isNull);
    });

    test('the newest session already closed by a matching profile -> fresh '
        '(a new diagnosis/retake, not a resume of the closed one)', () {
      final decision = policy.decide(
        latestDiagnosisAttempts: [
          _attempt(id: 'a1', sessionId: 's1', challengeId: 'c1'),
          _attempt(id: 'a2', sessionId: 's1', challengeId: 'c2'),
          _attempt(id: 'a3', sessionId: 's1', challengeId: 'c3'),
        ],
        latestProfile: _profile(id: 's1'),
        challengesById: _challengesById,
      );

      expect(decision, isA<DiagnosisFresh>());
    });

    test('an attempt whose challenge is unknown/unpublished is ignored — its '
        'slot is re-asked, never inferred', () {
      final decision = policy.decide(
        latestDiagnosisAttempts: [
          _attempt(id: 'a1', sessionId: 's1', challengeId: 'retired-c1'),
          _attempt(id: 'a2', sessionId: 's1', challengeId: 'c2'),
        ],
        latestProfile: null,
        challengesById: _challengesById,
      );

      final resume = decision as DiagnosisResume;
      expect(resume.answered.keys, {2});
      expect(resume.nextSlot, 1);
    });

    test('a profile that closed a DIFFERENT session never masks an open '
        'one (an older profile does not close the newest session)', () {
      final decision = policy.decide(
        latestDiagnosisAttempts: [
          _attempt(id: 'a1', sessionId: 's2', challengeId: 'c1'),
        ],
        latestProfile: _profile(id: 's1'),
        challengesById: _challengesById,
      );

      final resume = decision as DiagnosisResume;
      expect(resume.sessionId, 's2');
      expect(resume.nextSlot, 2);
    });
  });
}
