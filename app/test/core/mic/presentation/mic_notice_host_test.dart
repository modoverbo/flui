import 'dart:async';
import 'dart:typed_data';

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/audio/speech_recorder.dart';
import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/mic/mic_controller.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/core/mic/mic_target_registry.dart';
import 'package:flui/core/mic/presentation/mic_notice_host.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../helpers/pump_app.dart';

/// Flushes the notice-delivery microtask and the SnackBar's entrance
/// animation, WITHOUT letting its multi-second auto-dismiss timer fire —
/// a full `pumpAndSettle()` would wait that out and the notice would be
/// gone by the time the test asserts on it.
Future<void> _flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
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
  MicController build() => MicController(
    recorderFactory: _FakeSpeechRecorder.new,
    registry: MicTargetRegistry(),
    clock: FixedClock(DateTime(2026)),
  )..setAccessGranted(true);

  testWidgets('with no controller (e.g. the brief instant around sign-out), '
      'renders only the child with no crash', (tester) async {
    await tester.pumpFlui(
      const MicNoticeHost(controller: null, child: Text('hola')),
    );

    expect(find.text('hola'), findsOneWidget);
  });

  for (final (notice, expectedCopy) in [
    (
      MicNotice.cancelledByNavigation,
      'Grabación cancelada: cambiaste de pantalla.',
    ),
    (
      MicNotice.cancelledByBackground,
      'Grabación cancelada: la app pasó a segundo plano.',
    ),
    (
      MicNotice.tooShort,
      'Fue muy corto y no lo enviamos. Mantén pulsado mientras hablas, o '
          'toca una vez para empezar y otra para terminar.',
    ),
  ]) {
    testWidgets('shows the exact D43 copy for $notice', (tester) async {
      final controller = build();
      addTearDown(() => unawaited(controller.dispose()));
      await tester.pumpFlui(
        MicNoticeHost(controller: controller, child: const Text('hola')),
      );

      controller.emitNotice(notice);
      await _flush(tester);

      expect(find.text(expectedCopy), findsOneWidget);
    });
  }

  testWidgets(
    'tooShort and cancelledByNavigation render visibly distinct copy',
    (tester) async {
      final controller = build();
      addTearDown(() => unawaited(controller.dispose()));
      await tester.pumpFlui(
        MicNoticeHost(controller: controller, child: const Text('hola')),
      );

      controller.emitNotice(MicNotice.cancelledByNavigation);
      await _flush(tester);
      expect(
        find.text('Grabación cancelada: cambiaste de pantalla.'),
        findsOneWidget,
      );

      controller.emitNotice(MicNotice.tooShort);
      await _flush(tester);
      expect(
        find.text('Grabación cancelada: cambiaste de pantalla.'),
        findsNothing,
      );
      expect(
        find.textContaining('Fue muy corto y no lo enviamos'),
        findsOneWidget,
      );
    },
  );

  for (final (notice, expectedCopy) in [
    (
      MicNotice.permissionDenied,
      'No pudimos grabar: activa el micrófono en los ajustes y vuelve a '
          'intentarlo.',
    ),
    (
      MicNotice.busy,
      'Ya estamos analizando tu intento anterior. Espera un momento.',
    ),
    (
      MicNotice.deliveryFailed,
      'No pudimos enviar tu grabación. Vuelve a intentarlo.',
    ),
  ]) {
    testWidgets('shows its own distinct copy for $notice', (tester) async {
      final controller = build();
      addTearDown(() => unawaited(controller.dispose()));
      await tester.pumpFlui(
        MicNoticeHost(controller: controller, child: const Text('hola')),
      );

      controller.emitNotice(notice);
      await _flush(tester);

      expect(find.text(expectedCopy), findsOneWidget);
    });
  }
}
