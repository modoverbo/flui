import 'dart:async';
import 'dart:typed_data';

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/audio/speech_recorder.dart';
import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/mic/mic_controller.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/core/mic/mic_target_registry.dart';
import 'package:flui/core/mic/presentation/mic_button.dart';
import 'package:flui/core/mic/presentation/mic_dock.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

final class _FakeMicTarget implements MicTarget {
  new();

  @override
  final MicPrompt prompt = const MicPrompt(actionLabel: 'Responde en voz alta');

  @override
  final Duration maxDuration = const Duration(seconds: 30);

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

Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  late FixedClock clock;

  MicController build() {
    final registry = MicTargetRegistry()
      ..register(_FakeMicTarget(), layer: MicLayer.root);
    return MicController(
      recorderFactory: _FakeSpeechRecorder.new,
      registry: registry,
      clock: clock,
    )..setAccessGranted(true);
  }

  setUp(() {
    clock = FixedClock(DateTime(2026));
  });

  testWidgets('renders the shell mic button, docked', (tester) async {
    final controller = build();
    addTearDown(() => unawaited(controller.dispose()));
    await tester.pumpFlui(MicDock(controller: controller));

    expect(find.byType(MicButton), findsOneWidget);
  });

  testWidgets("shows the resolved target's prompt while idle", (tester) async {
    final controller = build();
    addTearDown(() => unawaited(controller.dispose()));
    await tester.pumpFlui(MicDock(controller: controller));

    expect(find.text('Responde en voz alta'), findsOneWidget);
  });

  testWidgets('shows the countdown while recording', (tester) async {
    final controller = build();
    addTearDown(() => unawaited(controller.dispose()));
    await tester.pumpFlui(MicDock(controller: controller));

    controller.toggle();
    await _flush(tester);

    expect(find.textContaining('30'), findsOneWidget);

    controller.cancelActiveCapture();
    await _flush(tester);
  });

  testWidgets(
    'shows the latched block message and its CTA label instead of the '
    'passive prompt',
    (tester) async {
      final controller = build()..setAccessGranted(false);
      addTearDown(() => unawaited(controller.dispose()));
      await tester.pumpFlui(MicDock(controller: controller));

      expect(
        find.text('Reactiva tu acceso para seguir practicando.'),
        findsOneWidget,
      );
      expect(find.text('Reactivar'), findsOneWidget);
      expect(find.text('Responde en voz alta'), findsNothing);
    },
  );
}
