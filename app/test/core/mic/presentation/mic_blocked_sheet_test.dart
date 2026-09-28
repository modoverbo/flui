import 'dart:async';
import 'dart:typed_data';

import 'package:flui/core/audio/speech_recorder.dart';
import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/mic/mic_controller.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/core/mic/mic_target_registry.dart';
import 'package:flui/core/mic/presentation/mic_blocked_sheet.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

final class _FakeSpeechRecorder implements SpeechRecorder {
  new();

  @override
  Stream<double> get amplitude => const Stream.empty();

  @override
  Future<bool> requestPermission() async => false;

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
  MicController build() => MicController(
    recorderFactory: _FakeSpeechRecorder.new,
    registry: MicTargetRegistry(),
    clock: FixedClock(DateTime(2026)),
  );

  testWidgets(
    'the access sheet (a route CTA) shows the message and "Reactivar"',
    (tester) async {
      final controller = build();
      addTearDown(() => unawaited(controller.dispose()));
      const block = MicBlocked(
        'Reactiva tu acceso para seguir practicando.',
        cta: MicBlockedCta(label: 'Reactivar', route: '/paywall'),
      );
      await tester.pumpFlui(
        MicBlockedSheet(block: block, controller: controller),
      );

      expect(
        find.text('Reactiva tu acceso para seguir practicando.'),
        findsOneWidget,
      );
      expect(find.text('Reactivar'), findsOneWidget);
    },
  );

  testWidgets(
    'the quota sheet (no CTA at all) shows only the message, no retry',
    (tester) async {
      final controller = build();
      addTearDown(() => unawaited(controller.dispose()));
      const block = MicBlocked('Ya usaste tus análisis de hoy. Vuelve mañana.');
      await tester.pumpFlui(
        MicBlockedSheet(block: block, controller: controller),
      );

      expect(
        find.text('Ya usaste tus análisis de hoy. Vuelve mañana.'),
        findsOneWidget,
      );
      expect(find.byType(FluiButton), findsNothing);
    },
  );

  testWidgets('the permission sheet (a routeless CTA) shows the message and '
      '"Intentar de nuevo", which calls MicController.retryPermission', (
    tester,
  ) async {
    final controller = build();
    addTearDown(() => unawaited(controller.dispose()));
    const block = MicBlocked(
      'Necesitamos acceso al micrófono. Actívalo en los ajustes y '
      'vuelve a intentarlo.',
      cta: MicBlockedCta(label: 'Intentar de nuevo'),
    );
    await tester.pumpFlui(
      MicBlockedSheet(block: block, controller: controller),
    );

    expect(find.text('Intentar de nuevo'), findsOneWidget);

    await tester.tap(find.text('Intentar de nuevo'));
    await tester.pump();

    // retryPermission re-attempts a capture start — the fake recorder
    // denies, so it settles back to the same permission-denied block.
    expect(controller.state, isA<MicIdle>());
  });
}
