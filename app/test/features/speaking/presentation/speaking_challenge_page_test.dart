import 'dart:async';
import 'dart:typed_data';

import 'package:flui/core/error/result.dart';
import 'package:flui/core/l10n/gen/app_localizations.dart';
import 'package:flui/features/speaking/data/fake_speech_analysis_repository.dart';
import 'package:flui/features/speaking/domain/speech_analysis_repository.dart';
import 'package:flui/features/speaking/domain/speech_recorder.dart';
import 'package:flui/features/speaking/domain/speech_transcript.dart';
import 'package:flui/features/speaking/presentation/speaking_challenge_page.dart';
import 'package:flui/shared/widgets/audio_reactive_bubble.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

final class FakeSpeechRecorder implements SpeechRecorder {
  new({
    this.permission = true,
    this.permissionResult,
    this.recording = const [1, 2, 3],
  });

  final bool permission;
  final Completer<bool>? permissionResult;
  final List<int> recording;
  int permissionRequests = 0;
  int starts = 0;
  int stops = 0;
  int cancellations = 0;

  @override
  Stream<double> get amplitude => const Stream.empty();
  @override
  Future<void> cancel() async {
    cancellations++;
  }

  @override
  Future<void> dispose() async {}
  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return await permissionResult?.future ?? permission;
  }

  @override
  Future<void> start() async {
    starts++;
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
    expect(find.textContaining('no guardamos tu audio'), findsOneWidget);
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
  });
}
