import 'dart:typed_data';

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/features/auth/data/fake_auth_repository.dart';
import 'package:flui/features/auth/domain/app_user.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/daily/data/fake_daily_session_repository.dart';
import 'package:flui/features/daily/presentation/providers/daily_providers.dart';
import 'package:flui/features/profile/data/fake_streak_repair_repository.dart';
import 'package:flui/features/profile/presentation/providers/profile_providers.dart';
import 'package:flui/features/speaking/data/fake_speech_analysis_repository.dart';
import 'package:flui/features/speaking/domain/speech_analysis_repository.dart';
import 'package:flui/features/speaking/domain/speech_transcript.dart';
import 'package:flui/features/speaking/presentation/providers/speaking_providers.dart';
import 'package:flui/features/training/data/fake_attempt_audio_store.dart';
import 'package:flui/features/training/data/fake_audio_consent_repository.dart';
import 'package:flui/features/training/data/fake_challenge_repository.dart';
import 'package:flui/features/training/data/fake_speaking_attempt_repository.dart';
import 'package:flui/features/training/domain/attempt_audio_store.dart';
import 'package:flui/features/training/domain/attempt_kind.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/challenge.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/speaking_attempt.dart';
import 'package:flui/features/training/domain/speaking_attempt_repository.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:flui/features/training/domain/training_loop.dart';
import 'package:flui/features/training/presentation/controllers/loop_mic_target.dart';
import 'package:flui/features/training/presentation/controllers/training_loop_controller.dart';
import 'package:flui/features/training/presentation/providers/training_providers.dart';
import 'package:flui/features/vocabulary/data/fake_content_repository.dart';
import 'package:flui/features/vocabulary/data/fake_exercise_attempt_repository.dart';
import 'package:flui/features/vocabulary/data/fake_word_progress_repository.dart';
import 'package:flui/features/vocabulary/presentation/providers/exercise_providers.dart';
import 'package:flui/features/vocabulary/presentation/providers/vocabulary_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/learning_builders.dart';

/// An insert that fails its first [failNextCalls] calls, then succeeds —
/// lets a test drive the controller's own automatic-retry-then-give-up
/// path deterministically (unlike [FakeSpeakingAttemptRepository]'s
/// single-shot `nextFailure`, which cannot fail two calls in a row).
final class _FlakyAttemptRepository implements SpeakingAttemptRepository {
  new({this.failNextCalls = 0});

  int failNextCalls;
  int callCount = 0;
  final inserted = <SpeakingAttempt>[];

  @override
  Future<Result<SpeakingAttempt>> insert(SpeakingAttempt attempt) async {
    callCount++;
    if (failNextCalls > 0) {
      failNextCalls--;
      return const Result.err(NetworkFailure());
    }
    inserted.add(attempt);
    return Result.ok(attempt);
  }

  @override
  Future<Result<Set<String>>> usedChallengeIdsSince(LocalDate since) async =>
      const Result.ok(<String>{});

  @override
  Future<Result<List<SpeakingAttempt>>> latestDiagnosisAttempts() async =>
      const Result.ok(<SpeakingAttempt>[]);

  @override
  Future<Result<List<SpeakingAttempt>>> recentAttemptsSince(
    LocalDate since,
  ) async => const Result.ok(<SpeakingAttempt>[]);

  @override
  Future<Result<List<SpeakingAttempt>>> attemptsForSession(
    String sessionId,
  ) async => const Result.ok(<SpeakingAttempt>[]);

  @override
  Future<Result<SpeakingAttempt?>> latestStoredMilestone() async =>
      const Result.ok(null);

  @override
  Future<Result<Set<String>>> storedAudioAttemptIds() async =>
      const Result.ok(<String>{});
}

/// Counts `analyze`/`transcribe` calls so a test can assert a save failure
/// never triggers a second (paid) analysis.
final class _CountingSpeechAnalysisRepository
    implements SpeechAnalysisRepository {
  new(this._inner);

  final SpeechAnalysisRepository _inner;
  int analyzeCallCount = 0;

  @override
  Future<Result<SpeechTranscript>> analyze(
    Uint8List audio, {
    required String mimeType,
    required Duration duration,
    String? challengeId,
  }) {
    analyzeCallCount++;
    return _inner.analyze(
      audio,
      mimeType: mimeType,
      duration: duration,
      challengeId: challengeId,
    );
  }

  @override
  Future<Result<SpeechTranscript>> transcribe(
    Uint8List audio, {
    required String mimeType,
    required Duration duration,
  }) => _inner.transcribe(audio, mimeType: mimeType, duration: duration);
}

