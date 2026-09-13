import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:flui/features/exercises/domain/exercise_attempt.dart';
import 'package:flui/features/exercises/presentation/providers/practice_overview.dart';
import 'package:flui/features/profile/domain/achievements.dart';
import 'package:flui/features/profile/presentation/providers/progress_overview.dart';
import 'package:flui/features/reading/domain/reading.dart';
import 'package:flui/features/reading/presentation/providers/context_readings.dart';
import 'package:flui/features/vocabulary/domain/grade.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';
import 'package:flui/features/vocabulary/presentation/providers/my_words.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/learning_builders.dart';
import '../../../helpers/learning_fakes.dart';
import '../../../helpers/test_container.dart';

void main() {
  late LearningFakes fakes;
  late ProviderContainer container;
  final perspicaz = seedWord('perspicaz');
  final plantear = seedWord('plantear');
  final matizar = seedWord('matizar');

  setUp(() async {
    // Wednesday 2026-09-16.
    fakes = LearningFakes(now: DateTime(2026, 9, 16, 9));
    container = createTestContainer(overrides: fakes.overrides);
    await fakes.progress.saveProgress(
      buildProgress(
        wordId: perspicaz.id,
        state: WordState.tuya,
        introducedOn: day(1),
        nextDueOn: day(30),
        productionDone: true,
      ),
    );
    await fakes.progress.saveProgress(
      buildProgress(
        wordId: plantear.id,
        introducedOn: day(12),
        nextDueOn: day(15),
      ),
    );
    await fakes.progress.saveProgress(
      buildProgress(
        wordId: matizar.id,
        state: WordState.nueva,
        introducedOn: day(16),
        nextDueOn: day(17),
      ),
    );
  });

  tearDown(() => fakes.dispose());

  Future<T> load<T>(ProviderListenable<Future<T>> provider) {
    container.listen(provider, (_, _) {});
    return container.read(provider);
  }

  test('myWords: the repertoire, newest first, with due flags', () async {
    final words = await load(myWordsProvider.future);

    expect(words.map((e) => e.word.lemma), [
      'matizar',
      'plantear',
      'perspicaz',
    ]);
    expect(words[1].isDue, isTrue);
    expect(words[0].isDue, isFalse);
    expect(words[2].progress.state, WordState.tuya);
  });

  test('wordEntry finds one word or null', () async {
    expect((await load(wordEntryProvider(plantear.id).future))!.word, plantear);
    expect(await load(wordEntryProvider('missing').future), isNull);
  });

  test('practiceOverview counts due reviews and the next due date', () async {
    final overview = await load(practiceOverviewProvider.future);

    expect(overview.dueCount, 1);
    expect(overview.nextDueOn, day(17));
    expect(overview.hasWords, isTrue);
  });

  test('contextReadings: readings of words introduced in 7 days', () async {
    final readings = await load(contextReadingsProvider.future);

    expect(readings.map((r) => r.word.lemma).toSet(), {'matizar', 'plantear'});
    expect(readings, hasLength(6));
    expect(readings.first.word.lemma, 'matizar');
    expect(readings.where((r) => r.reading.scene == Scene.trabajo), isNotEmpty);
  });

  test('progressOverview: week, streak, stats and achievements', () async {
    for (final date in [day(14), day(15)]) {
      await fakes.attempts.recordAttempt(
        ExerciseAttempt(
          exerciseId: 'e',
          wordId: plantear.id,
          attempts: 1,
          revealed: false,
          grade: Grade.good,
          localDate: date,
        ),
      );
    }
    await fakes.sessions.saveSession(
      DailySession(localDate: day(12), minutes: 10),
    );
    await fakes.sessions.completeSession(
      localDate: day(12),
      completedAt: DateTime(2026, 9, 12, 20),
    );

    final overview = await load(progressOverviewProvider.future);

    expect(overview.streak.weekDays.take(3), [true, true, false]);
    expect(overview.streak.currentStreak, 2);
    expect(overview.streak.repairableDate, day(13));
    expect(overview.stats.tuya, 1);
    expect(overview.stats.firstTryPrecisionPercent, 100);
    final first = overview.achievements.firstWhere(
      (a) => a.kind == AchievementKind.firstOwnedWord,
    );
    expect(first.isCompleted, isTrue);
  });

  test('the free repair fills the offered day', () async {
    for (final date in [day(12), day(14), day(15)]) {
      await fakes.attempts.recordAttempt(
        ExerciseAttempt(
          exerciseId: 'e',
          wordId: plantear.id,
          attempts: 2,
          revealed: false,
          grade: Grade.hard,
          localDate: date,
        ),
      );
    }
    await load(progressOverviewProvider.future);

    final result = await container
        .read(streakRepairControllerProvider.notifier)
        .repair(day(13));

    expect(result.isOk, isTrue);
    expect((await fakes.repairs.fetchRepairs()).valueOrNull, [day(13)]);
    final overview = await container.read(progressOverviewProvider.future);
    expect(overview.streak.currentStreak, 4);
    expect(overview.streak.repairableDate, isNull);
  });
}
