import 'package:flui/features/daily/domain/session_planner.dart';
import 'package:flui/features/daily/domain/time_budget.dart';
import 'package:flui/features/daily/presentation/controllers/plan_today.dart';
import 'package:flui/features/diagnosis/domain/skill_profile_repository.dart';
import 'package:flui/features/training/data/fake_challenge_repository.dart';
import 'package:flui/features/training/domain/attempt_kind.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/challenge.dart';
import 'package:flui/features/training/domain/observation.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/skill_profile.dart';
import 'package:flui/features/training/domain/speaking_attempt.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:flui/features/training/domain/training_mode.dart';
import 'package:flui/features/training/domain/training_planner.dart';
import 'package:flui/features/training/domain/voice_metrics.dart';
import 'package:flui/features/vocabulary/domain/word_progress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/learning_fakes.dart';
import '../../../../helpers/test_container.dart';

Challenge _challenge({
  required String id,
  required Skill skill,
  int sortOrder = 1,
}) => Challenge(
  id: id,
  slug: id,
  purpose: ChallengePurpose.training,
  skill: skill,
  difficulty: 1,
  prompt: 'Habla sobre algo interesante que te haya pasado hoy.',
  focus: 'claridad',
  focusBehaviors: const [],
  transferPrompts: const ['Cuéntalo otra vez con más detalle.'],
  targetDuration: const Duration(seconds: 30),
  sortOrder: sortOrder,
  mode: TrainingMode.thinkAndSpeak,
);

SkillProfileRecord _profileRecord() => SkillProfileRecord(
  id: 'diagnosis-1',
  kind: SkillProfileKind.baseline,
  diagnosedAt: DateTime.utc(2026, 8),
  profile: const SkillProfile(
    topArea: SkillArea.thinking,
    topBehavior: BehaviorCode.noClosing,
    secondArea: SkillArea.language,
    secondBehavior: BehaviorCode.vagueWord,
    strengths: [BehaviorCode.steadyPace],
    evidence: [],
  ),
);

