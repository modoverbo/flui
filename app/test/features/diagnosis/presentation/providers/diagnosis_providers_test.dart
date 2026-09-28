import 'package:flui/features/diagnosis/presentation/providers/diagnosis_providers.dart';
import 'package:flui/features/training/data/fake_challenge_repository.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/challenge.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/presentation/providers/training_providers.dart';
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
}
