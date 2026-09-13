import 'package:flui/app/router/app_routes.dart';
import 'package:flui/features/auth/data/fake_auth_repository.dart';
import 'package:flui/features/auth/presentation/pages/login_page.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/shared/widgets/flui_text_field.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_router.dart';

void main() {
  late FakeAuthRepository auth;

  setUp(() => auth = FakeAuthRepository());
  tearDown(() => auth.dispose());

  Future<void> pumpLogin(WidgetTester tester) => pumpRoutedPage(
    tester,
    location: AppRoutes.login,
    page: const LoginPage(),
    otherRoutes: [AppRoutes.register, AppRoutes.resetPassword],
    overrides: [authRepositoryProvider.overrideWithValue(auth)],
  );

  Finder field(String label) => find.widgetWithText(FluiTextField, label);

  testWidgets('empty submit shows kind validation messages', (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.text('Escribe tu correo.'), findsOneWidget);
    expect(find.text('Escribe tu contraseña.'), findsOneWidget);
    expect(auth.currentUser, isNull);
  });

  testWidgets('an incomplete email is flagged', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(field('Correo'), 'ana@correo');
    await tester.enterText(field('Contraseña'), 'secreta1');
    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.text('Revisa tu correo: parece incompleto.'), findsOneWidget);
  });

  testWidgets('wrong credentials show a friendly message', (tester) async {
    await auth.signUp(
      displayName: 'Ana',
      email: 'ana@correo.com',
      password: 'secreta1',
    );
    await auth.signOut();
    await pumpLogin(tester);

    await tester.enterText(field('Correo'), 'ana@correo.com');
    await tester.enterText(field('Contraseña'), 'otra-clave');
    await tester.tap(find.text('Entrar'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Ese correo y esa contraseña no coinciden. Prueba otra vez.'),
      findsOneWidget,
    );
  });

  testWidgets('valid credentials sign in', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(field('Correo'), 'ana@correo.com');
    await tester.enterText(field('Contraseña'), 'secreta1');
    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(auth.currentUser?.email, 'ana@correo.com');
  });

  testWidgets('links to password reset and register', (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.text('¿Olvidaste tu contraseña?'));
    await tester.pumpAndSettle();
    expect(find.text('route:/reset-password'), findsOneWidget);
  });

  testWidgets('links to register', (tester) async {
    await pumpLogin(tester);

    await tester.ensureVisible(find.text('Crear una cuenta'));
    await tester.tap(find.text('Crear una cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('route:/register'), findsOneWidget);
  });
}
