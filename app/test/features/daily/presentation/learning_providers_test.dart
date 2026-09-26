import 'package:flui/core/error/failure.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:flui/features/daily/domain/time_budget.dart';
import 'package:flui/features/daily/presentation/controllers/time_budget_controller.dart';
import 'package:flui/features/daily/presentation/providers/daily_providers.dart';
import 'package:flui/features/daily/presentation/providers/learning_data_controller.dart';
import 'package:flui/features/daily/presentation/providers/today_overview.dart';
import 'package:flui/features/vocabulary/domain/exercises/exercise_attempt.dart';
import 'package:flui/features/vocabulary/domain/grade.dart';
import 'package:flui/features/vocabulary/domain/word_progress.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/learning_builders.dart';
import '../../../helpers/learning_fakes.dart';
import '../../../helpers/test_container.dart';

void main() {
  late LearningFakes fakes;
  late ProviderContainer container;

  setUp(() {
    fakes = LearningFakes();
    container = createTestContainer(overrides: fakes.overrides);
  });

  tearDown(() => fakes.dispose());

  void keepAlive(ProviderListenable<Object?> provider) =>
      container.listen(provider, (_, _) {}, fireImmediately: true);

  Future<LearningData> learningData() => container.read(
    learningDataControllerProvider(LearningFakes.userId).future,
  );

  group('LearningDataController', () {
    test('loads every table of the user', () async {
      await fakes.sessions.saveSession(
        DailySession(localDate: day(12), minutes: 20),
      );
      await fakes.repairs.repairDay(day(10));
      keepAlive(learningDataControllerProvider(LearningFakes.userId));

      final data = await learningData();

      expect(data.sessions.single.minutes, 20);
      expect(data.repairs, [day(10)]);
      expect(data.progress, isEmpty);
    });

    test('writes through the repositories and updates its state', () async {
      keepAlive(learningDataControllerProvider(LearningFakes.userId));
      await learningData();
      final controller = container.read(
        learningDataControllerProvider(LearningFakes.userId).notifier,
      );

      await controller.saveProgress(
        WordProgress.introduced(wordId: 'w1', today: day(13)),
      );
      await controller.recordAttempt(
        ExerciseAttempt(
          exerciseId: 'e1',
          wordId: 'w1',
          attempts: 1,
          revealed: false,
          grade: Grade.good,
          localDate: day(13),
        ),
      );
      await controller.saveSession(
        DailySession(localDate: day(13), minutes: 10),
      );
      await controller.completeSession(day(13), DateTime(2026, 9, 13, 11));
      await controller.repairDay(day(11));

      final data = await learningData();
      expect(data.progressOf('w1')!.state, WordState.nueva);
      expect(data.attempts.single.createdAt, isNotNull);
      expect(data.sessionOn(day(13))!.isCompleted, isTrue);
      expect(data.repairs, [day(11)]);
      expect((await fakes.progress.fetchProgress()).valueOrNull, hasLength(1));
    });

    test('keeps the state when a write fails', () async {
      keepAlive(learningDataControllerProvider(LearningFakes.userId));
      await learningData();
      fakes.progress.nextFailure = const NetworkFailure();

      final result = await container
          .read(learningDataControllerProvider(LearningFakes.userId).notifier)
          .saveProgress(WordProgress.introduced(wordId: 'w1', today: day(13)));

      expect(result.failureOrNull, const NetworkFailure());
      expect((await learningData()).progress, isEmpty);
    });
  });

  group('dailyGateProvider', () {
    test('needs a budget without a session today, then is planned', () async {
      keepAlive(dailyGateProvider);
      expect(container.read(dailyGateProvider), DailyGate.unknown);
      await container.read(authUserProvider.future);
      await learningData();

      expect(container.read(dailyGateProvider), DailyGate.needsBudget);

      await container
          .read(learningDataControllerProvider(LearningFakes.userId).notifier)
          .saveSession(DailySession(localDate: day(13), minutes: 10));

      expect(container.read(dailyGateProvider), DailyGate.planned);
    });

    test('a session from yesterday does not count for today', () async {
      await fakes.sessions.saveSession(
        DailySession(localDate: day(12), minutes: 10),
      );
      keepAlive(dailyGateProvider);
      await container.read(authUserProvider.future);
      await learningData();

      expect(container.read(dailyGateProvider), DailyGate.needsBudget);
    });

    test('is unavailable when the data cannot load', () async {
      fakes.sessions.nextFailure = const NetworkFailure();
      keepAlive(dailyGateProvider);
      await container.read(authUserProvider.future);
      await expectLater(learningData(), throwsA(const NetworkFailure()));

      expect(container.read(dailyGateProvider), DailyGate.unavailable);
    });
  });

  group('TimeBudgetController', () {
    test("preselects yesterday's choice", () async {
      await fakes.sessions.saveSession(
        DailySession(localDate: day(12), minutes: 20),
      );
      keepAlive(preselectedBudgetProvider);

      expect(
        await container.read(preselectedBudgetProvider.future),
        TimeBudget.twenty,
      );
    });

    test('start plans today and saves the daily session', () async {
      keepAlive(timeBudgetControllerProvider);
      keepAlive(dailyGateProvider);

      final saved = await container
          .read(timeBudgetControllerProvider.notifier)
          .start(TimeBudget.ten);

      expect(saved, isTrue);
      final session =
          (await fakes.sessions.fetchSessions()).valueOrNull!.single;
      expect(session.localDate, day(13));
      expect(session.minutes, 10);
      expect(session.plannedWordIds, [seedWord('perspicaz').id]);
      expect(session.reviewWordIds, isEmpty);
      expect(container.read(dailyGateProvider), DailyGate.planned);
    });

    test('5 minutes without reviews saves an empty plan', () async {
      keepAlive(timeBudgetControllerProvider);

      await container
          .read(timeBudgetControllerProvider.notifier)
          .start(TimeBudget.five);

      final session =
          (await fakes.sessions.fetchSessions()).valueOrNull!.single;
      expect(session.isEmpty, isTrue);
    });

    test('due reviews and recent introductions shape the plan', () async {
      final perspicaz = seedWord('perspicaz');
      await fakes.progress.saveProgress(
        buildProgress(wordId: perspicaz.id, nextDueOn: day(13)),
      );
      keepAlive(timeBudgetControllerProvider);

      await container
          .read(timeBudgetControllerProvider.notifier)
          .start(TimeBudget.twenty);

      final session =
          (await fakes.sessions.fetchSessions()).valueOrNull!.single;
      expect(session.reviewWordIds, [perspicaz.id]);
      expect(session.plannedWordIds, [
        seedWord('plantear').id,
        seedWord('matizar').id,
      ]);
    });

    test('a failure is kept for the page', () async {
      keepAlive(timeBudgetControllerProvider);
      fakes.content.nextFailure = const NetworkFailure();

      final saved = await container
          .read(timeBudgetControllerProvider.notifier)
          .start(TimeBudget.ten);

      expect(saved, isFalse);
      expect(
        container.read(timeBudgetControllerProvider).failure,
        const NetworkFailure(),
      );
      expect(container.read(timeBudgetControllerProvider).saving, isFalse);
    });
  });

  group('todayOverviewProvider', () {
    Future<TodayOverview> overview() {
      keepAlive(todayOverviewProvider);
      return container.read(todayOverviewProvider.future);
    }

    test('a planned session not started yet', () async {
      await fakes.sessions.saveSession(
        DailySession(
          localDate: day(13),
          minutes: 10,
          plannedWordIds: [seedWord('perspicaz').id],
        ),
      );

      final today = await overview();

      expect(today.name, 'Ana');
      expect(today.session!.minutes, 10);
      expect(today.newWords.single.lemma, 'perspicaz');
      expect(today.reviewCount, 0);
      expect(today.started, isFalse);
      expect(today.completed, isFalse);
      expect(today.afianzar, isFalse);
    });

    test('started once anything happened today', () async {
      final perspicaz = seedWord('perspicaz');
      await fakes.sessions.saveSession(
        DailySession(
          localDate: day(13),
          minutes: 10,
          plannedWordIds: [perspicaz.id],
        ),
      );
      await fakes.progress.saveProgress(
        WordProgress.introduced(wordId: perspicaz.id, today: day(13)),
      );

      expect((await overview()).started, isTrue);
    });

    test('stats: owned words, days this week and precision', () async {
      await fakes.sessions.saveSession(
        DailySession(localDate: day(13), minutes: 10),
      );
      await fakes.sessions.completeSession(
        localDate: day(13),
        completedAt: DateTime(2026, 9, 13, 9),
      );
      await fakes.progress.saveProgress(
        buildProgress(wordId: 'a', state: WordState.tuya),
      );
      for (final (date, attempts) in [(day(8), 1), (day(9), 2)]) {
        await fakes.attempts.recordAttempt(
          ExerciseAttempt(
            exerciseId: 'e',
            wordId: 'a',
            attempts: attempts,
            revealed: false,
            grade: Grade.fromOutcome(attempts: attempts, revealed: false),
            localDate: date,
          ),
        );
      }

      final today = await overview();

      expect(today.completed, isTrue);
      expect(today.ownedWords, 1);
      expect(today.activeDaysThisWeek, 3);
      expect(today.precisionPercent, 50);
    });
  });
}
