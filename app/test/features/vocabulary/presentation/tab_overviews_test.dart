import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:flui/features/profile/domain/achievements.dart';
import 'package:flui/features/profile/presentation/providers/progress_overview.dart';
import 'package:flui/features/reading/domain/reading.dart';
import 'package:flui/features/reading/presentation/providers/context_readings.dart';
import 'package:flui/features/vocabulary/domain/exercises/exercise_attempt.dart';
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

  test('contextReadings keeps every word the user has met', () async {
    final readings = await load(contextReadingsProvider.future);

    // perspicaz was introduced on day 1: the old seven-day window dropped it.
    expect(readings.map((r) => r.word.lemma).toSet(), {
      'matizar',
      'plantear',
      'perspicaz',
    });
    expect(readings, hasLength(9));
    expect(readings.where((r) => r.reading.scene == Scene.trabajo), isNotEmpty);
  });

  test('contextReadings rotates the order once a day', () async {
    final first = await load(contextReadingsProvider.future);
    final tomorrow = LearningFakes(now: DateTime(2026, 9, 17, 9));
    addTearDown(tomorrow.dispose);
    for (final row in (await fakes.progress.fetchProgress()).valueOrNull!) {
      await tomorrow.progress.saveProgress(row);
    }
    final next = createTestContainer(overrides: tomorrow.overrides);
    addTearDown(next.dispose);
    next.listen(contextReadingsProvider.future, (_, _) {});

    final second = await next.read(contextReadingsProvider.future);

    expect(
      second.map((r) => r.reading.id).toSet(),
      first.map((r) => r.reading.id).toSet(),
    );
    expect(second.first.reading.id, isNot(first.first.reading.id));
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
