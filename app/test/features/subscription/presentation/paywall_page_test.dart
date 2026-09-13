import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/features/auth/data/fake_auth_repository.dart';
import 'package:flui/features/auth/domain/app_user.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/subscription/data/fake_checkout_launcher.dart';
import 'package:flui/features/subscription/data/fake_subscription_repository.dart';
import 'package:flui/features/subscription/presentation/pages/paywall_page.dart';
import 'package:flui/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../helpers/pump_router.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeSubscriptionRepository subscriptions;
  late FakeCheckoutLauncher launcher;
  late int returns;

  setUp(() {
    auth = FakeAuthRepository(
      initialUser: const AppUser(id: 'user-1', email: 'ana@correo.com'),
    );
    subscriptions = FakeSubscriptionRepository(
      clock: FixedClock(DateTime(2026, 9, 13)),
      currentUserId: () => auth.currentUser?.id,
    );
    returns = 0;
    launcher = FakeCheckoutLauncher(
      subscriptions: subscriptions,
      onReturn: () => returns++,
    );
  });

  tearDown(() => auth.dispose());

  Future<void> pumpPaywall(WidgetTester tester) async {
    await pumpRoutedPage(
      tester,
      location: AppRoutes.paywall,
      page: const PaywallPage(),
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        subscriptionRepositoryProvider.overrideWithValue(subscriptions),
        checkoutLauncherProvider.overrideWithValue(launcher),
      ],
      surfaceSize: const Size(400, 1100),
    );
    await tester.pump();
  }

  testWidgets('renders the trial promise and both plans', (tester) async {
    await pumpPaywall(tester);

    expect(find.text('Empieza tus 7 días gratis'), findsOneWidget);
    expect(
      find.text(
        'Hoy no te cobramos nada. Tu plan empieza el día 8. '
        'Cancela cuando quieras.',
      ),
      findsOneWidget,
    );
    expect(find.text('Mensual'), findsOneWidget);
    expect(find.text(r'US$ 9.99 al mes'), findsOneWidget);
    expect(find.text('Trimestral'), findsOneWidget);
    expect(find.text(r'US$ 24.99 cada 3 meses'), findsOneWidget);
    expect(find.text(r'Equivale a US$ 8.33 al mes'), findsOneWidget);
    expect(find.text('Ahorra 17%'), findsOneWidget);
    expect(find.text('Recomendado'), findsOneWidget);
    expect(find.text('Empezar prueba gratis'), findsOneWidget);
  });

  testWidgets('quarterly is preselected and the CTA starts its checkout', (
    tester,
  ) async {
    await pumpPaywall(tester);

    await tester.tap(find.text('Empezar prueba gratis'));
    await tester.pump();
    await tester.pump();

    expect(subscriptions.checkoutRequests, ['quarterly']);
    expect(launcher.openedUrls.single.path, contains('quarterly'));
    expect(returns, 1);
  });

  testWidgets('choosing monthly checks out monthly', (tester) async {
    await pumpPaywall(tester);

    await tester.tap(find.text('Mensual'));
    await tester.pump();
    await tester.tap(find.text('Empezar prueba gratis'));
    await tester.pump();
    await tester.pump();

    expect(subscriptions.checkoutRequests, ['monthly']);
  });

  testWidgets('shows a friendly message when checkout fails', (tester) async {
    await pumpPaywall(tester);
    subscriptions.nextFailure = const NetworkFailure();

    await tester.tap(find.text('Empezar prueba gratis'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Sin conexión. Revisa tu internet y vuelve a intentarlo.'),
      findsOneWidget,
    );
    expect(launcher.openedUrls, isEmpty);
  });

  testWidgets('offers a retry when plans cannot load', (tester) async {
    subscriptions.nextFailure = const NetworkFailure();
    await pumpPaywall(tester);

    expect(find.text('No pudimos cargar los planes.'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Mensual'), findsOneWidget);
  });

  testWidgets('sign out is available', (tester) async {
    await pumpPaywall(tester);

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pump();

    expect(auth.currentUser, isNull);
  });
}
