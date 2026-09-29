import 'dart:typed_data';

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/features/auth/data/fake_auth_repository.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
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
import 'package:flui/features/vocabulary/data/fake_content_repository.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/features/vocabulary/presentation/providers/vocabulary_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/learning_builders.dart';

// The woven words are chosen so `FakeSpeechAnalysisRepository`'s fixed
// transcript text naturally contains them — this file only exercises the
// mic prompt's hint (U15b.1/.2), not spoken-use detection itself (covered
// separately by spoken_use_mastery_test.dart / training_loop_controller_test.dart).
final Word _wordA = buildWord(id: 'w-a', lemma: 'organizar');
final Word _wordB = buildWord(id: 'w-b', lemma: 'claridad');

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

RecordedAudio _audio() => RecordedAudio(
  bytes: Uint8List.fromList(List<int>.filled(10, 1)),
  mimeType: 'audio/wav',
  duration: const Duration(seconds: 12),
  levelsDbfs: const [-30, -28],
);

ProviderContainer _buildContainer() {
  final consent = FakeAudioConsentRepository(currentUserId: () => 'u1');
  final built = ProviderContainer(
    overrides: [
      // Signed out (no user): `TrainingLoopController._recordSpokenUse`
      // then bails out on a null `authUserProvider` before ever touching
      // `learningDataControllerProvider` — this file only exercises the
      // mic prompt's hint, mastery persistence is covered separately.
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
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
        FakeChallengeRepository(challenges: const [_challenge]),
      ),
      contentRepositoryProvider.overrideWithValue(
        FakeContentRepository(words: [_wordA, _wordB]),
      ),
      clockProvider.overrideWithValue(FixedClock(DateTime(2026, 9, 28))),
    ],
  );
  addTearDown(built.dispose);
  return built;
}

LoopRequest _requestWith(List<String> targetWordIds) => LoopRequest(
  context: TrainingContext.daily,
  sessionId: 's1',
  script: const LoopScript.full(),
  challengeId: 'c1',
  targetWordIds: targetWordIds,
);

Future<void> _completeFirstAndRepeat(
  ProviderContainer container,
  LoopRequest request,
) async {
  final controller = container.read(
    trainingLoopControllerProvider(request).notifier,
  );
  await controller.submit(_audio());
  await controller.submit(_audio());
}

void main() {
  test("1-3 due words are woven into the transfer step's hint", () async {
    final container = _buildContainer();
    final request = _requestWith(const ['w-a', 'w-b']);
    // Loads the catalog synchronously into `wordsByIdProvider`'s cache
    // before the loop reaches `comparison`, exactly like the real
    // `/today/train` page (whose `PlanToday.run` already awaited it).
    await container.read(catalogProvider.future);

    await _completeFirstAndRepeat(container, request);
    final target = container.read(loopMicTargetProvider(request));

    expect(
      container.read(trainingLoopControllerProvider(request)).loop.phase,
      LoopPhase.comparison,
    );
    expect(target.prompt.hint, contains('organizar'));
    expect(target.prompt.hint, contains('claridad'));
  });

  test(
    'no due words -> the loop runs unaffected, generic hint stays',
    () async {
      final container = _buildContainer();
      final request = _requestWith(const []);

      await _completeFirstAndRepeat(container, request);
      final target = container.read(loopMicTargetProvider(request));

      expect(target.prompt.hint, 'Aplica lo que acabas de practicar.');
    },
  );

  test(
    'a single woven word is quoted alone, no dangling conjunction',
    () async {
      final container = _buildContainer();
      final request = _requestWith(const ['w-a']);
      await container.read(catalogProvider.future);

      await _completeFirstAndRepeat(container, request);
      final target = container.read(loopMicTargetProvider(request));

      expect(target.prompt.hint, contains('«organizar»'));
      expect(target.prompt.hint, isNot(contains(' y ')));
    },
  );

  test('a not-yet-loaded catalog never crashes the prompt — hint stays generic '
      'until it arrives', () async {
    final container = _buildContainer();
    final request = _requestWith(const ['w-a', 'w-b']);
    // Deliberately never awaits `catalogProvider` before reaching
    // comparison — `wordsByIdProvider` may still be loading.

    await _completeFirstAndRepeat(container, request);
    final target = container.read(loopMicTargetProvider(request));

    expect(target.prompt.hint, isNotNull);
  });
}
