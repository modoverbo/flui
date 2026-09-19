import 'package:flui/app/router/app_router.dart';
import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/features/auth/domain/app_user.dart';
import 'package:flui/features/daily/presentation/providers/daily_providers.dart';
import 'package:flui/features/subscription/domain/access_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../integration_test/support/app_harness.dart';

void main() {
  const ana = AppUser(
    id: 'ignored',
    email: 'ana@correo.com',
    displayName: 'Ana',
  );
  const trialing = AccessStatus(
    hasAccess: true,
    entitlementStatus: EntitlementStatus.trialing,
  );

  String location(AppHarness harness) => harness.container
      .read(goRouterProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .toString();

  testWidgets('signed out users land on welcome', (tester) async {
    final harness = AppHarness();
    await harness.pumpApp(tester);

    expect(location(harness), AppRoutes.welcome);
    expect(find.text('Empezar'), findsOneWidget);
  });

  testWidgets('signed in users without access land on the paywall', (
    tester,
  ) async {
    final harness = AppHarness(signedInAs: ana);
    await harness.pumpApp(tester);

    expect(location(harness), AppRoutes.paywall);
  });

  testWidgets('subscribers with a plan land on Hoy and can switch tabs', (
    tester,
  ) async {
    final harness = AppHarness(signedInAs: ana, access: trialing);
    await harness.pumpApp(tester, arrange: (h) => h.planToday());

    expect(location(harness), AppRoutes.today);
    await tester.tap(find.text('Palabras'));
    await tester.pumpAndSettle();

    expect(location(harness), AppRoutes.words);
    expect(find.text('Tu repertorio empieza hoy.'), findsOneWidget);
  });

  testWidgets('the time budget is asked once per local day', (tester) async {
    final harness = AppHarness(signedInAs: ana, access: trialing);
    await harness.pumpApp(tester);

    expect(location(harness), AppRoutes.timeBudget);
    harness.container.read(goRouterProvider).go(AppRoutes.words);
    await tester.pumpAndSettle();
    expect(location(harness), AppRoutes.timeBudget);

    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();
    expect(location(harness), AppRoutes.today);

    harness.container.read(goRouterProvider).go(AppRoutes.words);
    await tester.pumpAndSettle();
    expect(location(harness), AppRoutes.words);

    // A new local day asks again.
    harness.clock.advance(const Duration(days: 1));
    harness.container.invalidate(dailyGateProvider);
    await tester.pumpAndSettle();
    harness.container.read(goRouterProvider).go(AppRoutes.today);
    await tester.pumpAndSettle();
    expect(location(harness), AppRoutes.timeBudget);
  });

  testWidgets('deep links wait for the plan, then continue', (tester) async {
    final harness = AppHarness(signedInAs: ana, access: trialing);
    await harness.pumpApp(
      tester,
      initialLocation: AppRoutes.words,
      arrange: (h) => h.planToday(),
    );

    expect(location(harness), AppRoutes.words);
    expect(find.text('Tu repertorio empieza hoy.'), findsOneWidget);
  });

  testWidgets('wide screens show the navigation rail', (tester) async {
    final harness = AppHarness(signedInAs: ana, access: trialing);
    await harness.pumpApp(
      tester,
      size: const Size(1280, 800),
      arrange: (h) => h.planToday(),
    );

    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('a reloaded /checkout/return waits for access, then continues', (
    tester,
  ) async {
    final harness = AppHarness(signedInAs: ana);
    await harness.pumpApp(
      tester,
      initialLocation: AppRoutes.checkoutReturn,
      arrange: (harness) => harness.subscriptions.completeCheckout(),
    );

    expect(location(harness), AppRoutes.timeBudget);
    expect(find.text('¿Cuánto tiempo tienes hoy?'), findsOneWidget);
  });

  testWidgets('/checkout/return without a webhook ends in a retry', (
    tester,
  ) async {
    final harness = AppHarness(signedInAs: ana);
    await harness.pumpApp(tester, initialLocation: AppRoutes.checkoutReturn);

    expect(location(harness), AppRoutes.checkoutReturn);
    expect(find.text('Está tardando más de lo normal'), findsOneWidget);
  });

  testWidgets('when my_access fails the splash offers a retry', (tester) async {
    final harness = AppHarness(signedInAs: ana, access: trialing);
    await harness.pumpApp(
      tester,
      arrange: (harness) async {
        await harness.planToday();
        harness.subscriptions.nextFailure = const NetworkFailure();
      },
    );

    expect(location(harness), startsWith(AppRoutes.splash));
    expect(find.text('No pudimos conectar con flui.'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(location(harness), AppRoutes.today);
  });

  testWidgets('signing out from Tu progreso returns to welcome', (
    tester,
  ) async {
    final harness = AppHarness(signedInAs: ana, access: trialing);
    await harness.pumpApp(tester, initialLocation: AppRoutes.progress);

    // Tu progreso stays reachable before choosing today's time.
    expect(location(harness), AppRoutes.progress);
    await tester.ensureVisible(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(location(harness), AppRoutes.welcome);
  });

  group('Habla, the fourth shell branch', () {
    testWidgets(
      'the old /speaking/challenge deep link still resolves, inside the shell',
      (tester) async {
        final harness = AppHarness(signedInAs: ana, access: trialing);
        await harness.pumpApp(
          tester,
          initialLocation: AppRoutes.speakingChallenge,
          arrange: (h) => h.planToday(),
        );

        expect(location(harness), AppRoutes.speakingChallenge);
        // Still inside the shell: the tab bar renders, Habla selected, and
        // the landing content is the challenge's own "ready" phase.
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.text('Habla'), findsOneWidget);
        expect(find.text('Empezar a hablar'), findsOneWidget);
      },
    );

    testWidgets('switching to Habla from another tab lands on "ready"', (
      tester,
    ) async {
      final harness = AppHarness(signedInAs: ana, access: trialing);
      await harness.pumpApp(tester, arrange: (h) => h.planToday());

      expect(location(harness), AppRoutes.today);
      await tester.tap(find.text('Habla'));
      await tester.pumpAndSettle();

      expect(location(harness), AppRoutes.speakingChallenge);
      expect(find.text('Empezar a hablar'), findsOneWidget);
    });

    testWidgets(
      'starting a challenge takes over the full screen, like /session',
      (tester) async {
        final harness = AppHarness(signedInAs: ana, access: trialing);
        await harness.pumpApp(
          tester,
          initialLocation: AppRoutes.speakingChallenge,
          arrange: (h) => h.planToday(),
        );

        expect(find.byType(NavigationBar), findsOneWidget);
        await tester.tap(find.text('Empezar a hablar'));
        await tester.pumpAndSettle();

        expect(location(harness), AppRoutes.speakingChallengeLive);
        // Full-screen take-over: the shell's own chrome is gone.
        expect(find.byType(NavigationBar), findsNothing);
      },
    );
  });
}
