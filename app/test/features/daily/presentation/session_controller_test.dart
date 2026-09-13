import 'package:flui/core/error/failure.dart';
import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:flui/features/daily/domain/session_step.dart';
import 'package:flui/features/daily/presentation/controllers/session_controller.dart';
import 'package:flui/features/exercises/domain/cloze_attempt_flow.dart';
import 'package:flui/features/exercises/domain/exercise_attempt.dart';
import 'package:flui/features/exercises/domain/form_recall_check.dart';
import 'package:flui/features/exercises/domain/production_check.dart';
import 'package:flui/features/vocabulary/domain/grade.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/learning_builders.dart';
import '../../../helpers/learning_fakes.dart';
import '../../../helpers/test_container.dart';

abstract final class ExerciseAttemptFixture {
  static ExerciseAttempt good(String wordId, String exerciseId) =>
      ExerciseAttempt(
        exerciseId: exerciseId,
        wordId: wordId,
        attempts: 1,
        revealed: false,
        grade: Grade.good,
        localDate: day(13),
      );
}

void main() {
  late LearningFakes fakes;
  late ProviderContainer container;
  final perspicaz = seedWord('perspicaz');
  final plantear = seedWord('plantear');

  String option(Word word, int exercise, String text) =>
      word.exercises[exercise - 1].options.firstWhere((o) => o.text == text).id;

  setUp(() {
    fakes = LearningFakes();
    container = createTestContainer(overrides: fakes.overrides);
  });

  tearDown(() => fakes.dispose());

  /// Opens the session and returns its controller once loaded.
  Future<SessionController> open(SessionMode mode) {
    container.listen(sessionControllerProvider(mode), (_, _) {});
    return container
        .read(sessionControllerProvider(mode).future)
        .then((_) => container.read(sessionControllerProvider(mode).notifier));
  }

  SessionState read(SessionMode mode) =>
      container.read(sessionControllerProvider(mode)).requireValue;

  Future<void> planToday({
    List<String> newWords = const [],
    List<String> reviews = const [],
  }) => fakes.sessions.saveSession(
    DailySession(
      localDate: day(13),
      minutes: 10,
      plannedWordIds: newWords,
      reviewWordIds: reviews,
    ),
  );

  const daily = SessionMode.daily;

  test('a first day: Descubre → Mira → Elige → Úsala → check', () async {
    await planToday(newWords: [perspicaz.id]);
    final session = await open(daily);

    expect(read(daily).step, SessionStep.discover(wordId: perspicaz.id));
    expect(read(daily).word, perspicaz);
    expect(read(daily).flow.total, 6);

    await session.continueStep();
    final introduced = (await fakes.progress.fetchProgress()).valueOrNull!;
    expect(introduced.single.state, WordState.nueva);
    expect(introduced.single.introducedOn, day(13));
    expect(read(daily).step, isA<ReadingsStep>());

    await session.continueStep();
    expect(read(daily).step, isA<PracticeClozeStep>());
    expect(read(daily).cloze!.options.map((o) => o.text), [
      'suspicaz',
      'perspicaz',
      'perspicuo',
    ]);

    await session.answerCloze(option(perspicaz, 1, 'suspicaz'));
    expect(read(daily).cloze!.feedback!.kind, ClozeHintKind.general);
    expect((await fakes.attempts.fetchAttempts()).valueOrNull, isEmpty);

    session.retryCloze();
    expect(read(daily).cloze!.feedback, isNull);

    await session.answerCloze(option(perspicaz, 1, 'perspicaz'));
    final elige = (await fakes.attempts.fetchAttempts()).valueOrNull!.single;
    expect(elige.attempts, 2);
    expect(elige.grade, Grade.hard);
    expect(elige.localDate, day(13));

    await session.continueStep();
    expect(read(daily).step, isA<FormRecallStep>());
    expect(read(daily).formRecallPrompt!.hasSentence, isTrue);

    await session.submitFormRecall('perspikaz');
    expect(read(daily).formRecall!.status, FormRecallStatus.accepted);
    expect(
      (await fakes.progress.fetchProgress()).valueOrNull!.single.formRecallDone,
      isTrue,
    );

    await session.continueStep();
    expect(read(daily).step, isA<ProductionStep>());
    session.submitProduction('Hola');
    expect(read(daily).production!.issue, ProductionIssue.tooShort);
    session.submitProduction('Tu pregunta fue muy perspicaz, Carla.');
    expect(read(daily).production!.phase, ProductionPhase.selfCheck);
    session
      ..reviseProduction()
      ..submitProduction('Tu pregunta fue muy perspicaz, Carla.');
    await session.confirmProduction();

    expect(
      (await fakes.progress.fetchProgress()).valueOrNull!.single.productionDone,
      isTrue,
    );
    expect(read(daily).step, isA<FinalCheckStep>());
    expect(read(daily).exercise!.id, perspicaz.exercises[1].id);

    await session.answerCloze(option(perspicaz, 2, 'perspicaz'));
    final progress = (await fakes.progress.fetchProgress()).valueOrNull!.single;
    expect(progress.state, WordState.practica);
    expect(progress.nextDueOn, day(14));

    await session.continueStep();
    expect(read(daily).isFinished, isTrue);
    expect(read(daily).summaryNewWordIds, [perspicaz.id]);
    final saved = (await fakes.sessions.fetchSessions()).valueOrNull!.single;
    expect(saved.isCompleted, isTrue);
  });

  test('a failed check keeps the word nueva and due tomorrow', () async {
    await planToday(newWords: [perspicaz.id]);
    final session = await open(daily);
    await session.continueStep();
    await session.continueStep();
    await session.answerCloze(option(perspicaz, 1, 'perspicaz'));
    await session.continueStep();
    await session.takeFormRecallHint();
    await session.takeFormRecallHint();
    await session.takeFormRecallHint();
    expect(read(daily).formRecall!.status, FormRecallStatus.revealed);
    await session.continueStep();
    session.submitProduction('Mi jefa es muy perspicaz con los clientes.');
    await session.confirmProduction();

    await session.answerCloze(option(perspicaz, 2, 'locuaz'));
    await session.answerCloze(option(perspicaz, 2, 'perspicaz'));

    final progress = (await fakes.progress.fetchProgress()).valueOrNull!.single;
    expect(progress.state, WordState.nueva);
    expect(progress.formRecallDone, isFalse);
    expect(progress.nextDueOn, day(14));
  });

  test('reloading resumes after the last saved step', () async {
    await planToday(newWords: [perspicaz.id]);
    var session = await open(daily);
    await session.continueStep();
    await session.continueStep();
    await session.answerCloze(option(perspicaz, 1, 'perspicaz'));

    container.invalidate(sessionControllerProvider(daily));
    session = await open(daily);

    expect(read(daily).step, isA<FormRecallStep>());
    expect(read(daily).flow.position, 4);
  });

  test('review mode grades due words on the ladder', () async {
    await fakes.progress.saveProgress(
      buildProgress(
        wordId: plantear.id,
        nextDueOn: day(12),
        formRecallDone: true,
        productionDone: true,
        ladderStep: 1,
      ),
    );
    const review = SessionMode.review;
    final session = await open(review);

    expect(
      read(review).step,
      SessionStep.reviewCloze(
        wordId: plantear.id,
        exerciseId: plantear.exercises.first.id,
      ),
    );
    await session.answerCloze(option(plantear, 1, 'planteó'));

    final progress = (await fakes.progress.fetchProgress()).valueOrNull!.single;
    expect(progress.ladderStep, 2);
    expect(progress.nextDueOn, day(20));
    expect(progress.firstTrySuccessDays, {day(13)});

    await session.continueStep();
    expect(read(review).isFinished, isTrue);
    expect((await fakes.sessions.fetchSessions()).valueOrNull, isEmpty);
  });

  test(
    'a review that completes the criteria celebrates "Ya es tuya"',
    () async {
      await fakes.progress.saveProgress(
        buildProgress(
          wordId: plantear.id,
          nextDueOn: day(13),
          successDays: {day(2), day(6)},
          formRecallDone: true,
          productionDone: true,
          ladderStep: 2,
        ),
      );
      const review = SessionMode.review;
      final session = await open(review);

      await session.answerCloze(option(plantear, 1, 'planteó'));

      expect(read(review).ownedWordIds, [plantear.id]);
      expect(read(review).progress[plantear.id]!.state, WordState.tuya);
    },
  );

  test('three forced reveals switch the session to reading mode', () async {
    final ids = [
      for (final lemma in ['plantear', 'matizar', 'sopesar', 'zanjar'])
        seedWord(lemma).id,
    ];
    for (final id in ids) {
      await fakes.progress.saveProgress(
        buildProgress(
          wordId: id,
          nextDueOn: day(13),
          formRecallDone: true,
          productionDone: true,
        ),
      );
    }
    await planToday(reviews: ids);
    final session = await open(daily);

    Future<void> reveal() async {
      final cloze = read(daily).cloze!;
      final wrong = cloze.exercise.distractors;
      await session.answerCloze(wrong[0].id);
      await session.answerCloze(wrong[1].id);
      await session.answerCloze(cloze.exercise.correctOption.id);
      await session.continueStep();
    }

    await reveal();
    await reveal();
    expect(read(daily).flow.seeding, isFalse);
    await reveal();

    expect(read(daily).flow.seeding, isTrue);
    expect(read(daily).step, SessionStep.seedingReading(wordId: ids[3]));
    await session.continueStep();
    expect(read(daily).isFinished, isTrue);
  });

  test('a failed save is shown and can be retried', () async {
    await planToday(newWords: [perspicaz.id]);
    final session = await open(daily);
    fakes.progress.nextFailure = const NetworkFailure();

    await session.continueStep();

    expect(read(daily).failure, const NetworkFailure());
    expect(read(daily).step, isA<DiscoverStep>());

    await session.retrySave();

    expect(read(daily).failure, isNull);
    expect(read(daily).step, isA<ReadingsStep>());
  });

  test('a finished session found on reload is completed', () async {
    await fakes.progress.saveProgress(
      buildProgress(wordId: plantear.id, nextDueOn: day(20)),
    );
    await fakes.attempts.recordAttempt(
      ExerciseAttemptFixture.good(plantear.id, plantear.exercises.first.id),
    );
    await planToday(reviews: [plantear.id]);

    await open(daily);

    expect(read(daily).isFinished, isTrue);
    final saved = (await fakes.sessions.fetchSessions()).valueOrNull!.single;
    expect(saved.isCompleted, isTrue);
  });

  test('a day without a plan has nothing pending', () async {
    await open(daily);

    expect(read(daily).isFinished, isTrue);
    expect(read(daily).flow.total, 0);
  });
}