/// Counts `upload` calls so a test can assert a save failure never fires
/// the milestone upload.
final class _CountingAttemptAudioStore implements AttemptAudioStore {
  new(this._inner);

  final AttemptAudioStore _inner;
  int uploadCallCount = 0;

  @override
  Future<void> upload({
    required String attemptId,
    required Uint8List bytes,
    required String mimeType,
  }) {
    uploadCallCount++;
    return _inner.upload(
      attemptId: attemptId,
      bytes: bytes,
      mimeType: mimeType,
    );
  }

  @override
  Future<Result<void>> delete({required String attemptId}) =>
      _inner.delete(attemptId: attemptId);

  @override
  Future<Result<Uri>> signedUrlFor({required String path}) =>
      _inner.signedUrlFor(path: path);
}

const _challenge = Challenge(
  id: 'c1',
  slug: 'organize-morning',
  purpose: ChallengePurpose.training,
  skill: Skill.thinking,
  difficulty: 1,
  prompt: 'Cuenta cómo organizas tu mañana.',
  focus: 'Estructura tu respuesta con apertura y cierre.',
  focusBehaviors: <BehaviorCode>[],
  transferPrompts: <String>['Cuenta cómo aplicarías esto mañana.'],
  targetDuration: Duration(seconds: 30),
  sortOrder: 1,
);

const _request = LoopRequest(
  context: TrainingContext.daily,
  sessionId: 's1',
  script: LoopScript.full(),
  challengeId: 'c1',
);

const _diagnosisRequest = LoopRequest(
  context: TrainingContext.diagnosis,
  sessionId: 's-diag',
  script: LoopScript.diagnosis(totalSlots: 3),
  challengeIds: ['c1', 'c1', 'c1'],
);

// Deliberately no `targetWordIds`: this group only exercises the
// finished-loop guard, not `SpokenWordUse`'s own detection/mastery wiring
// (already covered elsewhere).
const _wordUseRequest = LoopRequest(
  context: TrainingContext.word,
  sessionId: 's-word',
  script: LoopScript.wordUse(),
);

RecordedAudio _audio({Duration duration = const Duration(seconds: 12)}) =>
    RecordedAudio(
      bytes: Uint8List.fromList(List<int>.filled(10, 1)),
      mimeType: 'audio/wav',
      duration: duration,
      levelsDbfs: const [-30, -28, -32],
    );

