import 'dart:typed_data';

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/core/mic/mic_target.dart';
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
import 'package:flui/features/training/presentation/controllers/training_loop_controller.dart';
import 'package:flui/features/training/presentation/providers/training_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
