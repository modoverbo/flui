import 'dart:async';
import 'dart:typed_data';

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/audio/speech_recorder.dart';
import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/mic/mic_controller.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/core/mic/mic_target_registry.dart';
import 'package:flui/core/mic/presentation/mic_button.dart';
import 'package:flui/features/vocabulary/domain/exercises/form_recall_check.dart';
import 'package:flui/features/vocabulary/domain/form_recall_prompt.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/features/vocabulary/presentation/widgets/form_recall_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../helpers/learning_fakes.dart';
import '../../../helpers/pump_app.dart';

class _RecallHost extends StatefulWidget {
  const new({super.key, this.speakingGym = false, this.micController});

  final bool speakingGym;
  final MicController? micController;

  @override
  State<_RecallHost> createState() => _RecallHostState();
}

class _RecallHostState extends State<_RecallHost> {
  final Word _word = seedWord('perspicaz');
  late final _prompt = FormRecallPrompt.forWord(_word);
  late var _check = FormRecallCheck(
    expectedForm: _prompt.expectedForm,
    forms: _word.forms,
  );
  var _skipped = false;

  bool get skipped => _skipped;

  /// Simulates `FormRecallMicTarget.deliver` having already resolved
  /// [transcript] through `SessionController.answerFormRecallAloud`.
  void speak(String transcript) =>
      setState(() => _check = _check.submitHeard(transcript));

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: FormRecallView(
      check: _check,
      explanation: _prompt.explanation,
      sentenceBefore: _prompt.before,
      sentenceAfter: _prompt.after,
      syllableCount: _word.syllables.length,
      onSubmit: (text) => setState(() => _check = _check.submit(text)),
      onHint: () => setState(() => _check = _check.takeHint()),
      onContinue: () {},
      speakingGym: widget.speakingGym,
      micController: widget.micController,
      onSkip: () => setState(() => _skipped = true),
    ),
  );
}

final class _FakeFormRecallMicTarget implements MicTarget {
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

MicController _buildMicController({bool accessGranted = true}) {
  final registry = MicTargetRegistry()
    ..register(_FakeFormRecallMicTarget(), layer: MicLayer.root);
  return MicController(
    recorderFactory: _FakeSpeechRecorder.new,
    registry: registry,
    clock: FixedClock(DateTime(2026)),
  )..setAccessGranted(accessGranted);
}

void main() {
  Future<void> pumpRecall(WidgetTester tester) =>
      tester.pumpFlui(const _RecallHost(), surfaceSize: const Size(400, 1200));

  testWidgets('two hints (syllables, first letter), then the reveal', (
    tester,
  ) async {
    await pumpRecall(tester);
    expect(find.text('Ahora dilo tú.'), findsOneWidget);

    await tester.tap(find.text('Pista'));
    await tester.pump();
    expect(find.text('Tiene 3 sílabas.'), findsOneWidget);

    await tester.tap(find.text('Pista'));
    await tester.pump();
    expect(find.text('Tiene 3 sílabas. Empieza por «p».'), findsOneWidget);

    await tester.tap(find.text('Ver la palabra'));
    await tester.pump();
    expect(
      find.text('La palabra es «perspicaz». La tendrás de nuevo pronto.'),
      findsOneWidget,
    );
    expect(find.text('Continuar'), findsOneWidget);
  });

  testWidgets('a wrong answer says "Casi." and gives the first hint', (
    tester,
  ) async {
    await pumpRecall(tester);

    await tester.enterText(find.byType(TextField), 'listo');
    await tester.tap(find.text('Comprobar'));
    await tester.pump();

    expect(find.text('Casi. Prueba otra vez.'), findsOneWidget);
    expect(find.text('Tiene 3 sílabas.'), findsOneWidget);
  });

  testWidgets('accepts accents, case and one typo', (tester) async {
    await pumpRecall(tester);

    await tester.enterText(fluiField('Tu palabra'), 'PERSPÍKAZ');
    await tester.tap(find.text('Comprobar'));
    await tester.pump();

    expect(find.text('¡Eso es!'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
  });

  group('speakingGym on (U17b spoken Úsala)', () {
    testWidgets('drops FluiTextField and the typed submit button', (
      tester,
    ) async {
      final controller = _buildMicController();
      addTearDown(() => unawaited(controller.dispose()));
      await tester.pumpFlui(
        _RecallHost(speakingGym: true, micController: controller),
        surfaceSize: const Size(400, 1200),
      );

      expect(find.byType(TextField), findsNothing);
      expect(find.text('Comprobar'), findsNothing);
      expect(find.byType(MicButton), findsOneWidget);
      // Hint stays a tap even under the flag (design D36).
      expect(find.text('Pista'), findsOneWidget);
    });

    testWidgets('shows the heard text once submitHeard set lastHeard', (
      tester,
    ) async {
      final controller = _buildMicController();
      addTearDown(() => unawaited(controller.dispose()));
      final state = GlobalKey<_RecallHostState>();
      await tester.pumpFlui(
        _RecallHost(key: state, speakingGym: true, micController: controller),
        surfaceSize: const Size(400, 1200),
      );

      state.currentState!.speak('gato');
      await tester.pump();

      expect(find.text('Escuché: «gato»'), findsOneWidget);
    });

    testWidgets(
      '"Continuar sin hablar" appears only while the mic is blocked and '
      'calls onSkip',
      (tester) async {
        final controller = _buildMicController(accessGranted: false);
        addTearDown(() => unawaited(controller.dispose()));
        final state = GlobalKey<_RecallHostState>();
        await tester.pumpFlui(
          _RecallHost(key: state, speakingGym: true, micController: controller),
          surfaceSize: const Size(400, 1200),
        );

        expect(find.text('Continuar sin hablar'), findsOneWidget);
        await tester.tap(find.text('Continuar sin hablar'));
        await tester.pump();
        expect(state.currentState!.skipped, isTrue);
      },
    );

    testWidgets('"Continuar" still shows once accepted', (tester) async {
      final controller = _buildMicController();
      addTearDown(() => unawaited(controller.dispose()));
      final state = GlobalKey<_RecallHostState>();
      await tester.pumpFlui(
        _RecallHost(key: state, speakingGym: true, micController: controller),
        surfaceSize: const Size(400, 1200),
      );

      state.currentState!.speak('perspicaz');
      await tester.pump();

      expect(find.text('¡Eso es!'), findsOneWidget);
      expect(find.text('Continuar'), findsOneWidget);
    });
  });
}