void main() {
  late FakeSpeechAnalysisRepository speech;
  late FakeSpeakingAttemptRepository attempts;
  late FakeAttemptAudioStore audioStore;
  late FakeAudioConsentRepository consent;
  late ProviderContainer container;

  setUp(() async {
    speech = FakeSpeechAnalysisRepository(latency: Duration.zero);
    attempts = FakeSpeakingAttemptRepository(currentUserId: () => 'u1');
    audioStore = FakeAttemptAudioStore(currentUserId: () => 'u1');
    consent = FakeAudioConsentRepository(currentUserId: () => 'u1');
    await consent.write(granted: true);

    container = ProviderContainer(
      overrides: [
        speechAnalysisRepositoryProvider.overrideWithValue(speech),
        speakingAttemptRepositoryProvider.overrideWithValue(attempts),
        attemptAudioStoreProvider.overrideWithValue(audioStore),
        audioConsentRepositoryProvider.overrideWithValue(consent),
        challengeRepositoryProvider.overrideWithValue(
          FakeChallengeRepository(challenges: const [_challenge]),
        ),
        clockProvider.overrideWithValue(FixedClock(DateTime(2026, 9, 28))),
      ],
    );
    addTearDown(container.dispose);
  });

  TrainingLoopController controller() =>
      container.read(trainingLoopControllerProvider(_request).notifier);
  TrainingLoopControllerState state() =>
      container.read(trainingLoopControllerProvider(_request));

  group('TrainingLoopController.submit — full-script happy path', () {
    test('persists first+repeat and fires the milestone upload for the '
        'first attempt only', () async {
      final firstDelivery = await controller().submit(_audio());

      expect(firstDelivery, isA<MicAccepted>());
      expect(state().loop.phase, LoopPhase.feedback);
      expect(state().feedback, isNotNull);
      expect(attempts.attemptsForCurrentUser, hasLength(1));
      expect(attempts.attemptsForCurrentUser.single.kind, AttemptKind.first);

      final repeatDelivery = await controller().submit(_audio());

      expect(repeatDelivery, isA<MicAccepted>());
      expect(state().loop.phase, LoopPhase.comparison);
      expect(state().comparison, isNotNull);
      expect(attempts.attemptsForCurrentUser, hasLength(2));
      expect(attempts.attemptsForCurrentUser.last.kind, AttemptKind.repeat);

      // MilestonePolicy only ever retains the FIRST attempt's audio.
      await pumpEventQueue();
      final first = attempts.attemptsForCurrentUser.first;
      final repeat = attempts.attemptsForCurrentUser.last;
      expect(audioStore.statusOf(first.id), isA<AudioRetentionStored>());
      expect(audioStore.statusOf(repeat.id), isNull);
    });
  });

  group('TrainingLoopController.submit — exit before completing the loop', () {
    test('preserves the first attempt and never fabricates a repeat or '
        'comparison', () async {
      await controller().submit(_audio());

      expect(state().loop.phase, LoopPhase.feedback);
      expect(attempts.attemptsForCurrentUser, hasLength(1));
      expect(state().comparison, isNull);
    });
  });

  group('TrainingLoopController.submit — accessRequired mid-session', () {
    test('keeps the prior step visible/persisted and returns '
        'MicAccessRequired without a retry loop', () async {
      await controller().submit(_audio());
      expect(attempts.attemptsForCurrentUser, hasLength(1));

      speech.nextFailure = const SpeechAnalysisFailure(
        SpeechAnalysisErrorCode.accessRequired,
      );
      final delivery = await controller().submit(_audio());

      expect(delivery, isA<MicAccessRequired>());
      expect(state().loop.phase, LoopPhase.accessRequired);
      expect(state().feedback, isNotNull);
      expect(attempts.attemptsForCurrentUser, hasLength(1));
    });

    test(
      'reproduces a trial expiring mid-session across two submit calls',
      () async {
        final firstDelivery = await controller().submit(_audio());
        expect(firstDelivery, isA<MicAccepted>());

        speech.nextFailure = const SpeechAnalysisFailure(
          SpeechAnalysisErrorCode.accessRequired,
        );
        final secondDelivery = await controller().submit(_audio());

        expect(secondDelivery, isA<MicAccessRequired>());
        expect(attempts.attemptsForCurrentUser, hasLength(1));
      },
    );
  });

  group('TrainingLoopController.submit — dailyLimitReached', () {
    test(
      'returns MicDailyLimitReached without persisting a new attempt',
      () async {
        speech.nextFailure = const SpeechAnalysisFailure(
          SpeechAnalysisErrorCode.dailyLimitReached,
        );

        final delivery = await controller().submit(_audio());

        expect(delivery, isA<MicDailyLimitReached>());
        expect(state().loop.phase, LoopPhase.analysisFailed);
        expect(attempts.attemptsForCurrentUser, isEmpty);
      },
    );
  });

  group('TrainingLoopController.resubmit', () {
    test(
      'resubmits the last delivered audio without a fresh recording',
      () async {
        speech.nextFailure = const SpeechAnalysisFailure(
          SpeechAnalysisErrorCode.unknown,
        );
        await controller().submit(_audio());
        expect(state().loop.phase, LoopPhase.analysisFailed);

        final delivery = await controller().resubmit();

        expect(delivery, isA<MicAccepted>());
        expect(attempts.attemptsForCurrentUser, hasLength(1));
      },
    );

    test('fails cleanly when nothing has ever been submitted', () async {
      final delivery = await controller().resubmit();

      expect(delivery, isA<MicDeliveryFailed>());
      expect(attempts.attemptsForCurrentUser, isEmpty);
    });
  });

  group('TrainingLoopController.submit — wordUse has no transfer step '
      '(orchestrator review finding: a finished loop must refuse before '
      'any paid analysis, never throw)', () {
    test("submitting again after comparison (wordUse's own terminal phase, "
        'it has no summary) makes zero analyze calls and returns a '
        'MicDeliveryFailed instead of throwing', () async {
      final counting = _CountingSpeechAnalysisRepository(speech);
      final localContainer = ProviderContainer(
        overrides: [
          speechAnalysisRepositoryProvider.overrideWithValue(counting),
          speakingAttemptRepositoryProvider.overrideWithValue(attempts),
          attemptAudioStoreProvider.overrideWithValue(audioStore),
          audioConsentRepositoryProvider.overrideWithValue(consent),
          challengeRepositoryProvider.overrideWithValue(
            FakeChallengeRepository(challenges: const [_challenge]),
          ),
          clockProvider.overrideWithValue(FixedClock(DateTime(2026, 9, 28))),
        ],
      );
      addTearDown(localContainer.dispose);
      final notifier = localContainer.read(
        trainingLoopControllerProvider(_wordUseRequest).notifier,
      );

      await notifier.submit(_audio()); // -> feedback (first)
      await notifier.submit(_audio()); // -> comparison (repeat, finished)
      expect(
        localContainer
            .read(trainingLoopControllerProvider(_wordUseRequest))
            .loop
            .phase,
        LoopPhase.comparison,
      );
      expect(counting.analyzeCallCount, 2);
      final savedBefore = attempts.attemptsForCurrentUser.length;

      final delivery = await notifier.submit(_audio());

      expect(delivery, isA<MicDeliveryFailed>());
      // Not a StateError, not a crash — a plain, non-throwing refusal.
      expect(counting.analyzeCallCount, 2); // unchanged: no 3rd call
      expect(attempts.attemptsForCurrentUser.length, savedBefore);
      expect(
        localContainer
            .read(trainingLoopControllerProvider(_wordUseRequest))
            .loop
            .phase,
        LoopPhase.comparison,
      );
    });

    test(
      'calling continueToNextStep() directly (the "Continuar" button path, '
      'orchestrator review finding on 4e58ac7) leaves the finished state '
      'unchanged, keeps offering "Practicar otra vez", and a mic press '
      'after that still makes zero analyze calls and saves zero attempts',
      () async {
        final counting = _CountingSpeechAnalysisRepository(speech);
        final localContainer = ProviderContainer(
          overrides: [
            speechAnalysisRepositoryProvider.overrideWithValue(counting),
            speakingAttemptRepositoryProvider.overrideWithValue(attempts),
            attemptAudioStoreProvider.overrideWithValue(audioStore),
            audioConsentRepositoryProvider.overrideWithValue(consent),
            challengeRepositoryProvider.overrideWithValue(
              FakeChallengeRepository(challenges: const [_challenge]),
            ),
            clockProvider.overrideWithValue(FixedClock(DateTime(2026, 9, 28))),
          ],
        );
        addTearDown(localContainer.dispose);
        final notifier = localContainer.read(
          trainingLoopControllerProvider(_wordUseRequest).notifier,
        );

        await notifier.submit(_audio()); // -> feedback (first)
        await notifier.submit(_audio()); // -> comparison (repeat, finished)
        expect(
          localContainer
              .read(trainingLoopControllerProvider(_wordUseRequest))
              .loop
              .phase,
          LoopPhase.comparison,
        );
        final savedBefore = attempts.attemptsForCurrentUser.length;

        notifier.continueToNextStep();

        expect(
          localContainer
              .read(trainingLoopControllerProvider(_wordUseRequest))
              .loop
              .phase,
          LoopPhase.comparison,
        );
        expect(
          localContainer
              .read(trainingLoopControllerProvider(_wordUseRequest))
              .loop
              .attemptStep,
          AttemptKind.repeat,
        );
        final mic = localContainer.read(loopMicTargetProvider(_wordUseRequest));
        expect(mic.prompt.actionLabel, 'Práctica en voz alta');
        expect(mic.availability, isA<MicPassThrough>());

        final delivery = await notifier.submit(_audio());

        expect(delivery, isA<MicDeliveryFailed>());
        expect(counting.analyzeCallCount, 2); // unchanged: no 3rd call
        expect(attempts.attemptsForCurrentUser.length, savedBefore);
      },
    );
  });

  group('TrainingLoopController — never continues with an unsaved attempt '
      '(orchestrator review fix on 151d0a6)', () {
    test('an insert failure that succeeds on the automatic retry saves the '
        'attempt and fires the milestone upload', () async {
      final flaky = _FlakyAttemptRepository(failNextCalls: 1);
      final countingAudioStore = _CountingAttemptAudioStore(
        FakeAttemptAudioStore(currentUserId: () => 'u1'),
      );
      final localContainer = ProviderContainer(
        overrides: [
          speechAnalysisRepositoryProvider.overrideWithValue(speech),
          speakingAttemptRepositoryProvider.overrideWithValue(flaky),
          attemptAudioStoreProvider.overrideWithValue(countingAudioStore),
          audioConsentRepositoryProvider.overrideWithValue(consent),
          challengeRepositoryProvider.overrideWithValue(
            FakeChallengeRepository(challenges: const [_challenge]),
          ),
          clockProvider.overrideWithValue(FixedClock(DateTime(2026, 9, 28))),
        ],
      );
      addTearDown(localContainer.dispose);
      final localController = localContainer.read(
        trainingLoopControllerProvider(_request).notifier,
      );

      final delivery = await localController.submit(_audio());

      expect(delivery, isA<MicAccepted>());
      expect(flaky.callCount, 2); // first attempt + the automatic retry
      expect(flaky.inserted, hasLength(1));
      expect(
        localContainer
            .read(trainingLoopControllerProvider(_request))
            .loop
            .phase,
        LoopPhase.feedback,
      );
      await pumpEventQueue();
      expect(countingAudioStore.uploadCallCount, 1);
    });

    test('an insert failing twice moves to a retryable not-saved state, '
        'never uploads, and never re-analyzes', () async {
      final flaky = _FlakyAttemptRepository(failNextCalls: 999);
      final countingSpeech = _CountingSpeechAnalysisRepository(
        FakeSpeechAnalysisRepository(latency: Duration.zero),
      );
      final countingAudioStore = _CountingAttemptAudioStore(
        FakeAttemptAudioStore(currentUserId: () => 'u1'),
      );
      final localContainer = ProviderContainer(
        overrides: [
          speechAnalysisRepositoryProvider.overrideWithValue(countingSpeech),
          speakingAttemptRepositoryProvider.overrideWithValue(flaky),
          attemptAudioStoreProvider.overrideWithValue(countingAudioStore),
          audioConsentRepositoryProvider.overrideWithValue(consent),
          challengeRepositoryProvider.overrideWithValue(
            FakeChallengeRepository(challenges: const [_challenge]),
          ),
          clockProvider.overrideWithValue(FixedClock(DateTime(2026, 9, 28))),
        ],
      );
      addTearDown(localContainer.dispose);
      final localController = localContainer.read(
        trainingLoopControllerProvider(_request).notifier,
      );

      final delivery = await localController.submit(_audio());

      expect(delivery, isA<MicDeliveryFailed>());
      expect(flaky.callCount, 2); // first attempt + one automatic retry only
      expect(flaky.inserted, isEmpty);
      expect(countingSpeech.analyzeCallCount, 1); // never re-analyzed
      expect(countingAudioStore.uploadCallCount, 0); // never uploaded
      final loop = localContainer
          .read(trainingLoopControllerProvider(_request))
          .loop;
      expect(loop.phase, LoopPhase.analysisFailed);
      expect(loop.failureCode, notSavedFailureCode);
    });

    test('retrySave saves the pending attempt and continues the normal '
        'flow (upload, feedback, loop advance)', () async {
      final flaky = _FlakyAttemptRepository(failNextCalls: 999);
      final countingAudioStore = _CountingAttemptAudioStore(
        FakeAttemptAudioStore(currentUserId: () => 'u1'),
      );
      final localContainer = ProviderContainer(
        overrides: [
          speechAnalysisRepositoryProvider.overrideWithValue(speech),
          speakingAttemptRepositoryProvider.overrideWithValue(flaky),
          attemptAudioStoreProvider.overrideWithValue(countingAudioStore),
          audioConsentRepositoryProvider.overrideWithValue(consent),
          challengeRepositoryProvider.overrideWithValue(
            FakeChallengeRepository(challenges: const [_challenge]),
          ),
          clockProvider.overrideWithValue(FixedClock(DateTime(2026, 9, 28))),
        ],
      );
      addTearDown(localContainer.dispose);
      final localController = localContainer.read(
        trainingLoopControllerProvider(_request).notifier,
      );
      await localController.submit(_audio());
      expect(
        localContainer
            .read(trainingLoopControllerProvider(_request))
            .loop
            .failureCode,
        notSavedFailureCode,
      );

      flaky.failNextCalls = 0;
      final delivery = await localController.retrySave();

      expect(delivery, isA<MicAccepted>());
      expect(flaky.inserted, hasLength(1));
      final state = localContainer.read(
        trainingLoopControllerProvider(_request),
      );
      expect(state.loop.phase, LoopPhase.feedback);
      expect(state.feedback, isNotNull);
      await pumpEventQueue();
      expect(countingAudioStore.uploadCallCount, 1);
    });

    test(
      'a new submit is rejected while an attempt is still pending save',
      () async {
        final flaky = _FlakyAttemptRepository(failNextCalls: 999);
        final localContainer = ProviderContainer(
          overrides: [
            speechAnalysisRepositoryProvider.overrideWithValue(speech),
            speakingAttemptRepositoryProvider.overrideWithValue(flaky),
            attemptAudioStoreProvider.overrideWithValue(audioStore),
            audioConsentRepositoryProvider.overrideWithValue(consent),
            challengeRepositoryProvider.overrideWithValue(
              FakeChallengeRepository(challenges: const [_challenge]),
            ),
            clockProvider.overrideWithValue(FixedClock(DateTime(2026, 9, 28))),
          ],
        );
        addTearDown(localContainer.dispose);
        final localController = localContainer.read(
          trainingLoopControllerProvider(_request).notifier,
        );
        await localController.submit(_audio());

        final second = await localController.submit(_audio());

        expect(second, isA<MicDeliveryFailed>());
        expect(flaky.callCount, 2); // no new insert attempt from the 2nd call
      },
    );

    test('diagnosis does not advance to the next slot while the current '
        'attempt is unsaved', () async {
      final flaky = _FlakyAttemptRepository(failNextCalls: 999);
      final localContainer = ProviderContainer(
        overrides: [
          speechAnalysisRepositoryProvider.overrideWithValue(speech),
          speakingAttemptRepositoryProvider.overrideWithValue(flaky),
          attemptAudioStoreProvider.overrideWithValue(audioStore),
          audioConsentRepositoryProvider.overrideWithValue(consent),
          challengeRepositoryProvider.overrideWithValue(
            FakeChallengeRepository(challenges: const [_challenge]),
          ),
          clockProvider.overrideWithValue(FixedClock(DateTime(2026, 9, 28))),
        ],
      );
      addTearDown(localContainer.dispose);
      final localController = localContainer.read(
        trainingLoopControllerProvider(_diagnosisRequest).notifier,
      );

      await localController.submit(_audio());

      final blocked = localContainer.read(
        trainingLoopControllerProvider(_diagnosisRequest),
      );
      expect(blocked.loop.phase, LoopPhase.analysisFailed);
      expect(blocked.loop.slot, 1);
      expect(flaky.inserted, isEmpty);

      flaky.failNextCalls = 0;
      final delivery = await localController.retrySave();

      expect(delivery, isA<MicAccepted>());
      final advanced = localContainer.read(
        trainingLoopControllerProvider(_diagnosisRequest),
      );
      expect(advanced.loop.slot, 2);
    });
  });

  group('TrainingLoopController.submit — spoken-use -> mastery (U15b, '
      'design D15)', () {
    // "organizar"/"claridad" are chosen because `FakeSpeechAnalysisRepository`'s
    // fixed first-attempt transcript ("...decisión importante... organizar
    // mejor mi mañana para trabajar con más claridad.") actually contains
    // "organizar" but never "trayectoria".
    final usedWord = buildWord(id: 'w-organizar', lemma: 'organizar');
    final unusedWord = buildWord(id: 'w-trayectoria', lemma: 'trayectoria');
    const ana = AppUser(id: 'u1', email: 'ana@correo.com');
    final wovenRequest = LoopRequest(
      context: TrainingContext.daily,
      sessionId: 's1',
      script: const LoopScript.full(),
      challengeId: 'c1',
      targetWordIds: [usedWord.id, unusedWord.id],
    );

    ProviderContainer buildWiredContainer({
      SpeakingAttemptRepository? attemptRepository,
    }) {
      final built = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(initialUser: ana),
          ),
          speechAnalysisRepositoryProvider.overrideWithValue(speech),
          speakingAttemptRepositoryProvider.overrideWithValue(
            attemptRepository ?? attempts,
          ),
          attemptAudioStoreProvider.overrideWithValue(audioStore),
          audioConsentRepositoryProvider.overrideWithValue(consent),
          challengeRepositoryProvider.overrideWithValue(
            FakeChallengeRepository(challenges: const [_challenge]),
          ),
          contentRepositoryProvider.overrideWithValue(
            FakeContentRepository(words: [usedWord, unusedWord]),
          ),
          wordProgressRepositoryProvider.overrideWithValue(
            FakeWordProgressRepository(currentUserId: () => 'u1'),
          ),
          dailySessionRepositoryProvider.overrideWithValue(
            FakeDailySessionRepository(currentUserId: () => 'u1'),
          ),
          exerciseAttemptRepositoryProvider.overrideWithValue(
            FakeExerciseAttemptRepository(currentUserId: () => 'u1'),
          ),
          streakRepairRepositoryProvider.overrideWithValue(
            FakeStreakRepairRepository(currentUserId: () => 'u1'),
          ),
          clockProvider.overrideWithValue(FixedClock(DateTime(2026, 9, 28))),
        ],
      );
      addTearDown(built.dispose);
      return built;
    }

    Future<void> seedDueProgress(ProviderContainer container) async {
      final wordProgress = container.read(
        wordProgressRepositoryProvider,
      ) as FakeWordProgressRepository;
      await wordProgress.saveProgress(
        buildProgress(wordId: usedWord.id, nextDueOn: day(28)),
      );
      await wordProgress.saveProgress(
        buildProgress(wordId: unusedWord.id, nextDueOn: day(28)),
      );
    }

    test(
      'detected word advances mastery; the other target word is untouched',
      () async {
        final container = buildWiredContainer();
        await seedDueProgress(container);

        final delivery = await container
            .read(trainingLoopControllerProvider(wovenRequest).notifier)
            .submit(_audio());

        expect(delivery, isA<MicAccepted>());
        final saved = attempts.attemptsForCurrentUser.single;
        expect(saved.targetWordIds, [usedWord.id, unusedWord.id]);
        expect(saved.wordsUsed, [usedWord.id]);

        final progress =
            (await container
                    .read(wordProgressRepositoryProvider)
                    .fetchProgress())
                .valueOrNull!;
        final usedAfter = progress.firstWhere(
          (row) => row.wordId == usedWord.id,
        );
        final unusedAfter = progress.firstWhere(
          (row) => row.wordId == unusedWord.id,
        );
        expect(usedAfter.ladderStep, 1);
        expect(usedAfter.productionDone, isTrue);
        expect(usedAfter.nextDueOn, isNot(day(28)));
        // Unused word: byte-identical to the seeded row.
        expect(unusedAfter.ladderStep, 0);
        expect(unusedAfter.productionDone, isFalse);
        expect(unusedAfter.nextDueOn, day(28));
      },
    );

    test('no target words -> never touches word_progress at all', () async {
      final container = buildWiredContainer();
      await seedDueProgress(container);
      const plainRequest = LoopRequest(
        context: TrainingContext.daily,
        sessionId: 's1',
        script: LoopScript.full(),
        challengeId: 'c1',
      );

      await container
          .read(trainingLoopControllerProvider(plainRequest).notifier)
          .submit(_audio());

      final progress =
          (await container.read(wordProgressRepositoryProvider).fetchProgress())
              .valueOrNull!;
      expect(
        progress.firstWhere((row) => row.wordId == usedWord.id).ladderStep,
        0,
      );
    });

    test('an unsaved attempt never records mastery', () async {
      final flaky = _FlakyAttemptRepository(failNextCalls: 999);
      final container = buildWiredContainer(attemptRepository: flaky);
      await seedDueProgress(container);

      final delivery = await container
          .read(trainingLoopControllerProvider(wovenRequest).notifier)
          .submit(_audio());

      expect(delivery, isA<MicDeliveryFailed>());
      expect(flaky.inserted, isEmpty);
      final progress =
          (await container.read(wordProgressRepositoryProvider).fetchProgress())
              .valueOrNull!;
      expect(
        progress.firstWhere((row) => row.wordId == usedWord.id).ladderStep,
        0,
      );
    });

    test('retrySave records mastery exactly once, never twice', () async {
      final flaky = _FlakyAttemptRepository(failNextCalls: 999);
      final container = buildWiredContainer(attemptRepository: flaky);
      await seedDueProgress(container);
      final controller = container.read(
        trainingLoopControllerProvider(wovenRequest).notifier,
      );
      await controller.submit(_audio());
      flaky.failNextCalls = 0;

      final delivery = await controller.retrySave();

      expect(delivery, isA<MicAccepted>());
      expect(flaky.inserted, hasLength(1));
      final progress =
          (await container.read(wordProgressRepositoryProvider).fetchProgress())
              .valueOrNull!;
      final usedAfter = progress.firstWhere((row) => row.wordId == usedWord.id);
      // A single ladder advance (step 1) — never double-counted by the
      // failed automatic retry AND the manual retrySave.
      expect(usedAfter.ladderStep, 1);
    });
  });

  group('TrainingLoopController — lifetime (leak fix)', () {
    // Models a screen watching the controller: the subscription is what
    // keeps an autoDispose provider alive while the screen is mounted.
    ProviderSubscription<TrainingLoopControllerState> mount(
      LoopRequest request,
    ) => container.listen(trainingLoopControllerProvider(request), (_, _) {});

    test('an untouched loop is released once its screen is left', () async {
      final screen = mount(_request);
      expect(container.exists(trainingLoopControllerProvider(_request)), true);

      screen.close();
      await pumpEventQueue();

      expect(container.exists(trainingLoopControllerProvider(_request)), false);
    });

    test(
      'a finished loop (summary) is released on exit, so re-entering the '
      'same session starts clean instead of showing the stale summary',
      () async {
        var screen = mount(_request);
        final notifier = container.read(
          trainingLoopControllerProvider(_request).notifier,
        );
        await notifier.submit(_audio()); // first -> feedback
        await notifier.submit(_audio()); // repeat -> comparison
        await notifier.submit(_audio()); // transfer -> summary
        expect(screen.read().loop.phase, LoopPhase.summary);
        expect(screen.read().comparison, isNotNull);

        screen.close();
        await pumpEventQueue();
        expect(
          container.exists(trainingLoopControllerProvider(_request)),
          false,
        );

        screen = mount(_request);
        expect(screen.read().loop.phase, LoopPhase.focus);
        expect(screen.read().feedback, isNull);
        expect(screen.read().comparison, isNull);
      },
    );

    test('a finished wordUse loop (no summary) stays pinned until its '
        'owner calls release()', () async {
      final screen = mount(_wordUseRequest);
      final notifier = container.read(
        trainingLoopControllerProvider(_wordUseRequest).notifier,
      );
      await notifier.submit(_audio());
      await notifier.submit(_audio());
      screen.close();
      await pumpEventQueue();
      expect(
        container.exists(trainingLoopControllerProvider(_wordUseRequest)),
        true,
      );

      notifier.release();
      await pumpEventQueue();

      expect(
        container.exists(trainingLoopControllerProvider(_wordUseRequest)),
        false,
      );
    });

    test('a loop left mid-flow stays alive so the user resumes where they '
        'stopped', () async {
      var screen = mount(_request);
      await container
          .read(trainingLoopControllerProvider(_request).notifier)
          .submit(_audio());
      expect(screen.read().loop.phase, LoopPhase.feedback);

      screen.close();
      await pumpEventQueue();

      expect(container.exists(trainingLoopControllerProvider(_request)), true);
      screen = mount(_request);
      expect(screen.read().loop.phase, LoopPhase.feedback);
      expect(screen.read().feedback, isNotNull);
    });
  });
}
