import 'package:flui/app/router/app_routes.dart';
import 'package:flui/features/auth/data/fake_auth_repository.dart';
import 'package:flui/features/auth/presentation/pages/register_page.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/pump_router.dart';

void main() {
  late FakeAuthRepository auth;

  tearDown(() => auth.dispose());

  Future<GoRouter> pumpRegister(WidgetTester tester) => pumpRoutedPage(
    tester,
    location: AppRoutes.register,
    page: const RegisterPage(),
    otherRoutes: [AppRoutes.login],
    overrides: [authRepositoryProvider.overrideWithValue(auth)],
    surfaceSize: const Size(400, 1000),
  );

  Future<void> fillAndSubmit(WidgetTester tester) async {
    await tester.enterText(fluiField('Nombre'), 'Ana');
    await tester.enterText(fluiField('Correo'), 'ana@correo.com');
    await tester.enterText(fluiField('Contraseña'), 'secreta1');
    await tester.tap(find.text('Crear cuenta'));
    await tester.pump();
  }

  testWidgets('shows validation messages', (tester) async {
    auth = FakeAuthRepository();
    await pumpRegister(tester);

    await tester.enterText(fluiField('Contraseña'), '123');
    await tester.tap(find.text('Crear cuenta'));
    await tester.pump();

    expect(find.text('Dinos cómo te llamas.'), findsOneWidget);
    expect(find.text('Escribe tu correo.'), findsOneWidget);
    expect(find.text('Usa al menos 8 caracteres.'), findsOneWidget);
  });

  testWidgets('creates the account with the display name', (tester) async {
    auth = FakeAuthRepository();
    await pumpRegister(tester);

    await fillAndSubmit(tester);

    expect(auth.currentUser?.displayName, 'Ana');
  });

  testWidgets('asks to check the inbox when confirmation is required', (
    tester,
  ) async {
    auth = FakeAuthRepository(requireEmailConfirmation: true);
    await pumpRegister(tester);

    await fillAndSubmit(tester);
    await tester.pump();

    expect(find.text('Revisa tu correo'), findsOneWidget);
    expect(
      find.text(
        'Te enviamos un enlace a ana@correo.com para confirmar tu cuenta.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Google sign-in is visible but disabled', (tester) async {
    auth = FakeAuthRepository();
    await pumpRegister(tester);

    final google = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Continuar con Google (muy pronto)'),
    );
    expect(google.onPressed, isNull);
  });

  testWidgets(
    '"Ya tengo una cuenta" pushes login, so back returns to the register '
    'form instead of exiting the app',
    (tester) async {
      auth = FakeAuthRepository();
      final router = await pumpRegister(tester);

      await tester.ensureVisible(find.text('Ya tengo una cuenta'));
      await tester.tap(find.text('Ya tengo una cuenta'));
      await tester.pumpAndSettle();

      expect(router.routerDelegate.currentConfiguration.matches, hasLength(2));
      expect(router.routerDelegate.canPop(), isTrue);

      await router.routerDelegate.popRoute();
      await tester.pumpAndSettle();

      expect(fluiField('Nombre'), findsOneWidget);
      expect(router.routerDelegate.currentConfiguration.matches, hasLength(1));
    },
  );

  testWidgets('confirmation screen pushes login, so back returns to the '
      'confirmation message instead of exiting the app', (tester) async {
    auth = FakeAuthRepository(requireEmailConfirmation: true);
    final router = await pumpRegister(tester);

    await fillAndSubmit(tester);
    await tester.pump();
    expect(find.text('Revisa tu correo'), findsOneWidget);

    await tester.tap(find.text('Ir a entrar'));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.matches, hasLength(2));
    expect(router.routerDelegate.canPop(), isTrue);

    await router.routerDelegate.popRoute();
    await tester.pumpAndSettle();

    expect(find.text('Revisa tu correo'), findsOneWidget);
    expect(router.routerDelegate.currentConfiguration.matches, hasLength(1));
  });
}
