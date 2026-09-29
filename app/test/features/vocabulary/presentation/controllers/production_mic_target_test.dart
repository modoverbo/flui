import 'dart:typed_data';

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:flui/features/daily/presentation/controllers/session_controller.dart';
import 'package:flui/features/speaking/data/fake_speech_analysis_repository.dart';
import 'package:flui/features/speaking/presentation/providers/speaking_providers.dart';
import 'package:flui/features/vocabulary/domain/exercises/production_check.dart';
import 'package:flui/features/vocabulary/presentation/controllers/production_mic_target.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/learning_fakes.dart';
import '../../../../helpers/test_container.dart';

RecordedAudio _audio() => RecordedAudio(
  bytes: Uint8List.fromList(const [1, 2, 3]),
  mimeType: 'audio/wav',
  duration: const Duration(seconds: 4),
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

  Future<void> reachProduction() async {
    final c = controller();
    await c.continueStep(); // discover -> readings
    await c.continueStep(); // readings -> practiceCloze
    final cloze = container
        .read(sessionControllerProvider(mode))
        .requireValue
        .cloze!;
    await c.answerCloze(cloze.exercise.correctOption.id);
    await c.continueStep(); // -> formRecall
    await c.submitFormRecall('perspicaz');
    await c.continueStep(); // -> readings (scenes held back)
    await c.continueStep(); // -> production
  }

  test('maxDuration is 30 seconds (D42)', () {
    final target = container.read(productionMicTargetProvider(mode));
    expect(target.maxDuration, const Duration(seconds: 30));
  });

  test('is a pass-through before the production step is reached', () {
    final target = container.read(productionMicTargetProvider(mode));
    expect(target.availability, isA<MicPassThrough>());
  });

  test('is ready during the writing phase', () async {
    await reachProduction();
    final target = container.read(productionMicTargetProvider(mode));
    expect(target.availability, isA<MicReady>());
  });

  test('is a pass-through once the self-check phase is reached, no further '
      'capture', () async {
    await reachProduction();
    controller().submitProduction('Tu pregunta fue muy perspicaz, Carla.');
    final target = container.read(productionMicTargetProvider(mode));
    expect(target.availability, isA<MicPassThrough>());
  });

  test('deliver transcribes and submits through ProductionFlow.submit '
      '(real validator, not a trivial accept)', () async {
    await reachProduction();
    final target = container.read(productionMicTargetProvider(mode));
    speech.nextFailure = null;

    final delivery = await target.deliver(_audio());

    expect(delivery, isA<MicAccepted>());
    final production = container
        .read(sessionControllerProvider(mode))
        .requireValue
        .production!;
    // FakeSpeechAnalysisRepository's fixed transcript is a real,
    // well-formed sentence (>=4 distinct words, not the model sentence)
    // that never contains "perspicaz" — the real ProductionFlow
    // validator correctly rejects it as missing the word, proving
    // deliver reaches the actual validator rather than trivially
    // accepting.
    expect(production.phase, ProductionPhase.writing);
    expect(production.issue, ProductionIssue.missingWord);
    expect(production.sentence, isNotEmpty);
  });

  test('fires changes when the session state updates', () async {
    await reachProduction();
    final target = container.read(productionMicTargetProvider(mode));
    var fired = 0;
    final sub = target.changes.listen((_) => fired++);
    addTearDown(sub.cancel);

    controller().submitProduction('demasiado corto');
    await Future<void>.delayed(Duration.zero);

    expect(fired, greaterThan(0));
  });
}
