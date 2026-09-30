import 'dart:typed_data';

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:flui/features/daily/presentation/controllers/session_controller.dart';
import 'package:flui/features/speaking/data/fake_speech_analysis_repository.dart';
import 'package:flui/features/speaking/presentation/providers/speaking_providers.dart';
import 'package:flui/features/vocabulary/domain/exercises/form_recall_check.dart';
import 'package:flui/features/vocabulary/presentation/controllers/form_recall_mic_target.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/learning_fakes.dart';
import '../../../../helpers/test_container.dart';

RecordedAudio _audio() => RecordedAudio(
  bytes: Uint8List.fromList(const [1, 2, 3]),
  mimeType: 'audio/wav',
  duration: const Duration(seconds: 2),
  levelsDbfs: const [],
);

void main() {
  late LearningFakes fakes;
  late FakeSpeechAnalysisRepository speech;
  late ProviderContainer container;
  final perspicaz = seedWord('perspicaz');
  const mode = SessionMode.daily;

  setUp(() async {
    fakes = LearningFakes();
    speech = FakeSpeechAnalysisRepository(latency: Duration.zero);
    container = createTestContainer(
      overrides: [
        ...fakes.overrides,
        speechAnalysisRepositoryProvider.overrideWithValue(speech),
      ],
    );
    await fakes.sessions.saveSession(
      DailySession(
        localDate: fakes.today,
        minutes: 10,
        plannedWordIds: [perspicaz.id],
      ),
    );
    container.listen(sessionControllerProvider(mode), (_, _) {});
    await container.read(sessionControllerProvider(mode).future);
  });

  tearDown(() => fakes.dispose());

  SessionController controller() =>
      container.read(sessionControllerProvider(mode).notifier);

  Future<void> reachFormRecall() async {
    final c = controller();
    await c.continueStep();
    await c.continueStep();
    final cloze = container
        .read(sessionControllerProvider(mode))
        .requireValue
        .cloze!;
    await c.answerCloze(cloze.exercise.correctOption.id);
    await c.continueStep();
  }

  test('maxDuration is clamped to 10 seconds (D42)', () {
    final target = container.read(formRecallMicTargetProvider(mode));
    expect(target.maxDuration, const Duration(seconds: 10));
  });

  test('is ready once the form recall step is active', () async {
    await reachFormRecall();
    final target = container.read(formRecallMicTargetProvider(mode));
    expect(target.availability, isA<MicReady>());
  });

  test('is a pass-through before the form recall step is reached', () {
    final target = container.read(formRecallMicTargetProvider(mode));
    expect(target.availability, isA<MicPassThrough>());
  });

  test('deliver transcribes and submits through submitHeard', () async {
    await reachFormRecall();
    final target = container.read(formRecallMicTargetProvider(mode));

    final delivery = await target.deliver(_audio());

    expect(delivery, isA<MicAccepted>());
    // FakeSpeechAnalysisRepository never produces the exact expected word,
    // so this genuinely exercises the mismatch/hint path — proving deliver
    // actually calls through to submitHeard rather than trivially
    // accepting.
    final check = container
        .read(sessionControllerProvider(mode))
        .requireValue
        .formRecall!;
    expect(check.status, FormRecallStatus.pending);
    expect(check.hintsUsed, 1);
  });

  test(
    'becomes a pass-through again once accepted, no further capture',
    () async {
      await reachFormRecall();
      final c = controller();
      speech.nextTranscribeText = 'perspicaz';
      await c.answerFormRecallAloud(_audio());

      final target = container.read(formRecallMicTargetProvider(mode));
      expect(target.availability, isA<MicPassThrough>());
    },
  );

  test('fires changes when the session state updates', () async {
    await reachFormRecall();
    final target = container.read(formRecallMicTargetProvider(mode));
    var fired = 0;
    final sub = target.changes.listen((_) => fired++);
    addTearDown(sub.cancel);

    await controller().takeFormRecallHint();
    await Future<void>.delayed(Duration.zero);

    expect(fired, greaterThan(0));
  });
}
