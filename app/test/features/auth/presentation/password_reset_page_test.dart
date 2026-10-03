import 'dart:async';

import 'package:flui/app/router/app_routes.dart';
import 'package:flui/features/auth/data/fake_auth_repository.dart';
import 'package:flui/features/auth/presentation/pages/password_reset_page.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/pump_router.dart';

void main() {
  late FakeAuthRepository auth;

  setUp(() => auth = FakeAuthRepository());
  tearDown(() => auth.dispose());

  Future<GoRouter> pumpReset(WidgetTester tester) => pumpRoutedPage(
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

  testWidgets(
    'when reached by pushing (as from login), "Volver a entrar" pops to '
    'whatever is actually underneath instead of a hardcoded go() to login',
    (tester) async {
      // Start on an unrelated stub ("welcome") underneath, then push the
      // real password-reset page on top of it — the one-page-deep shape
      // login's (now pushed) navigation produces. If the handler still
      // did a hardcoded `go(login)` instead of popping, we'd land on a
      // fresh login stub instead of the welcome stub genuinely underneath.
      final router = await pumpRoutedPage(
        tester,
        location: AppRoutes.resetPassword,
        page: const PasswordResetPage(),
        otherRoutes: [AppRoutes.login, AppRoutes.welcome],
        initialLocation: AppRoutes.welcome,
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
      );
      expect(find.text('route:/welcome'), findsOneWidget);

      // `push()`'s Future only completes once the pushed page is popped,
      // so it must not be awaited here (matches how the app itself never
      // awaits a push from a button handler). Bounded pumps, not
      // pumpAndSettle: a focused field's blinking caret schedules frames
      // forever.
      unawaited(router.push(AppRoutes.resetPassword));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(router.routerDelegate.currentConfiguration.matches, hasLength(2));
      expect(router.routerDelegate.canPop(), isTrue);

      await tester.tap(find.text('Volver a entrar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(router.routerDelegate.currentConfiguration.matches, hasLength(1));
      expect(find.text('route:/welcome'), findsOneWidget);
      expect(find.text('route:/login'), findsNothing);
    },
  );
}
