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
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/challenge.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:flui/features/training/domain/training_loop.dart';
import 'package:flui/features/training/presentation/controllers/loop_mic_target.dart';
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

const _wordUseRequest = LoopRequest(
  context: TrainingContext.word,
  sessionId: 's-word',
  script: LoopScript.wordUse(),
);

RecordedAudio _audio() => RecordedAudio(
  bytes: Uint8List.fromList(List<int>.filled(10, 1)),
  mimeType: 'audio/wav',
  duration: const Duration(seconds: 12),
  levelsDbfs: const [-30, -28],
);

void main() {
  late ProviderContainer container;
  late FakeSpeechAnalysisRepository speech;

  setUp(() async {
    speech = FakeSpeechAnalysisRepository(latency: Duration.zero);
    final consent = FakeAudioConsentRepository(currentUserId: () => 'u1');
    await consent.write(granted: true);

    container = ProviderContainer(
      overrides: [
        speechAnalysisRepositoryProvider.overrideWithValue(speech),
        speakingAttemptRepositoryProvider.overrideWithValue(
          FakeSpeakingAttemptRepository(currentUserId: () => 'u1'),
        ),
        attemptAudioStoreProvider.overrideWithValue(
          FakeAttemptAudioStore(currentUserId: () => 'u1'),
        ),
        audioConsentRepositoryProvider.overrideWithValue(consent),
        challengeRepositoryProvider.overrideWithValue(
          FakeChallengeRepository(challenges: const [_challenge]),
        ),
        clockProvider.overrideWithValue(FixedClock(DateTime(2026, 9, 28))),
      ],
    );
    addTearDown(container.dispose);
  });

  LoopMicTarget target() => container.read(loopMicTargetProvider(_request));

  test('focus/feedback/comparison all resolve ready', () async {
    expect(target().availability, isA<MicReady>());

    await container
        .read(trainingLoopControllerProvider(_request).notifier)
        .submit(_audio());
    expect(target().availability, isA<MicReady>()); // now feedback

    await container
        .read(trainingLoopControllerProvider(_request).notifier)
        .submit(_audio());
    expect(target().availability, isA<MicReady>()); // now comparison
  });

  test(
    'recording/analyzing resolves busy while an analysis is in flight',
    () async {
      final consent = FakeAudioConsentRepository(currentUserId: () => 'u1');
      await consent.write(granted: true);
      final delayed = ProviderContainer(
        overrides: [
          speechAnalysisRepositoryProvider.overrideWithValue(
            FakeSpeechAnalysisRepository(
              latency: const Duration(milliseconds: 50),
            ),
          ),
          speakingAttemptRepositoryProvider.overrideWithValue(
            FakeSpeakingAttemptRepository(currentUserId: () => 'u1'),
          ),
          attemptAudioStoreProvider.overrideWithValue(
            FakeAttemptAudioStore(currentUserId: () => 'u1'),
          ),
          audioConsentRepositoryProvider.overrideWithValue(consent),
          challengeRepositoryProvider.overrideWithValue(
            FakeChallengeRepository(challenges: const [_challenge]),
          ),
          clockProvider.overrideWithValue(FixedClock(DateTime(2026, 9, 28))),
        ],
      );
      addTearDown(delayed.dispose);

      final pending = delayed
          .read(trainingLoopControllerProvider(_request).notifier)
          .submit(_audio());

      expect(
        delayed.read(loopMicTargetProvider(_request)).availability,
        isA<MicBusy>(),
      );
      await pending;
    },
  );

  test('accessRequired resolves blocked with the Reactivar CTA', () async {
    speech.nextFailure = const SpeechAnalysisFailure(
      SpeechAnalysisErrorCode.accessRequired,
    );

    await container
        .read(trainingLoopControllerProvider(_request).notifier)
        .submit(_audio());

    final availability = target().availability;
    expect(availability, isA<MicBlocked>());
    expect((availability as MicBlocked).cta?.label, 'Reactivar');
  });

  test('a dailyLimitReached analysisFailed resolves blocked', () async {
    speech.nextFailure = const SpeechAnalysisFailure(
      SpeechAnalysisErrorCode.dailyLimitReached,
    );

    await container
        .read(trainingLoopControllerProvider(_request).notifier)
        .submit(_audio());

    expect(target().availability, isA<MicBlocked>());
  });

  test('any other analysisFailed stays ready for a re-record', () async {
    speech.nextFailure = const SpeechAnalysisFailure(
      SpeechAnalysisErrorCode.rateLimited,
    );

    await container
        .read(trainingLoopControllerProvider(_request).notifier)
        .submit(_audio());

    expect(target().availability, isA<MicReady>());
  });

  test("deliver forwards straight to the controller's submit", () async {
    final delivery = await target().deliver(_audio());

    expect(delivery, isA<MicAccepted>());
  });

  test('changes fires whenever the wrapped controller state changes', () async {
    var fired = 0;
    final target0 = target();
    final subscription = target0.changes.listen((_) => fired++);

    await container
        .read(trainingLoopControllerProvider(_request).notifier)
        .submit(_audio());
    await pumpEventQueue();

    expect(fired, greaterThan(0));
    await subscription.cancel();
  });

  group('a finished wordUse loop (comparison — wordUse has no summary '
      'phase, orchestrator review finding)', () {
    LoopMicTarget wordTarget() =>
        container.read(loopMicTargetProvider(_wordUseRequest));

    test("resolves MicPassThrough, never MicReady with the full script's own "
        '"Grabar tu transferencia" label — recording there has no valid '
        'next step', () async {
      final notifier = container.read(
        trainingLoopControllerProvider(_wordUseRequest).notifier,
      );
      await notifier.submit(_audio()); // -> feedback
      await notifier.submit(_audio()); // -> comparison (finished)
      expect(
        container
            .read(trainingLoopControllerProvider(_wordUseRequest))
            .loop
            .phase,
        LoopPhase.comparison,
      );

      expect(wordTarget().availability, isA<MicPassThrough>());
      expect(wordTarget().prompt.actionLabel, isNot('Grabar tu transferencia'));
    });

    test('a full-script comparison (NOT wordUse) is completely unaffected — '
        'still MicReady with its own transfer-step label', () async {
      final notifier = container.read(
        trainingLoopControllerProvider(_request).notifier,
      );
      await notifier.submit(_audio()); // -> feedback
      await notifier.submit(_audio()); // -> comparison
      expect(
        container.read(trainingLoopControllerProvider(_request)).loop.phase,
        LoopPhase.comparison,
      );

      expect(target().availability, isA<MicReady>());
      expect(target().prompt.actionLabel, 'Grabar tu transferencia');
    });
  });
}
