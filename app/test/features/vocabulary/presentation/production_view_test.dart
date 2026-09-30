import 'dart:async';
import 'dart:typed_data';

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/audio/speech_recorder.dart';
import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/mic/mic_controller.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/core/mic/mic_target_registry.dart';
import 'package:flui/core/mic/presentation/mic_button.dart';
import 'package:flui/features/vocabulary/domain/exercises/production_check.dart';
import 'package:flui/features/vocabulary/domain/exercises/word_forms.dart';
import 'package:flui/features/vocabulary/presentation/widgets/production_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../helpers/pump_app.dart';

const _forms = WordForms(lemma: 'perspicaz', isVerb: false);

class _ProductionHost extends StatefulWidget {
  const new({super.key, this.micController});

  final MicController? micController;

  @override
  State<_ProductionHost> createState() => _ProductionHostState();
}

class _ProductionHostState extends State<_ProductionHost> {
  var _flow = const ProductionFlow(forms: _forms);
  var _skipped = false;

  bool get skipped => _skipped;

  void speak(String transcript) =>
      setState(() => _flow = _flow.submit(transcript));

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: ProductionView(
      flow: _flow,
      lemma: 'perspicaz',
      beforePhrase: 'era muy lista',
      onConfirm: () => setState(() => _flow = _flow.confirmNatural()),
      onRevise: () => setState(() => _flow = _flow.rejectNatural()),
      onToggle: (item) => setState(() => _flow = _flow.toggle(item)),
      micController: widget.micController,
      onSkip: () => setState(() => _skipped = true),
    ),
  );
}

final class _FakeProductionMicTarget implements MicTarget {
  new();

  @override
  final MicPrompt prompt = const MicPrompt(actionLabel: 'Grabar tu oración');

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

MicController _buildMicController({bool accessGranted = true}) {
  final registry = MicTargetRegistry()
    ..register(_FakeProductionMicTarget(), layer: MicLayer.root);
  return MicController(
    recorderFactory: _FakeSpeechRecorder.new,
    registry: registry,
    clock: FixedClock(DateTime(2026)),
  )..setAccessGranted(accessGranted);
}

void main() {
  testWidgets('drops FluiTextField and the typed submit button', (
    tester,
  ) async {
    final controller = _buildMicController();
    addTearDown(() => unawaited(controller.dispose()));
    await tester.pumpFlui(
      _ProductionHost(micController: controller),
      surfaceSize: const Size(400, 1200),
    );

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Comprobar'), findsNothing);
    expect(find.byType(MicButton), findsOneWidget);
  });

  testWidgets('shows the heard sentence once one was transcribed', (
    tester,
  ) async {
    final controller = _buildMicController();
    addTearDown(() => unawaited(controller.dispose()));
    final key = GlobalKey<_ProductionHostState>();
    await tester.pumpFlui(
      _ProductionHost(key: key, micController: controller),
      surfaceSize: const Size(400, 1200),
    );

    key.currentState!.speak('demasiado corto');
    await tester.pump();

    expect(find.text('Escuché: «demasiado corto»'), findsOneWidget);
  });

  testWidgets(
    '"Continuar sin hablar" appears only while the mic is blocked and '
    'calls onSkip',
    (tester) async {
      final controller = _buildMicController(accessGranted: false);
      addTearDown(() => unawaited(controller.dispose()));
      await tester.pumpFlui(
        _ProductionHost(micController: controller),
        surfaceSize: const Size(400, 1200),
      );

      expect(find.text('Continuar sin hablar'), findsOneWidget);
      await tester.tap(find.text('Continuar sin hablar'));
      await tester.pump();
    },
  );

  testWidgets('moves to the self-check phase on a valid heard sentence', (
    tester,
  ) async {
    final controller = _buildMicController();
    addTearDown(() => unawaited(controller.dispose()));
    final key = GlobalKey<_ProductionHostState>();
    await tester.pumpFlui(
      _ProductionHost(key: key, micController: controller),
      surfaceSize: const Size(400, 1200),
    );

    key.currentState!.speak('Ella fue muy perspicaz con la respuesta.');
    await tester.pump();

    expect(find.text('¿Suena natural?'), findsOneWidget);
  });
}
