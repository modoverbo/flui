import 'dart:async';

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/audio/speech_recorder.dart';
import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/mic/mic_controller.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/core/mic/mic_target_registry.dart';
import 'package:flui/core/mic/presentation/mic_button.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../helpers/pump_app.dart';

/// Ported from `mic_controller_test.dart`'s fakes.
final class _FakeMicTarget implements MicTarget {
  new();

  @override
  final MicPrompt prompt = const MicPrompt(
    actionLabel: 'Practicar en voz alta',
    hint: 'Mantén pulsado para grabar',
  );

  @override
  final Duration maxDuration = const Duration(seconds: 30);

  @override
  MicAvailability get availability => const MicReady();

  final _changesController = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changesController.stream;

  @override
  Future<MicDelivery> deliver(RecordedAudio audio) async => const MicAccepted();
}

final class _FakeSpeechRecorder implements SpeechRecorder {
  new();

  int starts = 0;
  int stops = 0;

  @override
  Stream<double> get amplitude => const Stream.empty();

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> start() async => starts++;

  @override
  Future<Uint8List> stop() async {
    stops++;
    return Uint8List.fromList(const [1, 2, 3]);
  }

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

/// Simulates an assistive-tech "double tap to activate" on the semantics
/// node [id] — the only stable API for this in the current Flutter SDK is
/// through the deprecated `pipelineOwner` accessor; the suggested
/// `rootPipelineOwner` replacement resolves to a different `SemanticsOwner`
/// in this harness and silently no-ops (see engram bug/fakeasync-hang note).
void _performSemanticTap(WidgetTester tester, int id) {
  // `rootPipelineOwner.semanticsOwner` (the suggested replacement) resolves
  // to a different owner in this harness and silently no-ops.
  // ignore: deprecated_member_use
  tester.binding.pipelineOwner.semanticsOwner!.performAction(
    id,
    SemanticsAction.tap,
  );
}

void main() {
  late FixedClock clock;
  late MicController controller;

  MicController build() {
    final registry = MicTargetRegistry()
      ..register(_FakeMicTarget(), layer: MicLayer.branch);
    return MicController(
      recorderFactory: _FakeSpeechRecorder.new,
      registry: registry,
      clock: clock,
    )..setAccessGranted(true);
  }

  setUp(() {
    clock = FixedClock(DateTime(2026));
  });

  testWidgets('a pointer down starts a recording, a pointer up ends it', (
    tester,
  ) async {
    controller = build();
    addTearDown(() => unawaited(controller.dispose()));
    await tester.pumpFlui(MicButton(controller: controller));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(MicButton)),
    );
    await _flush(tester);
    expect(controller.state, isA<MicRecording>());

    clock.advance(const Duration(milliseconds: 700));
    await gesture.up();
    await _flush(tester);

    expect(controller.state, isNot(isA<MicRecording>()));
  });

  testWidgets(
    'Enter/Space via ActivateIntent calls toggle once per press; auto-repeat '
    'is ignored',
    (tester) async {
      controller = build();
      addTearDown(() => unawaited(controller.dispose()));
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpFlui(
        MicButton(controller: controller, focusNode: focusNode),
      );
      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await _flush(tester);
      expect(controller.state, isA<MicRecording>());

      // Auto-repeat while the key stays held must NOT toggle again.
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      await _flush(tester);
      expect(controller.state, isA<MicRecording>());

      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await _flush(tester);

      // A fresh key-down (a new press) toggles again, stopping it.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await _flush(tester);
      expect(controller.state, isNot(isA<MicRecording>()));

      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    },
  );

  testWidgets('a semantic tap (assistive-tech activate) calls toggle directly, '
      'distinct from the raw pointer down/up path', (tester) async {
    final handle = tester.ensureSemantics();
    controller = build();
    addTearDown(() => unawaited(controller.dispose()));
    await tester.pumpFlui(MicButton(controller: controller));

    final semantics = tester.getSemantics(find.byType(MicButton));
    expect(semantics.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    _performSemanticTap(tester, semantics.id);
    await _flush(tester);

    expect(controller.state, isA<MicRecording>());

    // Stop the recording (a second semantic tap toggles it off) so no
    // countdown timer is left pending once the test ends.
    _performSemanticTap(tester, semantics.id);
    await _flush(tester);
    handle.dispose();
  });

  testWidgets(
    'Semantics reflects the resolved actionLabel/hint, and the countdown '
    'while recording',
    (tester) async {
      final handle = tester.ensureSemantics();
      controller = build();
      addTearDown(() => unawaited(controller.dispose()));
      await tester.pumpFlui(MicButton(controller: controller));

      var semantics = tester.getSemantics(find.byType(MicButton));
      expect(semantics.label, 'Practicar en voz alta');
      expect(semantics.hint, 'Mantén pulsado para grabar');
      expect(semantics.value, isEmpty);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(MicButton)),
      );
      await _flush(tester);

      semantics = tester.getSemantics(find.byType(MicButton));
      expect(semantics.label, 'Grabando');
      expect(semantics.value, isNotEmpty);

      clock.advance(const Duration(milliseconds: 700));
      await gesture.up();
      await _flush(tester);
      handle.dispose();
    },
  );

  testWidgets('the touch target is never smaller than 48dp', (tester) async {
    controller = build();
    addTearDown(() => unawaited(controller.dispose()));
    await tester.pumpFlui(MicButton(controller: controller, size: 24));

    final size = tester.getSize(find.byType(MicButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets(
    'reduced motion disables the pulsing ring; ordinary motion shows it '
    'while recording',
    (tester) async {
      controller = build();
      addTearDown(() => unawaited(controller.dispose()));
      await tester.pumpFlui(
        MicButton(controller: controller),
        disableAnimations: false,
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(MicButton)),
      );
      await _flush(tester);
      expect(controller.state, isA<MicRecording>());
      expect(
        find.descendant(
          of: find.byType(MicButton),
          matching: find.byType(Transform),
        ),
        findsOneWidget,
      );

      clock.advance(const Duration(milliseconds: 700));
      await gesture.up();
      await _flush(tester);
    },
  );

  testWidgets(
    'a blocked pointer-down tap opens the matching blocked sheet instead of '
    'starting a recording (U23d)',
    (tester) async {
      controller = build()..setAccessGranted(false);
      addTearDown(() => unawaited(controller.dispose()));
      await tester.pumpFlui(MicButton(controller: controller));

      await tester.startGesture(tester.getCenter(find.byType(MicButton)));
      await _flush(tester);

      expect(
        find.text('Reactiva tu acceso para seguir practicando.'),
        findsOneWidget,
      );
      expect(find.text('Reactivar'), findsOneWidget);
      expect(controller.state, isNot(isA<MicRecording>()));
    },
  );

  testWidgets(
    'a blocked semantic/keyboard activation also opens the sheet, never '
    'toggling the mic',
    (tester) async {
      final handle = tester.ensureSemantics();
      controller = build()..setAccessGranted(false);
      addTearDown(() => unawaited(controller.dispose()));
      await tester.pumpFlui(MicButton(controller: controller));

      final semantics = tester.getSemantics(find.byType(MicButton));
      _performSemanticTap(tester, semantics.id);
      await _flush(tester);

      expect(
        find.text('Reactiva tu acceso para seguir practicando.'),
        findsOneWidget,
      );
      expect(controller.state, isNot(isA<MicRecording>()));
      handle.dispose();
    },
  );

  testWidgets('reduced motion never builds the pulsing ring, even while '
      'recording', (tester) async {
    controller = build();
    addTearDown(() => unawaited(controller.dispose()));
    // pumpFlui defaults to reduced motion (disableAnimations: true).
    await tester.pumpFlui(MicButton(controller: controller));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(MicButton)),
    );
    await _flush(tester);
    expect(controller.state, isA<MicRecording>());
    expect(
      find.descendant(
        of: find.byType(MicButton),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );

    clock.advance(const Duration(milliseconds: 700));
    await gesture.up();
    await _flush(tester);
  });
}
