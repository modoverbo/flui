import 'package:flui/shared/widgets/flui_text_field.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'app_harness.dart';

/// First day on the fake backend:
/// welcome → intro → register → paywall → fake checkout → time budget
/// (10 min) → Hoy → session for one new word (Descubre, Mira, Elige with a
/// "Casi.", Úsala, final check) → summary → Hoy done → Tu progreso.
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

  // Welcome.
  expect(find.text('Empezar'), findsOneWidget);
  await tapText('Empezar');

  // Intro.
  expect(find.text('No te faltan ideas. Te faltan palabras.'), findsOneWidget);
  await tapText('Saltar');

  // Register.
  expect(find.text('Crea tu cuenta'), findsOneWidget);
  await tester.enterText(find.widgetWithText(FluiTextField, 'Nombre'), 'Ana');
  await tester.enterText(
    find.widgetWithText(FluiTextField, 'Correo'),
    'ana@correo.com',
  );
  await tester.enterText(
    find.widgetWithText(FluiTextField, 'Contraseña'),
    'secreta123',
  );
  await tapText('Crear cuenta');

  // Paywall.
  expect(find.text('Empieza tus 7 días gratis'), findsOneWidget);
  expect(find.text('Trimestral'), findsOneWidget);
  await tapText('Empezar prueba gratis');

  // Fake checkout returns to /checkout/return, which polls until the fake
  // webhook grants the trial, then the router opens the time budget.
  expect(harness.subscriptions.checkoutRequests, ['quarterly']);
  expect(find.text('¿Cuánto tiempo tienes hoy?'), findsOneWidget);
  await tapText('10 min');
  await tapText('Empezar');

  // Hoy.
  expect(find.byType(NavigationBar), findsOneWidget);
  expect(find.text('Hola, Ana'), findsOneWidget);
  expect(find.text('Tu sesión de hoy'), findsOneWidget);
  expect(find.text('10 minutos'), findsOneWidget);
  expect(find.text('perspicaz'), findsOneWidget);
  await tapText('Empezar');

  // Descubre + Entiende.
  expect(find.text('Tu palabra de hoy'), findsOneWidget);
  expect(find.text('perspicaz'), findsOneWidget);
  expect(find.text('1 de 6'), findsOneWidget);
  await tapText('Ver en contexto');

  // Mira.
  expect(find.text('Mira cómo suena'), findsOneWidget);
  expect(find.text('1 de 3'), findsOneWidget);
  await tester.tap(find.byTooltip('Siguiente'));
  await tester.pumpAndSettle();
  expect(find.text('2 de 3'), findsOneWidget);
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
  await tester.enterText(
    find.widgetWithText(FluiTextField, 'Tu palabra'),
    'perspicaz',
  );
  await tapText('Comprobar');
  expect(find.text('¡Eso es!'), findsOneWidget);
  await tapText('Continuar');

  expect(find.text('Úsala'), findsOneWidget);
  await tester.enterText(
    find.widgetWithText(FluiTextField, 'Tu frase'),
    'Carla hizo una pregunta muy perspicaz en la reunión.',
  );
  await tapText('Comprobar');
  expect(find.text('¿Suena natural?'), findsOneWidget);
  await tapText('Sí, suena natural');

  // End-of-session check: a fresh sentence, first try.
  expect(find.text('Una frase nueva'), findsOneWidget);
  await tapOption('perspicaz');
  expect(find.text('¡Eso es!'), findsOneWidget);
  await tapText('Continuar');

  // Summary.
  expect(find.text('Una palabra más en tu repertorio.'), findsOneWidget);
  expect(find.text('Practica'), findsOneWidget);
  await tapText('Volver a Hoy');

  // Hoy is done for today, and Tu progreso counts the day.
  expect(find.text('Hoy ya sumaste. Vuelve mañana.'), findsOneWidget);
  await tapText('Tu progreso');
  expect(find.text('1 de 7 días esta semana'), findsOneWidget);
  expect(find.text('Hola, Ana'), findsOneWidget);
  expect(find.textContaining('Prueba gratis hasta el'), findsOneWidget);
}
