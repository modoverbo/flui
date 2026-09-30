import 'dart:typed_data';

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:flui/features/daily/domain/session_step.dart';
import 'package:flui/features/daily/presentation/controllers/session_controller.dart';
import 'package:flui/features/speaking/domain/speech_analysis_repository.dart';
import 'package:flui/features/speaking/domain/speech_transcript.dart';
import 'package:flui/features/speaking/presentation/providers/speaking_providers.dart';
import 'package:flui/features/vocabulary/domain/exercises/cloze_attempt_flow.dart';
import 'package:flui/features/vocabulary/domain/exercises/exercise_attempt.dart';
import 'package:flui/features/vocabulary/domain/exercises/form_recall_check.dart';
import 'package:flui/features/vocabulary/domain/exercises/production_check.dart';
import 'package:flui/features/vocabulary/domain/grade.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/learning_builders.dart';
import '../../../helpers/learning_fakes.dart';
import '../../../helpers/test_container.dart';

/// A transcribe-only double: [onTranscribe] controls the outcome per call
/// (`Result.ok`/`Result.err`, matching or mismatching text), and
/// [transcribeCalls] proves exactly how many quota-spending calls a test's
/// actions actually made (D37/R20 regression guard). `analyze` is never
/// used by these tests (spoken word exercises never call it, D34).
final class _ControllableTranscribeRepository
    implements SpeechAnalysisRepository {
  Result<SpeechTranscript> Function(Uint8List audio)? onTranscribe;
  int transcribeCalls = 0;

  @override
  Future<Result<SpeechTranscript>> analyze(
    Uint8List audio, {
    required String mimeType,
    required Duration duration,
    String? challengeId,
  }) => throw UnimplementedError('spoken Úsala never calls analyze (D34)');

  @override
  Future<Result<SpeechTranscript>> transcribe(
    Uint8List audio, {
    required String mimeType,
    required Duration duration,
  }) async {
    transcribeCalls++;
    final handler = onTranscribe;
    if (handler == null) {
      return Result.ok(
        SpeechTranscript(text: '', duration: duration, words: const []),
      );
    }
    return handler(audio);
  }
}