void main() {
  late LearningFakes fakes;

  setUp(() => fakes = LearningFakes(speakingGym: true));
  tearDown(() => fakes.dispose());

  ProviderContainer container({List<Challenge>? challenges}) {
    if (challenges != null) {
      fakes.challenges = FakeChallengeRepository(challenges: challenges);
    }
    return createTestContainer(overrides: fakes.overrides);
  }

  group('PlanToday.run — word plan (regression, U15a.1-U15a.3)', () {
    test('flag off: persists exactly what SessionPlanner.plan computes, no '
        'training fields', () async {
      fakes = LearningFakes();
      final ref = container();
      addTearDown(ref.dispose);

      final saved = await ref
          .read(planTodayProvider)
          .run(budget: TimeBudget.ten);

      expect(saved.isOk, isTrue);
      final persisted =
          (await fakes.sessions.fetchSessions()).valueOrNull!.single;

      final catalog = (await fakes.content.fetchCatalog()).valueOrNull!;
      final inputs = SessionPlanInputs.derive(
        catalog: catalog,
        progress: const <WordProgress>[],
        today: fakes.today,
      );
      final expected = SessionPlanner.plan(
        budgetMinutes: TimeBudget.ten.minutes,
        today: fakes.today,
        dueReviews: inputs.dueReviews,
        candidates: inputs.candidates,
        recentIntroductions: inputs.recentIntroductions,
      );
      expect(persisted.plannedWordIds, expected.newWordIds);
      expect(persisted.reviewWordIds, expected.reviewWordIds);
      expect(persisted.focusArea, isNull);
      expect(persisted.challengeId, isNull);
      expect(persisted.wovenWordIds, isEmpty);
    });

    test('flag on: the word plan is unchanged, only the training fields are '
        'new', () async {
      final ref = container();
      addTearDown(ref.dispose);

      await ref.read(planTodayProvider).run(budget: TimeBudget.ten);
      final withFlag =
          (await fakes.sessions.fetchSessions()).valueOrNull!.single;

      fakes = LearningFakes();
      final refFlagOff = container();
      addTearDown(refFlagOff.dispose);
      await refFlagOff.read(planTodayProvider).run(budget: TimeBudget.ten);
      final withoutFlag =
          (await fakes.sessions.fetchSessions()).valueOrNull!.single;

      expect(withFlag.plannedWordIds, withoutFlag.plannedWordIds);
      expect(withFlag.reviewWordIds, withoutFlag.reviewWordIds);
    });
  });

  group('PlanToday.run — training plan (U15a.2)', () {
    test(
      'with no diagnosis profile yet: no training fields, no crash',
      () async {
        final ref = container();
        addTearDown(ref.dispose);

        final saved = await ref
            .read(planTodayProvider)
            .run(budget: TimeBudget.ten);

        expect(saved.isOk, isTrue);
        expect(saved.valueOrNull!.focusArea, isNull);
        expect(saved.valueOrNull!.challengeId, isNull);
      },
    );

    test("with a diagnosis profile: persists TrainingPlanner.planDay's own "
        'focus/challenge/woven picks', () async {
      fakes.skillProfiles.seedProfile(_profileRecord());
      final ref = container(
        challenges: [
          _challenge(id: 'c-thinking', skill: Skill.thinking),
          _challenge(id: 'c-language', skill: Skill.language, sortOrder: 2),
        ],
      );
      addTearDown(ref.dispose);

      final saved = await ref
          .read(planTodayProvider)
          .run(budget: TimeBudget.ten);

      final persisted = saved.valueOrNull!;
      final expected = const TrainingPlanner().planDay(
        profile: _profileRecord().profile,
        recentAttempts: const [],
        publishedChallenges: [
          _challenge(id: 'c-thinking', skill: Skill.thinking),
        ],
        dueReviewWordIds: persisted.reviewWordIds,
        budgetMinutes: TimeBudget.ten.minutes,
        difficulty: 1,
        today: fakes.today,
      );
      expect(persisted.focusArea, expected.focusArea.name);
      expect(persisted.challengeId, expected.challenge!.id);
      expect(persisted.wovenWordIds, expected.wovenWordIds);
    });

    test('recent attempts feed opportunityCodes from observations, filtered '
        'to polarity=opportunity', () async {
      fakes.skillProfiles.seedProfile(_profileRecord());
      for (var i = 0; i < 3; i++) {
        await fakes.speakingAttempts.insert(
          SpeakingAttempt(
            id: 'a$i',
            sessionId: 's$i',
            context: TrainingContext.daily,
            kind: AttemptKind.first,
            localDate: fakes.today.addDays(-i),
            transcript: 'texto de prueba suficientemente largo',
            duration: const Duration(seconds: 20),
            metrics: const VoiceMetrics(
              longPauses: 0,
              usefulPauses: 0,
              fillerCount: 0,
            ),
            audio: const AudioRetention.none(),
            observations: const [
              Observation(
                code: BehaviorCode.vagueWord,
                source: ObservationSource.ai,
              ),
              Observation(
                code: BehaviorCode.preciseWord,
                source: ObservationSource.ai,
              ),
            ],
          ),
        );
      }
      final ref = container(
        challenges: [
          _challenge(id: 'c-thinking', skill: Skill.thinking),
          _challenge(id: 'c-language', skill: Skill.language, sortOrder: 2),
        ],
      );
      addTearDown(ref.dispose);

      final saved = await ref
          .read(planTodayProvider)
          .run(budget: TimeBudget.ten);

      // vagueWord is an opportunity in `language`; preciseWord is a
      // strength — only the opportunity ever drives a focus shift, proving
      // `PlanToday` filtered by `Polarity.opportunity` before handing the
      // summaries to `TrainingPlanner`.
      expect(saved.valueOrNull!.focusArea, SkillArea.language.name);
    });
  });

  group('PlanToday — persisted plan is stable across reload', () {
    test('reading the session again never re-rolls the persisted training '
        'plan', () async {
      fakes.skillProfiles.seedProfile(_profileRecord());
      final ref = container(
        challenges: [_challenge(id: 'c-thinking', skill: Skill.thinking)],
      );
      addTearDown(ref.dispose);
      await ref.read(planTodayProvider).run(budget: TimeBudget.ten);
      final first = (await fakes.sessions.fetchSessions()).valueOrNull!.single;

      // A passive reload never calls PlanToday.run again — it only reads
      // the repository, which returns exactly what was persisted.
      final second = (await fakes.sessions.fetchSessions()).valueOrNull!.single;

      expect(second.focusArea, first.focusArea);
      expect(second.challengeId, first.challengeId);
      expect(second.wovenWordIds, first.wovenWordIds);
    });
  });

  group('PlanToday.previewTrainingGoal (U15a.4-U15a.5)', () {
    test('flag off: always null', () async {
      fakes = LearningFakes();
      final ref = container();
      addTearDown(ref.dispose);

      final preview = await ref
          .read(planTodayProvider)
          .previewTrainingGoal(TimeBudget.ten);

      expect(preview, isNull);
    });

    test('flag on, signed out: null, never throws', () async {
      fakes = LearningFakes(signedIn: false, speakingGym: true);
      final ref = container();
      addTearDown(ref.dispose);

      final preview = await ref
          .read(planTodayProvider)
          .previewTrainingGoal(TimeBudget.ten);

      expect(preview, isNull);
    });

    test(
      'flag on, with a profile: previews without persisting anything',
      () async {
        fakes.skillProfiles.seedProfile(_profileRecord());
        final ref = container(
          challenges: [_challenge(id: 'c-thinking', skill: Skill.thinking)],
        );
        addTearDown(ref.dispose);

        final preview = await ref
            .read(planTodayProvider)
            .previewTrainingGoal(TimeBudget.twenty);

        expect(preview, isNotNull);
        expect(preview!.challenge?.id, 'c-thinking');
        expect((await fakes.sessions.fetchSessions()).valueOrNull, isEmpty);
      },
    );

    test(
      'changing the duration re-plans the provisional plan in memory',
      () async {
        fakes.skillProfiles.seedProfile(_profileRecord());
        final ref = container(
          challenges: [_challenge(id: 'c-thinking', skill: Skill.thinking)],
        );
        addTearDown(ref.dispose);
        final planToday = ref.read(planTodayProvider);

        final five = await planToday.previewTrainingGoal(TimeBudget.five);
        final thirty = await planToday.previewTrainingGoal(TimeBudget.thirty);

        expect(five!.rounds, lessThan(thirty!.rounds));
      },
    );
  });
}
