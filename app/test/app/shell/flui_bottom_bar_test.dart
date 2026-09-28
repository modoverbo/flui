import 'dart:async';
import 'dart:typed_data';

import 'package:flui/app/shell/flui_bottom_bar.dart';
import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/audio/speech_recorder.dart';
import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/mic/mic_controller.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/core/mic/mic_target_registry.dart';
import 'package:flui/core/mic/presentation/mic_button.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/shared/widgets/flui_glyph.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

final class _FakeMicTarget implements MicTarget {
  new();

  @override
  final MicPrompt prompt = const MicPrompt(actionLabel: 'Practicar');

  @override
  final Duration maxDuration = const Duration(seconds: 30);

  @override
  MicAvailability get availability => const MicReady();

  final _c = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _c.stream;

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

const _items = <(FluiGlyph, String)>[
  (FluiGlyph.onda, 'Hoy'),
  (FluiGlyph.microphone, 'Entrenar'),
  (FluiGlyph.wordOfTheDay, 'Palabras'),
  (FluiGlyph.streak, 'Tu progreso'),
];

void main() {
  MicController buildController() {
    final registry = MicTargetRegistry()
      ..register(_FakeMicTarget(), layer: MicLayer.branch);
    return MicController(
      recorderFactory: _FakeSpeechRecorder.new,
      registry: registry,
      clock: FixedClock(DateTime(2026)),
    )..setAccessGranted(true);
  }

  testWidgets('renders exactly 4 destinations plus one raised mic action', (
    tester,
  ) async {
    final controller = buildController();
    addTearDown(() => unawaited(controller.dispose()));
    final selected = <int>[];

    await tester.pumpFlui(
      FluiBottomBar(
        items: _items,
        selectedIndex: 0,
        onDestinationSelected: selected.add,
        progressIndex: 3,
        micController: controller,
      ),
      surfaceSize: const Size(400, 800),
    );

    for (final (_, label) in _items) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byType(MicButton), findsOneWidget);
  });

  testWidgets('tapping a destination reports its index; the mic is never '
      'one of them', (tester) async {
    final controller = buildController();
    addTearDown(() => unawaited(controller.dispose()));
    final selected = <int>[];

    await tester.pumpFlui(
      FluiBottomBar(
        items: _items,
        selectedIndex: 0,
        onDestinationSelected: selected.add,
        progressIndex: 3,
        micController: controller,
      ),
      surfaceSize: const Size(400, 800),
    );

    await tester.tap(find.text('Entrenar'));
    expect(selected, [1]);

    await tester.tap(find.text('Tu progreso'));
    expect(selected, [1, 3]);

    // The mic is an action, not a destination: tapping it never calls
    // onDestinationSelected.
    await tester.tap(find.byType(MicButton));
    expect(selected, [1, 3]);
    // A quick tap latches to a toggled recording (design D26) — stop it
    // with a second tap so no countdown timer is left pending.
    await tester.tap(find.byType(MicButton));
    for (var i = 0; i < 3; i++) {
      await tester.pump();
    }
  });

  testWidgets('the bar surface uses the floating radius/colors of the '
      'existing bar', (tester) async {
    final controller = buildController();
    addTearDown(() => unawaited(controller.dispose()));

    await tester.pumpFlui(
      FluiBottomBar(
        items: _items,
        selectedIndex: 0,
        onDestinationSelected: (_) {},
        progressIndex: 3,
        micController: controller,
      ),
      surfaceSize: const Size(400, 800),
    );

    final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
    expect(
      (clip.borderRadius as BorderRadius).topLeft,
      const Radius.circular(28),
    );
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(ClipRRect),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((container.decoration! as BoxDecoration).color, FluiColors.surface);
  });
}
