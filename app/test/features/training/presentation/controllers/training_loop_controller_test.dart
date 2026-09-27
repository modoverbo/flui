import 'dart:typed_data';

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/features/speaking/data/fake_speech_analysis_repository.dart';
import 'package:flui/features/speaking/presentation/providers/speaking_providers.dart';
import 'package:flui/features/training/data/fake_attempt_audio_store.dart';
import 'package:flui/features/training/data/fake_audio_consent_repository.dart';
import 'package:flui/features/training/data/fake_challenge_repository.dart';
import 'package:flui/features/training/data/fake_speaking_attempt_repository.dart';
import 'package:flui/features/training/domain/attempt_kind.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/challenge.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/speaking_attempt.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:flui/features/training/domain/training_loop.dart';
import 'package:flui/features/training/presentation/controllers/training_loop_controller.dart';
import 'package:flui/features/training/presentation/providers/training_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
