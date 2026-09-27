import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/challenge.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/skill_profile.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:flui/features/training/domain/training_mode.dart';
import 'package:flui/features/training/domain/training_planner.dart';
import 'package:flutter_test/flutter_test.dart';

SkillProfile _profile({
  SkillArea top = SkillArea.thinking,
  SkillArea second = SkillArea.language,
}) => SkillProfile(
  topArea: top,
  topBehavior: BehaviorCode.noClosing,
  secondArea: second,
  secondBehavior: BehaviorCode.vagueWord,
  strengths: const [],
  evidence: const [],
);

Challenge _challenge({
  required String id,
  required Skill skill,
  int difficulty = 1,
  int sortOrder = 0,
}) => Challenge(
  id: id,
  slug: id,
  purpose: ChallengePurpose.training,
  skill: skill,
  difficulty: difficulty,
  prompt: 'Habla sobre algo interesante que te haya pasado hoy.',
  focus: 'claridad',
  focusBehaviors: const [],
  transferPrompts: const ['Cuéntalo otra vez con más detalle.'],
  targetDuration: const Duration(seconds: 30),
  sortOrder: sortOrder,
  mode: TrainingMode.thinkAndSpeak,
);

void main() {
  const planner = TrainingPlanner();
  final today = LocalDate(2026, 9, 26);

  group('focus selection', () {
    test('falls back to the diagnosis profile with no prior non-diagnosis '
        'attempts', () {
      final plan = planner.planDay(
        profile: _profile(),
        recentAttempts: const [],
        publishedChallenges: [_challenge(id: 'c1', skill: Skill.thinking)],
        dueReviewWordIds: const [],
        budgetMinutes: 10,
        difficulty: 1,
        today: today,
      );

      expect(plan.reason, PlanReason.fromDiagnosis);
      expect(plan.focusArea, SkillArea.thinking);
    });

    test('shifts focus when the top behavior improved and another area needs '
        'work', () {
      final recent = [
        for (var i = 0; i < 5; i++)
          TrainingAttemptSummary(
            date: today.addDays(-i),
            context: TrainingContext.daily,
            opportunityCodes: const [BehaviorCode.vagueWord],
          ),
      ];

      final plan = planner.planDay(
        profile: _profile(),
        recentAttempts: recent,
        publishedChallenges: [_challenge(id: 'c1', skill: Skill.language)],
        dueReviewWordIds: const [],
        budgetMinutes: 10,
        difficulty: 1,
        today: today,
      );

      expect(plan.reason, PlanReason.shift);
      expect(plan.focusArea, SkillArea.language);
    });

    test('does not shift when the top behavior keeps showing up', () {
      final recent = [
        for (var i = 0; i < 5; i++)
          TrainingAttemptSummary(
            date: today.addDays(-i),
            context: TrainingContext.daily,
            opportunityCodes: const [
              BehaviorCode.noClosing,
              BehaviorCode.vagueWord,
            ],
          ),
      ];

      final plan = planner.planDay(
        profile: _profile(),
        recentAttempts: recent,
        publishedChallenges: [_challenge(id: 'c1', skill: Skill.thinking)],
        dueReviewWordIds: const [],
        budgetMinutes: 10,
        difficulty: 1,
        today: today,
      );

      expect(plan.reason, isNot(PlanReason.shift));
      expect(plan.focusArea, SkillArea.thinking);
    });
  });

  group('woven review words (never new words)', () {
    test('an empty due-words list produces an empty woven list, not a '
        'failure', () {
      final plan = planner.planDay(
        profile: _profile(),
        recentAttempts: const [],
        publishedChallenges: [_challenge(id: 'c1', skill: Skill.thinking)],
        dueReviewWordIds: const [],
        budgetMinutes: 20,
        difficulty: 1,
        today: today,
      );

      expect(plan.wovenWordIds, isEmpty);
    });

    test('woven words are capped at min(3, rounds) and never fabricated', () {
      final plan = planner.planDay(
        profile: _profile(),
        recentAttempts: const [],
        publishedChallenges: [_challenge(id: 'c1', skill: Skill.thinking)],
        dueReviewWordIds: const ['w1', 'w2', 'w3', 'w4', 'w5'],
        budgetMinutes: 20,
        difficulty: 1,
        today: today,
      );

      expect(plan.wovenWordIds, ['w1', 'w2', 'w3']);
    });
  });

  group('challenge catalog', () {
    test(
      'an empty catalog for the focus skill is unavailable, not a crash',
      () {
        final plan = planner.planDay(
          profile: _profile(),
          recentAttempts: const [],
          publishedChallenges: const [],
          dueReviewWordIds: const [],
          budgetMinutes: 10,
          difficulty: 1,
          today: today,
        );

        expect(plan.isUnavailable, isTrue);
        expect(plan.reason, PlanReason.fromDiagnosis);
      },
    );

    test('excludes a challenge used within the last 7 days, falls back to '
        'another at the same difficulty', () {
      final used = _challenge(id: 'used', skill: Skill.thinking);
      final fresh = _challenge(
        id: 'fresh',
        skill: Skill.thinking,
        sortOrder: 1,
      );

      final plan = planner.planDay(
        profile: _profile(),
        recentAttempts: [
          TrainingAttemptSummary(
            date: today.addDays(-2),
            context: TrainingContext.daily,
            opportunityCodes: const [],
            challengeId: 'used',
          ),
        ],
        publishedChallenges: [used, fresh],
        dueReviewWordIds: const [],
        budgetMinutes: 10,
        difficulty: 1,
        today: today,
      );

      expect(plan.challenge?.id, 'fresh');
    });

    test('falls back to a used challenge rather than reporting unavailable '
        'when it is the only one', () {
      final onlyOne = _challenge(id: 'only', skill: Skill.thinking);

      final plan = planner.planDay(
        profile: _profile(),
        recentAttempts: [
          TrainingAttemptSummary(
            date: today.addDays(-1),
            context: TrainingContext.quick,
            opportunityCodes: const [],
            challengeId: 'only',
          ),
        ],
        publishedChallenges: [onlyOne],
        dueReviewWordIds: const [],
        budgetMinutes: 10,
        difficulty: 1,
        today: today,
      );

      expect(plan.challenge?.id, 'only');
    });
  });

  group('rounds from budget', () {
    for (final entry in const {5: 1, 10: 2, 20: 3, 30: 3}.entries) {
      test('${entry.key} minutes -> ${entry.value} rounds', () {
        final plan = planner.planDay(
          profile: _profile(),
          recentAttempts: const [],
          publishedChallenges: [_challenge(id: 'c1', skill: Skill.thinking)],
          dueReviewWordIds: const ['w1', 'w2', 'w3', 'w4'],
          budgetMinutes: entry.key,
          difficulty: 1,
          today: today,
        );

        expect(plan.rounds, entry.value);
      });
    }
  });
}
