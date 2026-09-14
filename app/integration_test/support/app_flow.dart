import 'package:flui/core/theme/flui_type_scale.dart';
import 'package:flui/shared/widgets/flui_text_field.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'app_harness.dart';

/// First day on the fake backend:
/// welcome → intro → plan preview (real prices, no account yet) → register →
/// paywall on the decision step → fake checkout → time budget (10 min) → Hoy
/// → session for one new word (Descubre, one scene, Elige with a "Casi.",
/// Úsala recall, the rest of the scenes, Úsala production, final check) →
/// summary → Hoy done → Tu progreso.
Future<void> runFirstRunFlow(WidgetTester tester) async {
  final harness = AppHarness();
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

  // Welcome.
  expect(find.text('Empezar'), findsOneWidget);
  await tapText('Empezar');

  // Intro: the promise, then the questions and the micro-lesson, all
  // skippable.
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
  // webhook grants the trial, then the router opens the two questions of the
  // day: how long, and about what.
  expect(harness.subscriptions.checkoutRequests, ['quarterly']);
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
  expect(find.byType(NavigationBar), findsOneWidget);
  expect(find.text('Hola, Ana'), findsOneWidget);
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

  // Úsala: form recall, then production with the self-check.
  expect(find.text('Ahora dilo tú.'), findsOneWidget);
  await fill('Tu palabra', 'perspicaz');
  await tapText('Comprobar');
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
  await fill(
    'Tu frase',
    'Carla hizo una pregunta muy perspicaz en la reunión.',
  );
  await tapText('Comprobar');
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

  // Hoy is done for today, and Tu progreso counts the day.
  expect(find.text('Hoy ya sumaste. Vuelve mañana.'), findsOneWidget);
  await tapText('Tu progreso');
  expect(find.text('1 de 7 días esta semana'), findsOneWidget);
  expect(find.text('Hola, Ana'), findsOneWidget);
  expect(find.textContaining('Prueba gratis hasta el'), findsOneWidget);
}
