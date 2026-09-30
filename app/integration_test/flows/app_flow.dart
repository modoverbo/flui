import 'dart:typed_data';

import 'package:flui/app/shell/flui_bottom_bar.dart';
import 'package:flui/core/audio/audio_providers.dart';
import 'package:flui/core/audio/speech_recorder.dart';
import 'package:flui/core/mic/presentation/mic_button.dart';
import 'package:flui/core/theme/flui_type_scale.dart';
import 'package:flui/shared/widgets/flui_text_field.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// Registers this flow's `testWidgets` case — called once from the single
/// `integration_test/app_test.dart` entry point (not its own `main()`), so
/// every flow shares one `flutter-tester` app launch instead of each
/// `_test.dart` file relaunching the device.
void registerAppFlowTests() {
  testWidgets(
    'first day: register → paywall → trial → diagnosis → HOY → session → '
    'progress',
    (tester) async {
      await runFirstRunFlow(tester);
    },
  );
}

/// A permission-granted recorder that finishes instantly, real enough for
/// `HoldToRecord` to drive a full pointer-down/up cycle through
/// `MicController` (ported from `diagnosis_flow_test.dart`'s own).
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

/// First day on the fake backend:
/// welcome → intro (benefits + micro-lesson, skippable) → plan preview (real
/// prices, no account yet) → register → paywall on the decision step → fake
/// checkout → the mandatory diagnosis (3 mic slots) → HOY → the word daily
/// session for one new word (Descubre, one scene, Elige with a "Casi.",
/// Úsala recall, the rest of the scenes, Úsala production, final check) →
/// summary → Hoy done → Tu progreso.
Future<void> runFirstRunFlow(WidgetTester tester) async {
  final recorder = _FakeSpeechRecorder();
  final harness = AppHarness(
    overrides: [
      speechRecorderFactoryProvider.overrideWithValue(() => recorder),
    ],
  );
  await harness.pumpApp(tester);

  Future<void> tapText(String text) async {
    final finder = find.text(text);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> tapOption(String text) async {
    await tapText(text);
    await tapText('Confirmar');
  }

  Future<void> fill(String label, String value) => tester.enterText(
    find.widgetWithText(FluiTextField, FluiTypeScale.labelText(label)),
    value,
  );

  /// Presses the shell/root mic for long enough to clear `HoldToRecord`'s
  /// minimum hold, then releases — one captured attempt. [heardText]
  /// overrides the fake transcribe repository's NEXT result exactly once
  /// (D34's word-exercise path, `mode=transcribe`) — `null` for a plain
  /// analyze-only capture (e.g. diagnosis), which never reads it.
  Future<void> recordOneCapture({String? heardText}) async {
    if (heardText != null) harness.speech.nextTranscribeText = heardText;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(MicButton)),
    );
    for (var i = 0; i < 3; i++) {
      await tester.pump();
    }
    harness.clock.advance(const Duration(milliseconds: 700));
    await gesture.up();
    await tester.pumpAndSettle();
  }

  // Welcome.
  expect(find.text('Empezar'), findsOneWidget);
  await tapText('Empezar');

  // Intro: the promise, then the micro-lesson, both skippable.
  expect(find.text('No te faltan ideas. Te faltan palabras.'), findsOneWidget);
  await tapText('Saltar');

  // The paywall before the account: real prices, nothing charged, no email
  // asked for yet.
  expect(find.text('Tu plan está listo.'), findsOneWidget);
  await tapText('Seguir');
  expect(find.text('Cómo funciona tu prueba'), findsOneWidget);
  expect(
    find.text('Si cancelas antes del día 8, no pagas nada.'),
    findsOneWidget,
  );
  await tapText('Seguir');
  expect(find.text('Elige tu plan'), findsOneWidget);
  expect(find.text('Trimestral'), findsOneWidget);
  expect(find.text(r'US$ 16.15 cada 3 meses'), findsOneWidget);
  expect(find.text('Creas tu cuenta en el siguiente paso.'), findsOneWidget);
  await tapText('Crear mi cuenta');

  // Register.
  expect(find.text('Crea tu cuenta'), findsOneWidget);
  await fill('Nombre', 'Ana');
  await fill('Correo', 'ana@correo.com');
  await fill('Contraseña', 'secreta123');
  await tapText('Crear cuenta');

  // The paywall opens on the decision: the pitch is not repeated.
  expect(find.text('Elige tu plan'), findsOneWidget);
  expect(find.text(r'Hoy pagas US$0.'), findsOneWidget);
  await tapText('Empezar prueba gratis');

  // Fake checkout returns to /checkout/return, which polls until the fake
  // webhook grants the trial, then the mandatory diagnosis gate (U14a)
  // takes over — before anything else, including the daily time budget.
  expect(harness.subscriptions.checkoutRequests, ['quarterly']);
  expect(find.text('Antes de empezar: una evaluación rápida'), findsOneWidget);
  await tapText('Empezar');

  // Diagnosis: 3 mic slots, measure-only (no feedback/comparison step
  // between them) — each capture auto-advances to the next slot.
  for (var slot = 1; slot <= 3; slot++) {
    await recordOneCapture();
  }

  // The profile is real, derived from the 3 captured attempts — never
  // fabricated.
  expect(find.text('Tu perfil de expresión oral'), findsOneWidget);
  await tapText('Ir a HOY');

  // HOY, with the diagnosis done. The word daily session is a separate
  // action from the speaking loop's own chips card above it — pick the
  // time budget from the sticky dock, same as before diagnosis existed.
  expect(find.byType(FluiBottomBar), findsOneWidget);
  expect(find.text('Hola, Ana'), findsOneWidget);
  await tapText('Elegir tiempo');

  expect(find.text('¿Cuánto tiempo tienes hoy?'), findsOneWidget);
  await tapText('10 min');

  // The theme: three recommendations, and a door to the rest of them.
  expect(find.text('¿Sobre qué tema?'), findsOneWidget);
  expect(find.text('Reuniones'), findsOneWidget);
  await tapText('Explorar');
  expect(find.text('Todos los temas'), findsOneWidget);
  await tapText('Reconocer a otros');
  await tapText('Empezar');

  // Hoy, with the chosen theme and a word that belongs to it.
  expect(find.byType(FluiBottomBar), findsOneWidget);
  expect(find.text('10 minutos'), findsOneWidget);
  expect(find.text('TEMA DE HOY'), findsOneWidget);
  expect(find.text('Reconocer a otros'), findsOneWidget);
  expect(find.text('perspicaz'), findsOneWidget);
  await tapText('Empezar');

  // Descubre + Entiende.
  expect(find.text('TU PALABRA DE HOY'), findsOneWidget);
  expect(find.text('perspicaz'), findsOneWidget);
  expect(find.text('1 DE 7'), findsOneWidget);
  await tapText('Ver en contexto');

  // Mira: one scene now, the rest after the form recall.
  expect(find.text('Mira cómo suena'), findsOneWidget);
  expect(find.text('1 DE 1'), findsOneWidget);
  await tapText('Continuar');

  // Elige: one wrong answer first.
  expect(find.text('Encuentra la palabra que encaja'), findsOneWidget);
  await tapOption('suspicaz');
  expect(find.text('Casi.'), findsOneWidget);
  expect(
    find.text(
      'La palabra describe a alguien que capta rápido lo que no es evidente.',
    ),
    findsOneWidget,
  );
  await tapText('Intentar de nuevo');
  await tapOption('perspicaz');
  expect(find.text('¡Eso es!'), findsOneWidget);
  await tapText('Continuar');

  // Úsala: form recall by mic, then production with the self-check.
  expect(find.text('Ahora dilo tú.'), findsOneWidget);
  await recordOneCapture(heardText: 'perspicaz');
  expect(find.text('¡Eso es!'), findsOneWidget);
  await tapText('Continuar');

  // Mira again: the scenes that were held back.
  expect(find.text('Mira cómo suena'), findsOneWidget);
  expect(find.text('1 DE 2'), findsOneWidget);
  await tester.ensureVisible(find.byTooltip('Siguiente'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Siguiente'));
  await tester.pumpAndSettle();
  expect(find.text('2 DE 2'), findsOneWidget);
  await tapText('Continuar');

  expect(find.text('Úsala'), findsOneWidget);
  await recordOneCapture(
    heardText: 'Carla hizo una pregunta muy perspicaz en la reunión.',
  );
  expect(find.text('¿Suena natural?'), findsOneWidget);
  // The model sentence is shown to compare against, and every rubric item
  // has to be ticked before the sentence is accepted.
  expect(find.text('Una frase que funciona'), findsOneWidget);
  expect(find.text('Marca lo que se cumple para seguir.'), findsOneWidget);
  for (final item in [
    'Dice lo que quiero decir',
    'La diría en voz alta sin sonar raro',
    'La palabra encaja, no está forzada',
  ]) {
    await tapText(item);
  }
  await tapText('Sí, suena natural');

  // End-of-session check: a fresh sentence, first try.
  expect(find.text('UNA FRASE NUEVA'), findsOneWidget);
  await tapOption('perspicaz');
  expect(find.text('¡Eso es!'), findsOneWidget);
  await tapText('Continuar');

  // Summary: what moved, how it went, and what waits tomorrow.
  expect(find.text('Una palabra más en tu repertorio.'), findsOneWidget);
  expect(find.text('PRACTICA'), findsOneWidget);
  expect(find.text('1 día seguido'), findsOneWidget);
  // Elige took two tries, the check one: half of the answers were first-try.
  expect(find.text('50 % A LA PRIMERA EN ESTA SESIÓN'), findsOneWidget);
  expect(find.text('Mañana: 1 repaso'), findsOneWidget);
  // The five-rung meter shows the work the "Practica" chip hides.
  expect(find.text('4 DE 5'), findsOneWidget);
  await tapText('Volver a Hoy');

  // Hoy is done for today, and Progreso counts the day.
  expect(find.text('Hoy ya sumaste. Vuelve mañana.'), findsOneWidget);
  await tapText('Progreso');
  expect(find.text('1 de 7 días esta semana'), findsOneWidget);
  expect(find.text('Hola, Ana'), findsOneWidget);
  expect(find.textContaining('Prueba gratis hasta el'), findsOneWidget);
}
