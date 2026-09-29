import 'dart:async';
import 'dart:typed_data';

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/audio/speech_recorder.dart';
import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/mic/mic_controller.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/core/mic/mic_target_registry.dart';
import 'package:flui/core/mic/presentation/mic_button.dart';
import 'package:flui/features/vocabulary/presentation/widgets/spoken_answer_controls.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/pump_app.dart';

final class _FakeMicTarget implements MicTarget {
  new();

  @override
  final MicPrompt prompt = const MicPrompt(actionLabel: 'Decir la palabra');

  @override
  final Duration maxDuration = const Duration(seconds: 10);

  @override
  MicAvailability get availability => const MicReady();

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Future<MicDelivery> deliver(RecordedAudio audio) async => const MicAccepted();
}

final class _FakeSpeechRecorder implements SpeechRecorder {
  new();

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
  MicController build({bool accessGranted = true}) {
    final registry = MicTargetRegistry()
      ..register(_FakeMicTarget(), layer: MicLayer.root);
    return MicController(
      recorderFactory: _FakeSpeechRecorder.new,
      registry: registry,
      clock: FixedClock(DateTime(2026)),
    )..setAccessGranted(accessGranted);
  }

  testWidgets('shows the shell mic, no heard text and no skip when idle', (
    tester,
  ) async {
    final controller = build();
    addTearDown(() => unawaited(controller.dispose()));
    await tester.pumpFlui(
      SpokenAnswerControls(
        controller: controller,
        heardText: null,
        onSkip: () {},
      ),
    );

    expect(find.byType(MicButton), findsOneWidget);
    expect(find.textContaining('Escuché'), findsNothing);
    expect(find.text('Continuar sin hablar'), findsNothing);
  });

  testWidgets('shows the heard text once one was transcribed', (tester) async {
    final controller = build();
    addTearDown(() => unawaited(controller.dispose()));
    await tester.pumpFlui(
      SpokenAnswerControls(
        controller: controller,
        heardText: 'perspicaz',
        onSkip: () {},
      ),
    );

    expect(find.text('Escuché: «perspicaz»'), findsOneWidget);
  });

  testWidgets('"Continuar sin hablar" appears only while the mic is blocked', (
    tester,
  ) async {
    final controller = build(accessGranted: false);
    addTearDown(() => unawaited(controller.dispose()));
    var skipped = false;
    await tester.pumpFlui(
      SpokenAnswerControls(
        controller: controller,
        heardText: null,
        onSkip: () => skipped = true,
      ),
    );

    expect(find.text('Continuar sin hablar'), findsOneWidget);
    await tester.tap(find.text('Continuar sin hablar'));
    await tester.pump();
    expect(skipped, isTrue);
  });
}
