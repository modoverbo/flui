import 'dart:async';
import 'dart:typed_data';

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/audio/speech_recorder.dart';
import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/mic/mic_controller.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/core/mic/mic_target_registry.dart';
import 'package:flui/features/speaking/data/fake_speech_analysis_repository.dart';
import 'package:flui/features/speaking/presentation/providers/speaking_providers.dart';
import 'package:flui/features/training/data/fake_attempt_audio_store.dart';
import 'package:flui/features/training/data/fake_audio_consent_repository.dart';
import 'package:flui/features/training/data/fake_challenge_repository.dart';
import 'package:flui/features/training/data/fake_speaking_attempt_repository.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/challenge.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/presentation/providers/training_providers.dart';
import 'package:flui/features/training/presentation/quick/quick_practice_target.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _challenge1 = Challenge(
  id: 'c1',
  slug: 'organize-morning',
  purpose: ChallengePurpose.training,
  skill: Skill.thinking,
  difficulty: 1,
  prompt: 'Cuenta cómo organizas tu mañana.',
  focus: 'Estructura tu respuesta.',
  focusBehaviors: <BehaviorCode>[],
  transferPrompts: <String>['Aplica esto mañana.'],
  targetDuration: Duration(seconds: 20),
  sortOrder: 1,
);

RecordedAudio _audio() => RecordedAudio(
  bytes: Uint8List.fromList(List<int>.filled(10, 1)),
  mimeType: 'audio/wav',
  duration: const Duration(seconds: 12),
  levelsDbfs: const [-30, -28],
);

final class _FakeSpeechRecorder implements SpeechRecorder {
  @override
  Stream<double> get amplitude => const Stream.empty();

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> start() async {}

  @override
  Future<Uint8List> stop() async => Uint8List.fromList(const [1, 2, 3]);

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  ProviderContainer build({List<Challenge> challenges = const [_challenge1]}) {
    final consent = FakeAudioConsentRepository(currentUserId: () => 'u1');
    unawaited(consent.write(granted: true));
    return ProviderContainer(
      overrides: [
        speechAnalysisRepositoryProvider.overrideWithValue(
          FakeSpeechAnalysisRepository(latency: Duration.zero),
        ),
        speakingAttemptRepositoryProvider.overrideWithValue(
          FakeSpeakingAttemptRepository(currentUserId: () => 'u1'),
        ),
        attemptAudioStoreProvider.overrideWithValue(
          FakeAttemptAudioStore(currentUserId: () => 'u1'),
        ),
        audioConsentRepositoryProvider.overrideWithValue(consent),
        challengeRepositoryProvider.overrideWithValue(
          FakeChallengeRepository(challenges: challenges),
        ),
        clockProvider.overrideWithValue(FixedClock(DateTime(2026, 9, 28))),
      ],
    );
  }

  late ProviderContainer container;

  setUp(() {
    container = build();
    addTearDown(container.dispose);
  });

  test('first activation returns MicPrepare and captures no audio', () {
    final target = container.read(quickPracticeTargetProvider);

    expect(target.availability, isA<MicPrepare>());
  });

  test(
    'onActivate picks a challenge; the next activation is ready to record',
    () async {
      final target = container.read(quickPracticeTargetProvider);
      final prepare = target.availability as MicPrepare;

      await prepare.onActivate();

      expect(target.availability, isA<MicReady>());
      expect(target.currentChallenge?.id, 'c1');
    },
  );

  test(
    'deliver after activation submits through the quick training loop',
    () async {
      final target = container.read(quickPracticeTargetProvider);
      await (target.availability as MicPrepare).onActivate();

      final delivery = await target.deliver(_audio());

      expect(delivery, isA<MicAccepted>());
      // The mic is immediately ready for a FRESH quick practice again.
      expect(target.availability, isA<MicPrepare>());
    },
  );

  test('an empty catalog resolves ready and still submits the attempt (no '
      'challenge attached), never throws', () async {
    final empty = build(challenges: const []);
    addTearDown(empty.dispose);
    final target = empty.read(quickPracticeTargetProvider);
    await (target.availability as MicPrepare).onActivate();

    expect(target.availability, isA<MicReady>());
    expect(target.currentChallenge, isNull);
    final delivery = await target.deliver(_audio());
    expect(delivery, isA<MicAccepted>());
  });

  test('dismiss (navigate-away-between-activations) resets to prompt-first, '
      'closing silently — nothing was ever captured', () async {
    final target = container.read(quickPracticeTargetProvider);
    await (target.availability as MicPrepare).onActivate();
    expect(target.availability, isA<MicReady>());

    target.dismiss();

    expect(target.availability, isA<MicPrepare>());
    expect(target.currentRequest, isNull);
  });

  test('has_access=false blocks before the quick-practice prompt is ever '
      'activated (paywall precedence, design §19.5)', () async {
    final target = container.read(quickPracticeTargetProvider);
    final registry = MicTargetRegistry()..setFallback(target);
    final controller = MicController(
      recorderFactory: _FakeSpeechRecorder.new,
      registry: registry,
      clock: const SystemClock(),
    )..setAccessGranted(false);
    addTearDown(() => unawaited(controller.dispose()));

    controller.pointerDown();
    await Future<void>.delayed(Duration.zero);

    final state = controller.state;
    expect(state, isA<MicIdle>());
    expect((state as MicIdle).block?.cta?.label, 'Reactivar');
    // The paywall latch is checked BEFORE the registry ever resolves:
    // the quick-practice prompt is never shown, so the target stays
    // unprepared/untouched.
    expect(target.availability, isA<MicPrepare>());
  });
}
