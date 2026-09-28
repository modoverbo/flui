import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/daily/presentation/providers/daily_providers.dart';
import 'package:flui/features/diagnosis/data/fake_skill_profile_repository.dart';
import 'package:flui/features/diagnosis/domain/diagnosis_resume_policy.dart';
import 'package:flui/features/diagnosis/presentation/providers/diagnosis_providers.dart';
import 'package:flui/features/training/data/fake_challenge_repository.dart';
import 'package:flui/features/training/data/fake_speaking_attempt_repository.dart';
import 'package:flui/features/training/domain/attempt_kind.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/challenge.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/speaking_attempt.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:flui/features/training/domain/voice_metrics.dart';
import 'package:flui/features/training/presentation/providers/training_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/test_container.dart';

Challenge _diagnosis({
  required String id,
  required int slot,
  required int sortOrder,
}) => Challenge(
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
  sortOrder: sortOrder,
  diagnosisSlot: slot,
);

Challenge _training({required String id, required int sortOrder}) => Challenge(
  id: id,
  slug: id,
  purpose: ChallengePurpose.training,
  skill: Skill.language,
  difficulty: 1,
  prompt: 'Prompt $id',
  focus: 'Focus $id',
  focusBehaviors: const <BehaviorCode>[],
  transferPrompts: const <String>['transfer'],
  targetDuration: const Duration(seconds: 30),
  sortOrder: sortOrder,
);

void main() {
  group('diagnosisChallengesProvider', () {
    test('picks exactly one, lowest-sortOrder challenge per slot — a real '
        'diagnosis session never asks the same slot twice, even when the '
        'content pipeline publishes multiple variants per slot', () async {
      final container = createTestContainer(
        overrides: [
          challengeRepositoryProvider.overrideWithValue(
            FakeChallengeRepository(
              challenges: [
                _diagnosis(id: 's1-easy', slot: 1, sortOrder: 1),
                _diagnosis(id: 's1-hard', slot: 1, sortOrder: 2),
                _diagnosis(id: 's2-hard', slot: 2, sortOrder: 4),
                _diagnosis(id: 's2-easy', slot: 2, sortOrder: 3),
                _diagnosis(id: 's3-easy', slot: 3, sortOrder: 5),
                _training(id: 't1', sortOrder: 0),
              ],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final challenges = await container.read(
        diagnosisChallengesProvider.future,
      );

      expect(challenges.map((c) => c.id).toList(), [
        's1-easy',
        's2-easy',
        's3-easy',
      ]);
    });

    test('a slot with no published challenge is simply absent, never '
        'fabricated', () async {
      final container = createTestContainer(
        overrides: [
          challengeRepositoryProvider.overrideWithValue(
            FakeChallengeRepository(
              challenges: [
                _diagnosis(id: 's1', slot: 1, sortOrder: 1),
                _diagnosis(id: 's3', slot: 3, sortOrder: 1),
              ],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final challenges = await container.read(
        diagnosisChallengesProvider.future,
      );

      expect(challenges.map((c) => c.id).toList(), ['s1', 's3']);
    });
  });

  group('diagnosisResumeProvider', () {
    const metrics = VoiceMetrics(
      longPauses: 0,
      usefulPauses: 0,
      fillerCount: 0,
    );

    SpeakingAttempt attempt({
      required String sessionId,
      required String challengeId,
    }) => SpeakingAttempt(
      id: 'a-$challengeId',
      sessionId: sessionId,
      context: TrainingContext.diagnosis,
      kind: AttemptKind.first,
      localDate: LocalDate(2026, 9, 14),
      transcript: 'Hablé sobre mi rutina diaria.',
      duration: const Duration(seconds: 20),
      metrics: metrics,
      audio: const AudioRetention.none(),
      challengeId: challengeId,
    );

    Future<ProviderContainer> buildContainer({
      List<SpeakingAttempt> attempts = const [],
    }) async {
      final speakingAttempts = FakeSpeakingAttemptRepository(
        currentUserId: () => 'u1',
      );
      for (final attempt in attempts) {
        await speakingAttempts.insert(attempt);
      }
      return createTestContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('u1'),
          challengeRepositoryProvider.overrideWithValue(
            FakeChallengeRepository(
              challenges: [
                _diagnosis(id: 'c1', slot: 1, sortOrder: 1),
                _diagnosis(id: 'c2', slot: 2, sortOrder: 1),
                _diagnosis(id: 'c3', slot: 3, sortOrder: 1),
              ],
            ),
          ),
          speakingAttemptRepositoryProvider.overrideWithValue(speakingAttempts),
          skillProfileRepositoryProvider.overrideWithValue(
            FakeSkillProfileRepository(currentUserId: () => 'u1'),
          ),
        ],
      );
    }

    test('no attempts yet -> fresh', () async {
      final container = await buildContainer();
      addTearDown(container.dispose);

      final decision = await container.read(diagnosisResumeProvider.future);

      expect(decision, isA<DiagnosisFresh>());
    });

    test('1 answered slot -> resume at slot 2', () async {
      final container = await buildContainer(
        attempts: [attempt(sessionId: 's1', challengeId: 'c1')],
      );
      addTearDown(container.dispose);

      final decision = await container.read(diagnosisResumeProvider.future);

      final resume = decision as DiagnosisResume;
      expect(resume.sessionId, 's1');
      expect(resume.nextSlot, 2);
    });
  });
}
