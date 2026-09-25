import 'dart:async';
import 'dart:typed_data';

import 'package:flui/core/error/result.dart';
import 'package:flui/core/l10n/gen/app_localizations.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/features/speaking/data/fake_speech_analysis_repository.dart';
import 'package:flui/features/speaking/domain/speech_analysis_repository.dart';
import 'package:flui/features/speaking/domain/speech_recorder.dart';
import 'package:flui/features/speaking/domain/speech_transcript.dart';
import 'package:flui/features/speaking/presentation/speaking_challenge_page.dart';
import 'package:flui/shared/widgets/audio_reactive_bubble.dart';
import 'package:flui/shared/widgets/flui_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

final class FakeSpeechRecorder implements SpeechRecorder {
  new({
    this.permission = true,
    this.permissionResult,
    this.startResult,
    this.recording = const [1, 2, 3],
  });

  final bool permission;
  final Completer<bool>? permissionResult;
  final Completer<void>? startResult;
  final List<int> recording;
  final events = <String>[];
  int permissionRequests = 0;
  int starts = 0;
  int stops = 0;
  int cancellations = 0;

  @override
  Stream<double> get amplitude => const Stream.empty();
  @override
  Future<void> cancel() async {
    cancellations++;
    events.add('cancel');
  }

  @override
  Future<void> dispose() async {
    events.add('dispose');
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return await permissionResult?.future ?? permission;
  }

  @override
  Future<void> start() async {
    starts++;
    events.add('start-requested');
    await startResult?.future;
    events.add('start-completed');
  }

  @override
  Future<Uint8List> stop() async {
    stops++;
    return Uint8List.fromList(recording);
  }
}

final class CountingAnalysisRepository implements SpeechAnalysisRepository {
  final _delegate = FakeSpeechAnalysisRepository(latency: Duration.zero);
  int calls = 0;

  @override
  Future<Result<SpeechTranscript>> analyze(
    Uint8List audio, {
    required String mimeType,
    required Duration duration,
  }) {
    calls++;
    return _delegate.analyze(audio, mimeType: mimeType, duration: duration);
  }
}

final class PendingAnalysisRepository implements SpeechAnalysisRepository {
  final result = Completer<Result<SpeechTranscript>>();

  @override
  Future<Result<SpeechTranscript>> analyze(
    Uint8List audio, {
    required String mimeType,
    required Duration duration,
  }) => result.future;
}

Future<TestGesture> _pressMicrophone(WidgetTester tester) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byType(AudioReactiveBubble).first),
  );
  await tester.pump();
  return gesture;
}