RecordedAudio _fakeAudio() => RecordedAudio(
  bytes: Uint8List.fromList(const [1, 2, 3]),
  mimeType: 'audio/wav',
  duration: const Duration(seconds: 2),
  levelsDbfs: const [],
);

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
  late _ControllableTranscribeRepository speech;
  final perspicaz = seedWord('perspicaz');
  final plantear = seedWord('plantear');

  String option(Word word, int exercise, String text) =>
      word.exercises[exercise - 1].options.firstWhere((o) => o.text == text).id;

  setUp(() {
    fakes = LearningFakes();
    speech = _ControllableTranscribeRepository();
    container = createTestContainer(
      overrides: [
        ...fakes.overrides,
        speechAnalysisRepositoryProvider.overrideWithValue(speech),
      ],
    );
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
    expect(read(daily).flow.total, 7);

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

    speech.onTranscribe = (_) => const Result.ok(
      SpeechTranscript(
        text: 'perspikaz',
        duration: Duration(seconds: 2),
        words: [],
      ),
    );
    await session.answerFormRecallAloud(_fakeAudio());
    expect(read(daily).formRecall!.status, FormRecallStatus.accepted);
    expect(
      (await fakes.progress.fetchProgress()).valueOrNull!.single.formRecallDone,
      isTrue,
    );

    // The scenes held back during discovery come before Úsala.
    await session.continueStep();
    expect(read(daily).step, isA<ReadingsStep>());

    await session.continueStep();
    expect(read(daily).step, isA<ProductionStep>());
    speech.onTranscribe = (_) => const Result.ok(
      SpeechTranscript(text: 'Hola', duration: Duration(seconds: 1), words: []),
    );
    await session.answerProductionAloud(_fakeAudio());
    expect(read(daily).production!.issue, ProductionIssue.tooShort);
    speech.onTranscribe = (_) => const Result.ok(
      SpeechTranscript(
        text: 'Tu pregunta fue muy perspicaz, Carla.',
        duration: Duration(seconds: 3),
        words: [],
      ),
    );
    await session.answerProductionAloud(_fakeAudio());
    expect(read(daily).production!.phase, ProductionPhase.selfCheck);
    session.reviseProduction();
    await session.answerProductionAloud(_fakeAudio());

    // The rubric gates acceptance: one tap on "Sí" is not enough.
    await session.confirmProduction();
    expect(read(daily).production!.isAccepted, isFalse);
    ProductionRubric.values.forEach(session.toggleProductionRubric);
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
    expect(read(daily).step, isA<ReadingsStep>());
    await session.continueStep();
    expect(read(daily).step, isA<ProductionStep>());
    speech.onTranscribe = (_) => const Result.ok(
      SpeechTranscript(
        text: 'Mi jefa es muy perspicaz con los clientes.',
        duration: Duration(seconds: 3),
        words: [],
      ),
    );
    await session.answerProductionAloud(_fakeAudio());
    ProductionRubric.values.forEach(session.toggleProductionRubric);
    await session.confirmProduction();

    expect(read(daily).step, isA<FinalCheckStep>());
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
      for (final lemma in ['plantear', 'matizar', 'sopesar', 'pertinente'])
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
      buildProgress(
        wordId: plantear.id,
        formRecallDone: true,
        productionDone: true,
        nextDueOn: day(20),
      ),
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

  test('an empty plan still counts the day as active', () async {
    await planToday();

    await open(daily);

    expect(read(daily).flow.total, 0);
    final saved = (await fakes.sessions.fetchSessions()).valueOrNull!.single;
    expect(saved.isCompleted, isTrue);
  });

  test('a free run practises words that are not due', () async {
    await fakes.progress.saveProgress(
      buildProgress(
        wordId: plantear.id,
        formRecallDone: true,
        productionDone: true,
        ladderStep: 2,
        nextDueOn: day(20),
      ),
    );
    await planToday();
    final session = await open(SessionMode.free);

    expect(read(SessionMode.free).step, isA<ReviewClozeStep>());
    await session.answerCloze(option(plantear, 1, 'planteó'));

    // The attempt counts for the streak and for precision...
    expect((await fakes.attempts.fetchAttempts()).valueOrNull, hasLength(1));
    // ...but answering early must not push the real review away.
    final progress = (await fakes.progress.fetchProgress()).valueOrNull!.single;
    expect(progress.ladderStep, 2);
    expect(progress.nextDueOn, day(20));
    expect(progress.firstTrySuccessDays, isEmpty);
  });

  test('a free review run counts a day the plan left empty', () async {
    await fakes.progress.saveProgress(
      buildProgress(
        wordId: plantear.id,
        formRecallDone: true,
        productionDone: true,
        nextDueOn: day(20),
      ),
    );
    await planToday();

    await open(SessionMode.review);

    final saved = (await fakes.sessions.fetchSessions()).valueOrNull!.single;
    expect(saved.isCompleted, isTrue);
  });

  test('a free review run never closes a day that still has a plan', () async {
    await planToday(newWords: [perspicaz.id]);

    await open(SessionMode.review);

    final saved = (await fakes.sessions.fetchSessions()).valueOrNull!.single;
    expect(saved.isCompleted, isFalse);
  });

  group('spoken Úsala (U17b, design D34-D37)', () {
    late _ControllableTranscribeRepository speech;
    late ProviderContainer spokenContainer;

    setUp(() {
      speech = _ControllableTranscribeRepository();
      spokenContainer = createTestContainer(
        overrides: [
          ...fakes.overrides,
          speechAnalysisRepositoryProvider.overrideWithValue(speech),
        ],
      );
    });

    Future<SessionController> openSpoken(SessionMode mode) {
      spokenContainer.listen(sessionControllerProvider(mode), (_, _) {});
      return spokenContainer
          .read(sessionControllerProvider(mode).future)
          .then(
            (_) =>
                spokenContainer.read(sessionControllerProvider(mode).notifier),
          );
    }

    SessionState readSpoken(SessionMode mode) =>
        spokenContainer.read(sessionControllerProvider(mode)).requireValue;

    /// Descubre -> Mira -> Elige (correct) -> FormRecallStep, matching the
    /// pre-existing "a first day" test's own sequence above.
    Future<SessionController> reachFormRecall() async {
      final session = await openSpoken(daily);
      await session.continueStep();
      await session.continueStep();
      await session.answerCloze(option(perspicaz, 1, 'perspicaz'));
      await session.continueStep();
      expect(readSpoken(daily).step, isA<FormRecallStep>());
      return session;
    }

    test('a matching transcript accepts and persists formRecallDone, one '
        'transcribe call', () async {
      await planToday(newWords: [perspicaz.id]);
      final session = await reachFormRecall();
      speech.onTranscribe = (_) => const Result.ok(
        SpeechTranscript(
          text: 'perspicaz',
          duration: Duration(seconds: 2),
          words: [],
        ),
      );

      final delivery = await session.answerFormRecallAloud(_fakeAudio());

      expect(delivery, isA<MicAccepted>());
      expect(readSpoken(daily).formRecall!.status, FormRecallStatus.accepted);
      expect(readSpoken(daily).formRecall!.lastHeard, 'perspicaz');
      expect(
        (await fakes.progress.fetchProgress())
            .valueOrNull!
            .single
            .formRecallDone,
        isTrue,
      );
      expect(speech.transcribeCalls, 1);
    });

    test(
      'a mismatching transcript shows the next hint, no persistence',
      () async {
        await planToday(newWords: [perspicaz.id]);
        final session = await reachFormRecall();
        speech.onTranscribe = (_) => const Result.ok(
          SpeechTranscript(
            text: 'gato',
            duration: Duration(seconds: 2),
            words: [],
          ),
        );

        final delivery = await session.answerFormRecallAloud(_fakeAudio());

        expect(delivery, isA<MicAccepted>());
        expect(readSpoken(daily).formRecall!.status, FormRecallStatus.pending);
        expect(readSpoken(daily).formRecall!.hintsUsed, 1);
        expect(readSpoken(daily).formRecall!.lastHeard, 'gato');
        expect(
          (await fakes.progress.fetchProgress())
              .valueOrNull!
              .single
              .formRecallDone,
          isFalse,
        );
      },
    );

    test('a noSpeech transcribe failure returns the distinct copy and consumes '
        'no hint', () async {
      await planToday(newWords: [perspicaz.id]);
      final session = await reachFormRecall();
      speech.onTranscribe = (_) => const Result.err(
        SpeechAnalysisFailure(SpeechAnalysisErrorCode.noSpeech),
      );

      final delivery = await session.answerFormRecallAloud(_fakeAudio());

      expect(
        delivery,
        isA<MicDeliveryFailed>().having(
          (d) => d.message,
          'message',
          'No te escuchamos bien. Inténtalo otra vez.',
        ),
      );
      expect(readSpoken(daily).formRecall!.status, FormRecallStatus.pending);
      expect(readSpoken(daily).formRecall!.hintsUsed, 0);
      expect(readSpoken(daily).formRecall!.lastHeard, isNull);
    });

    test(
      'an access-required failure latches, a quota failure latches',
      () async {
        await planToday(newWords: [perspicaz.id]);
        final accessSession = await reachFormRecall();
        speech.onTranscribe = (_) => const Result.err(
          SpeechAnalysisFailure(SpeechAnalysisErrorCode.accessRequired),
        );
        expect(
          await accessSession.answerFormRecallAloud(_fakeAudio()),
          isA<MicAccessRequired>(),
        );

        speech.onTranscribe = (_) => const Result.err(
          SpeechAnalysisFailure(SpeechAnalysisErrorCode.dailyLimitReached),
        );
        expect(
          await accessSession.answerFormRecallAloud(_fakeAudio()),
          isA<MicDailyLimitReached>(),
        );
      },
    );

    test('never transcribes an already-resolved form recall step (no quota '
        'spent on a resolved step)', () async {
      await planToday(newWords: [perspicaz.id]);
      final session = await reachFormRecall();
      speech.onTranscribe = (_) => const Result.ok(
        SpeechTranscript(
          text: 'perspicaz',
          duration: Duration(seconds: 2),
          words: [],
        ),
      );
      await session.answerFormRecallAloud(_fakeAudio());
      expect(readSpoken(daily).formRecall!.status, FormRecallStatus.accepted);
      final callsBeforeRetry = speech.transcribeCalls;

      final delivery = await session.answerFormRecallAloud(_fakeAudio());

      expect(delivery, isA<MicDeliveryFailed>());
      expect(speech.transcribeCalls, callsBeforeRetry);
    });

    test('never transcribes when the current step is not form recall (no '
        'quota spent on an inactive step)', () async {
      await planToday(newWords: [perspicaz.id]);
      final session = await openSpoken(daily);
      expect(readSpoken(daily).step, isA<DiscoverStep>());

      final delivery = await session.answerFormRecallAloud(_fakeAudio());

      expect(delivery, isA<MicDeliveryFailed>());
      expect(speech.transcribeCalls, 0);
    });

    test('a matching production transcript moves to the self-check phase, one '
        'transcribe call', () async {
      await planToday(newWords: [perspicaz.id]);
      final session = await reachFormRecall();
      speech.onTranscribe = (_) => const Result.ok(
        SpeechTranscript(
          text: 'perspicaz',
          duration: Duration(seconds: 2),
          words: [],
        ),
      );
      await session.answerFormRecallAloud(_fakeAudio());
      await session.continueStep(); // -> readings (scenes held back)
      await session.continueStep(); // -> ProductionStep
      expect(readSpoken(daily).step, isA<ProductionStep>());
      final callsBeforeProduction = speech.transcribeCalls;
      speech.onTranscribe = (_) => const Result.ok(
        SpeechTranscript(
          text: 'Tu pregunta fue muy perspicaz, Carla.',
          duration: Duration(seconds: 4),
          words: [],
        ),
      );

      final delivery = await session.answerProductionAloud(_fakeAudio());

      expect(delivery, isA<MicAccepted>());
      expect(readSpoken(daily).production!.phase, ProductionPhase.selfCheck);
      expect(
        readSpoken(daily).production!.sentence,
        'Tu pregunta fue muy perspicaz, Carla.',
      );
      expect(speech.transcribeCalls, callsBeforeProduction + 1);
    });

    test('a noSpeech production transcribe failure returns the distinct copy, '
        'no state change', () async {
      await planToday(newWords: [perspicaz.id]);
      final session = await reachFormRecall();
      speech.onTranscribe = (_) => const Result.ok(
        SpeechTranscript(
          text: 'perspicaz',
          duration: Duration(seconds: 2),
          words: [],
        ),
      );
      await session.answerFormRecallAloud(_fakeAudio());
      await session.continueStep();
      await session.continueStep();
      expect(readSpoken(daily).step, isA<ProductionStep>());
      speech.onTranscribe = (_) => const Result.err(
        SpeechAnalysisFailure(SpeechAnalysisErrorCode.noSpeech),
      );

      final delivery = await session.answerProductionAloud(_fakeAudio());

      expect(
        delivery,
        isA<MicDeliveryFailed>().having(
          (d) => d.message,
          'message',
          'No te escuchamos bien. Inténtalo otra vez.',
        ),
      );
      expect(readSpoken(daily).production!.phase, ProductionPhase.writing);
      expect(readSpoken(daily).production!.sentence, '');
    });

    test('never transcribes production once the self-check phase is reached '
        '(no quota on a resolved step)', () async {
      await planToday(newWords: [perspicaz.id]);
      final session = await reachFormRecall();
      speech.onTranscribe = (_) => const Result.ok(
        SpeechTranscript(
          text: 'perspicaz',
          duration: Duration(seconds: 2),
          words: [],
        ),
      );
      await session.answerFormRecallAloud(_fakeAudio());
      await session.continueStep();
      await session.continueStep();
      speech.onTranscribe = (_) => const Result.ok(
        SpeechTranscript(
          text: 'Tu pregunta fue muy perspicaz, Carla.',
          duration: Duration(seconds: 4),
          words: [],
        ),
      );
      await session.answerProductionAloud(_fakeAudio());
      expect(readSpoken(daily).production!.phase, ProductionPhase.selfCheck);
      final callsBeforeRetry = speech.transcribeCalls;

      final delivery = await session.answerProductionAloud(_fakeAudio());

      expect(delivery, isA<MicDeliveryFailed>());
      expect(speech.transcribeCalls, callsBeforeRetry);
    });

    test('"Continuar sin hablar" advances without persisting formRecallDone, '
        'the step resurfaces on the next plan', () async {
      await planToday(newWords: [perspicaz.id]);
      final session = await reachFormRecall();

      await session.skipSpokenStep();

      expect(readSpoken(daily).step, isNot(isA<FormRecallStep>()));
      expect(
        (await fakes.progress.fetchProgress())
            .valueOrNull!
            .single
            .formRecallDone,
        isFalse,
      );
    });
  });
}
