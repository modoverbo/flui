import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/challenge.dart';
import 'package:flui/features/training/domain/quick_practice_picker.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flutter_test/flutter_test.dart';

Challenge _challenge({
  required String id,
  required int sortOrder,
  ChallengePurpose purpose = ChallengePurpose.training,
}) => Challenge(
  id: id,
  slug: 'slug-$id',
  purpose: purpose,
  skill: Skill.thinking,
  difficulty: 1,
  prompt: 'Cuenta algo breve.',
  focus: 'Estructura tu respuesta.',
  focusBehaviors: const <BehaviorCode>[],
  transferPrompts: purpose == ChallengePurpose.diagnosis
      ? const <String>[]
      : const <String>['Aplica esto mañana.'],
  diagnosisSlot: purpose == ChallengePurpose.diagnosis ? 1 : null,
  targetDuration: const Duration(seconds: 30),
  sortOrder: sortOrder,
);

void main() {
  group('QuickPracticePicker', () {
    const picker = QuickPracticePicker();

    test('picks the lowest-sortOrder published training challenge', () {
      final challenges = [
        _challenge(id: 'c2', sortOrder: 2),
        _challenge(id: 'c1', sortOrder: 1),
        _challenge(id: 'c3', sortOrder: 3),
      ];

      final picked = picker.pick(
        publishedChallenges: challenges,
        recentlyUsedChallengeIds: const <String>{},
      );

      expect(picked?.id, 'c1');
    });

    test('excludes a challenge used in the last 7 days', () {
      final challenges = [
        _challenge(id: 'c1', sortOrder: 1),
        _challenge(id: 'c2', sortOrder: 2),
      ];

      final picked = picker.pick(
        publishedChallenges: challenges,
        recentlyUsedChallengeIds: const {'c1'},
      );

      expect(picked?.id, 'c2');
    });

    test('ignores diagnosis-purpose challenges', () {
      final challenges = [
        _challenge(id: 'd1', sortOrder: 0, purpose: ChallengePurpose.diagnosis),
        _challenge(id: 'c1', sortOrder: 5),
      ];

      final picked = picker.pick(
        publishedChallenges: challenges,
        recentlyUsedChallengeIds: const <String>{},
      );

      expect(picked?.id, 'c1');
    });

    test('an empty catalog never throws, returns null', () {
      expect(
        () => picker.pick(
          publishedChallenges: const <Challenge>[],
          recentlyUsedChallengeIds: const <String>{},
        ),
        returnsNormally,
      );
      expect(
        picker.pick(
          publishedChallenges: const <Challenge>[],
          recentlyUsedChallengeIds: const <String>{},
        ),
        isNull,
      );
    });

    test(
      'every training challenge used recently never throws, returns null',
      () {
        final challenges = [_challenge(id: 'c1', sortOrder: 1)];

        final picked = picker.pick(
          publishedChallenges: challenges,
          recentlyUsedChallengeIds: const {'c1'},
        );

        expect(picked, isNull);
      },
    );
  });
}
