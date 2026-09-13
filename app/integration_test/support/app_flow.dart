import 'package:flui/shared/widgets/flui_text_field.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'app_harness.dart';

/// First run on the fake backend:
/// welcome → intro → register → paywall → fake checkout → return → shell.
Future<void> runFirstRunFlow(WidgetTester tester) async {
  final harness = AppHarness();
  await harness.pumpApp(tester);

  Future<void> tapText(String text) async {
    final finder = find.text(text);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
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
  await tapText('Ir a Hoy');

  // App shell.
  expect(find.byType(NavigationBar), findsOneWidget);
  expect(find.text('Aquí vivirá tu sesión del día.'), findsOneWidget);
  await tapText('Tu progreso');
  expect(find.text('Hola, Ana'), findsOneWidget);
  expect(find.textContaining('Prueba gratis hasta el'), findsOneWidget);
}
