import 'dart:async';
import 'dart:typed_data';

import 'package:flui/features/speaking/domain/speech_recorder.dart';
import 'package:flui/features/speaking/presentation/speaking_challenge_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class FakeSpeechRecorder implements SpeechRecorder {
  @override
  Stream<double> get amplitude => const Stream.empty();
  @override
  Future<void> cancel() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> start() async {}
  @override
  Future<Uint8List> stop() async => Uint8List.fromList([1, 2, 3]);
}

void main() {
  testWidgets('shows a clear 45 second oral challenge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: SpeakingChallengePage(recorder: FakeSpeechRecorder())),
    );

    expect(find.text('PAUSA DE PODER'), findsOneWidget);
    expect(find.textContaining('decisión pequeña'), findsOneWidget);
    expect(find.text('45 s'), findsOneWidget);
    expect(find.text('Empezar a hablar'), findsOneWidget);
    expect(find.textContaining('no guardamos tu audio'), findsOneWidget);
  });

  testWidgets('finishing twice reveals before and after comparison', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: SpeakingChallengePage(recorder: FakeSpeechRecorder())),
    );

    await tester.tap(find.text('Empezar a hablar'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    await tester.tap(find.text('Terminar intento'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(find.text('Inténtalo otra vez'), findsOneWidget);

    await tester.tap(find.text('Inténtalo otra vez'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    await tester.tap(find.text('Terminar intento'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(find.text('Antes vs. ahora'), findsOneWidget);
  });
}