Future<void> _holdLongEnough(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 650)),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows a clear 45 second oral challenge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: SpeakingChallengePage(
          recorder: FakeSpeechRecorder(),
          analysisRepository: FakeSpeechAnalysisRepository(
            latency: Duration.zero,
          ),
        ),
      ),
    );

    expect(find.text('PAUSA DE PODER'), findsOneWidget);
    expect(find.textContaining('decisión pequeña'), findsOneWidget);
    expect(find.text('45 s'), findsOneWidget);
    expect(find.text('Empezar a hablar'), findsOneWidget);
    expect(find.bySemanticsLabel('Mantén pulsado para grabar'), findsOneWidget);
    expect(find.byType(AudioReactiveBubble), findsOneWidget);
    expect(find.byType(FluiCard), findsNWidgets(2));
    expect(
      tester.widget<FluiCard>(find.byType(FluiCard).first).color,
      FluiColors.aqua,
    );
    expect(find.textContaining('no guardamos tu audio'), findsOneWidget);
  });

  testWidgets('permission and recording states keep their live announcements', (
    tester,
  ) async {
    final permissionResult = Completer<bool>();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: SpeakingChallengePage(
          recorder: FakeSpeechRecorder(permissionResult: permissionResult),
        ),
      ),
    );

    final press = await _pressMicrophone(tester);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.liveRegion == true &&
            widget.properties.label == 'Preparando el micrófono',
      ),
      findsOneWidget,
    );
    expect(find.byType(FluiCard), findsWidgets);

    permissionResult.complete(true);
    await tester.pump();
    await tester.pump();
    await _holdLongEnough(tester);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.liveRegion == true &&
            widget.properties.label ==
                'Grabando. Mantén pulsado y suelta para analizar.',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.liveRegion != true &&
            widget.properties.label == '45 segundos restantes',
      ),
      findsOneWidget,
    );

    await press.cancel();
    await tester.pump();
  });

  testWidgets('analyzing state uses a written, announced progress surface', (
    tester,
  ) async {
    final repository = PendingAnalysisRepository();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: SpeakingChallengePage(
          recorder: FakeSpeechRecorder(),
          analysisRepository: repository,
        ),
      ),
    );

    final press = await _pressMicrophone(tester);
    await _holdLongEnough(tester);
    await press.up();
    await tester.pump();

    expect(find.text('Escuchando tu ritmo…'), findsOneWidget);
    expect(find.byType(FluiCard), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.liveRegion == true &&
            widget.properties.label == 'Analizando tu voz',
      ),
      findsOneWidget,
    );

    repository.result.complete(
      const Result.ok(
        SpeechTranscript(
          text: 'Una frase clara.',
          words: [],
          duration: Duration(seconds: 1),
        ),
      ),
    );
    await tester.pump();
  });

  testWidgets('releasing a hold submits each speaking attempt once', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: SpeakingChallengePage(
          recorder: FakeSpeechRecorder(),
          analysisRepository: FakeSpeechAnalysisRepository(
            latency: Duration.zero,
          ),
        ),
      ),
    );

    final firstHold = await _pressMicrophone(tester);
    await _holdLongEnough(tester);
    await firstHold.up();
    await tester.pump();
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(find.text('Inténtalo otra vez'), findsOneWidget);
    expect(find.byType(FluiCard).evaluate().length, greaterThanOrEqualTo(4));
    expect(find.textContaining('3 detectadas'), findsOneWidget);
    expect(find.text('LO QUE ENTENDÍ'), findsOneWidget);
    expect(find.textContaining('Eh pues tomé una decisión'), findsOneWidget);
    expect(find.text('VOCABULARIO · ESTIMACIÓN'), findsOneWidget);
    expect(find.textContaining('“organizar”'), findsOneWidget);

    await tester.ensureVisible(find.text('Inténtalo otra vez'));
    await tester.tap(find.text('Inténtalo otra vez'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    final secondHold = await _pressMicrophone(tester);
    await _holdLongEnough(tester);
    await secondHold.up();
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(find.text('Antes vs. ahora'), findsOneWidget);
    expect(find.byType(FluiCard).evaluate().length, greaterThanOrEqualTo(4));
    expect(find.text('3 → 0'), findsOneWidget);
  });

  testWidgets('a brief press cancels without submitting audio', (tester) async {
    final recorder = FakeSpeechRecorder();
    final repository = CountingAnalysisRepository();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: SpeakingChallengePage(
          recorder: recorder,
          analysisRepository: repository,
        ),
      ),
    );

    final press = await _pressMicrophone(tester);
    await press.up();
    await tester.pump();

    expect(recorder.starts, 1);
    expect(recorder.cancellations, 1);
    expect(recorder.stops, 0);
    expect(repository.calls, 0);
    expect(find.text('Empezar a hablar'), findsOneWidget);
  });

  testWidgets('permission denial never starts or submits a recording', (
    tester,
  ) async {
    final recorder = FakeSpeechRecorder(permission: false);
    final repository = CountingAnalysisRepository();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: SpeakingChallengePage(
          recorder: recorder,
          analysisRepository: repository,
        ),
      ),
    );

    final press = await _pressMicrophone(tester);
    await press.up();
    await tester.pump();

    expect(recorder.permissionRequests, 1);
    expect(recorder.starts, 0);
    expect(recorder.stops, 0);
    expect(repository.calls, 0);
    expect(find.text('Necesitamos acceso al micrófono'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.liveRegion == true &&
            widget.properties.label?.startsWith(
                  'Necesitamos acceso al micrófono.',
                ) ==
                true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('releasing a long hold submits exactly once', (tester) async {
    final recorder = FakeSpeechRecorder();
    final repository = CountingAnalysisRepository();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: SpeakingChallengePage(
          recorder: recorder,
          analysisRepository: repository,
        ),
      ),
    );

    final press = await _pressMicrophone(tester);
    await _holdLongEnough(tester);
    await press.up();
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();

    expect(recorder.starts, 1);
    expect(recorder.stops, 1);
    expect(recorder.cancellations, 0);
    expect(repository.calls, 1);
  });

  testWidgets('pointer cancellation discards a recording without analysis', (
    tester,
  ) async {
    final recorder = FakeSpeechRecorder();
    final repository = CountingAnalysisRepository();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: SpeakingChallengePage(
          recorder: recorder,
          analysisRepository: repository,
        ),
      ),
    );

    final press = await _pressMicrophone(tester);
    await _holdLongEnough(tester);
    await press.cancel();
    await tester.pump();

    expect(recorder.cancellations, 1);
    expect(recorder.stops, 0);
    expect(repository.calls, 0);
    expect(find.text('Empezar a hablar'), findsOneWidget);
  });

  testWidgets('release before permission resolves never starts recording', (
    tester,
  ) async {
    final permissionResult = Completer<bool>();
    final recorder = FakeSpeechRecorder(permissionResult: permissionResult);
    final repository = CountingAnalysisRepository();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: SpeakingChallengePage(
          recorder: recorder,
          analysisRepository: repository,
        ),
      ),
    );

    final press = await _pressMicrophone(tester);
    await press.up();
    permissionResult.complete(true);
    await tester.pump();
    await tester.pump();

    expect(recorder.starts, 0);
    expect(recorder.stops, 0);
    expect(repository.calls, 0);
  });

  testWidgets('release while start is pending cancels after start completes', (
    tester,
  ) async {
    final startResult = Completer<void>();
    final recorder = FakeSpeechRecorder(startResult: startResult);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: SpeakingChallengePage(recorder: recorder),
      ),
    );

    final press = await _pressMicrophone(tester);
    expect(recorder.events, ['start-requested']);
    await press.up();
    startResult.complete();
    await tester.pump();
    await tester.pump();

    expect(recorder.events, ['start-requested', 'start-completed', 'cancel']);
  });

  testWidgets(
    'pointer cancellation waits for pending start before cancelling',
    (tester) async {
      final startResult = Completer<void>();
      final recorder = FakeSpeechRecorder(startResult: startResult);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: SpeakingChallengePage(recorder: recorder),
        ),
      );

      final press = await _pressMicrophone(tester);
      await press.cancel();
      await tester.pump();

      expect(recorder.events, ['start-requested']);
      startResult.complete();
      await tester.pump();
      await tester.pump();

      expect(recorder.events, ['start-requested', 'start-completed', 'cancel']);
    },
  );

  testWidgets('leaving while start is pending cancels before disposal', (
    tester,
  ) async {
    final startResult = Completer<void>();
    final recorder = FakeSpeechRecorder(startResult: startResult);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: SpeakingChallengePage(recorder: recorder),
      ),
    );

    await _pressMicrophone(tester);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(recorder.events, ['start-requested']);

    startResult.complete();
    await tester.pump();
    await tester.pump();

    expect(recorder.events, [
      'start-requested',
      'start-completed',
      'cancel',
      'dispose',
    ]);
  });

  testWidgets('leaving during a hold cancels without analyzing', (
    tester,
  ) async {
    final recorder = FakeSpeechRecorder();
    final repository = CountingAnalysisRepository();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: SpeakingChallengePage(
          recorder: recorder,
          analysisRepository: repository,
        ),
      ),
    );

    await _pressMicrophone(tester);
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    expect(recorder.cancellations, 1);
    expect(recorder.stops, 0);
    expect(repository.calls, 0);
  });

  testWidgets('the maximum duration submits once if the pointer remains', (
    tester,
  ) async {
    final recorder = FakeSpeechRecorder();
    final repository = CountingAnalysisRepository();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: SpeakingChallengePage(
          recorder: recorder,
          analysisRepository: repository,
        ),
      ),
    );

    final press = await _pressMicrophone(tester);
    await tester.pump(const Duration(seconds: 45));
    await press.up();
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();

    expect(recorder.stops, 1);
    expect(repository.calls, 1);
    expect(recorder.cancellations, 0);
  });

  testWidgets('an empty recording surfaces a retryable written error', (
    tester,
  ) async {
    final recorder = FakeSpeechRecorder(recording: const []);
    final repository = CountingAnalysisRepository();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: SpeakingChallengePage(
          recorder: recorder,
          analysisRepository: repository,
        ),
      ),
    );

    final press = await _pressMicrophone(tester);
    await _holdLongEnough(tester);
    await press.up();
    await tester.pump();
    await tester.pump();

    expect(recorder.stops, 1);
    expect(repository.calls, 0);
    expect(find.text('No pudimos analizar este intento'), findsOneWidget);
    expect(find.text('Grabar de nuevo'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.liveRegion == true &&
            widget.properties.label?.startsWith(
                  'No pudimos analizar este intento.',
                ) ==
                true,
      ),
      findsOneWidget,
    );
    expect(find.byType(FluiCard), findsWidgets);
  });
}
