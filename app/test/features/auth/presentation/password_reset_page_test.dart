import 'package:flui/app/router/app_routes.dart';
import 'package:flui/features/auth/data/fake_auth_repository.dart';
import 'package:flui/features/auth/presentation/pages/password_reset_page.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/pump_router.dart';

void main() {
  late FakeAuthRepository auth;

  setUp(() => auth = FakeAuthRepository());
  tearDown(() => auth.dispose());

  Future<void> pumpReset(WidgetTester tester) => pumpRoutedPage(
    tester,
    location: AppRoutes.resetPassword,
    page: const PasswordResetPage(),
    otherRoutes: [AppRoutes.login],
    overrides: [authRepositoryProvider.overrideWithValue(auth)],
  );

  testWidgets('validates the email', (tester) async {
    await pumpReset(tester);

    await tester.tap(find.text('Enviar enlace'));
    await tester.pump();

    expect(find.text('Escribe tu correo.'), findsOneWidget);
    expect(auth.passwordResetEmails, isEmpty);
  });

  testWidgets('sends the link and confirms without revealing accounts', (
    tester,
  ) async {
    await pumpReset(tester);

    await tester.enterText(fluiField('Correo'), 'ana@correo.com');
    await tester.tap(find.text('Enviar enlace'));
    await tester.pump();

    expect(auth.passwordResetEmails, ['ana@correo.com']);
    expect(
      find.text(
        'Listo. Si ana@correo.com tiene una cuenta, te llegará un enlace en '
        'unos minutos.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('goes back to login', (tester) async {
    await pumpReset(tester);

    await tester.tap(find.text('Volver a entrar'));
    await tester.pumpAndSettle();

    expect(find.text('route:/login'), findsOneWidget);
  });
}
