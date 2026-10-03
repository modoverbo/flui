import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/clock/clock.dart';
import 'package:flui/features/onboarding/domain/onboarding_store.dart';
import 'package:flui/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:flui/features/subscription/data/fake_subscription_repository.dart';
import 'package:flui/features/subscription/presentation/pages/plan_preview_page.dart';
import 'package:flui/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/pump_router.dart';

void main() {
  late InMemoryOnboardingStore store;

  setUp(() => store = InMemoryOnboardingStore());

  Future<GoRouter> pumpPlan(WidgetTester tester) async {
    final router = await pumpRoutedPage(
      tester,
      location: AppRoutes.plan,
      page: const PlanPreviewPage(),
      otherRoutes: [AppRoutes.register],
      overrides: [
        subscriptionRepositoryProvider.overrideWithValue(
          FakeSubscriptionRepository(
            clock: FixedClock(DateTime(2026, 9, 13, 10)),
            currentUserId: () => null,
          ),
        ),
        onboardingStoreProvider.overrideWithValue(store),
      ],
    );
    await tester.pumpAndSettle();
    return router;
  }

  /// Walks the three paywall steps to the final "create account" tap,
  /// relying on `PaywallFlow`'s own recommended-plan fallback so a plan is
  /// always selected.
  Future<void> chooseAndFinish(WidgetTester tester) async {
    await tester.tap(find.text('Seguir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seguir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear mi cuenta'));
    await tester.pumpAndSettle();
  }

  testWidgets('finishing the plan preview pushes register, so the Android back '
      'button returns to the plan instead of exiting the app', (tester) async {
    final router = await pumpPlan(tester);

    await chooseAndFinish(tester);

    expect(find.text('route:/register'), findsOneWidget);
    // A push keeps the plan preview underneath on the Navigator stack;
    // a go() would have replaced it, leaving nothing for the system
    // back button to pop to.
    expect(router.routerDelegate.currentConfiguration.matches, hasLength(2));
    expect(router.routerDelegate.canPop(), isTrue);

    await router.routerDelegate.popRoute();
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.matches, hasLength(1));
    expect(find.text('route:/register'), findsNothing);
  });
}
