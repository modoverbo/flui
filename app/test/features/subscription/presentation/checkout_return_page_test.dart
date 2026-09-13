import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/features/auth/data/fake_auth_repository.dart';
import 'package:flui/features/auth/domain/app_user.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/subscription/data/fake_subscription_repository.dart';
import 'package:flui/features/subscription/domain/access_status.dart';
import 'package:flui/features/subscription/presentation/pages/checkout_return_page.dart';
import 'package:flui/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_router.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeSubscriptionRepository subscriptions;
  late FixedClock clock;

  setUp(() {
    auth = FakeAuthRepository(
      initialUser: const AppUser(id: 'user-1', email: 'ana@correo.com'),
    );
    clock = FixedClock(DateTime(2026, 9, 13, 10));
    subscriptions = FakeSubscriptionRepository(
      clock: clock,
      currentUserId: () => auth.currentUser?.id,
    );
  });

  tearDown(() => auth.dispose());

  Future<void> pumpReturn(WidgetTester tester) => pumpRoutedPage(
    tester,
    location: AppRoutes.checkoutReturn,
    page: const CheckoutReturnPage(),
    otherRoutes: [AppRoutes.paywall],
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      subscriptionRepositoryProvider.overrideWithValue(subscriptions),
      clockProvider.overrideWithValue(clock),
      sleepProvider.overrideWithValue(
        (duration) async => clock.advance(duration),
      ),
    ],
  );

  testWidgets('shows the activating state while polling', (tester) async {
    subscriptions.completeCheckout();
    await pumpReturn(tester);

    expect(find.text('Activando tu prueba…'), findsOneWidget);
    expect(find.bySemanticsLabel('Activando tu prueba…'), findsWidgets);
  });

  testWidgets('after a minute without access offers retry and plans', (
    tester,
  ) async {
    await pumpReturn(tester);
    for (var i = 0; i < 40; i++) {
      await tester.pump();
    }

    expect(find.text('Está tardando más de lo normal'), findsOneWidget);

    subscriptions.grantAccess(const AccessStatus(hasAccess: true));
    await tester.tap(find.text('Volver a intentar'));
    await tester.pump();
    expect(find.text('Activando tu prueba…'), findsOneWidget);
  });

  testWidgets('Ver planes goes back to the paywall', (tester) async {
    await pumpReturn(tester);
    for (var i = 0; i < 40; i++) {
      await tester.pump();
    }

    await tester.tap(find.text('Ver planes'));
    await tester.pumpAndSettle();

    expect(find.text('route:/paywall'), findsOneWidget);
  });
}
