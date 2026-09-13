import 'package:flui/core/clock/clock.dart';
import 'package:flui/features/auth/data/fake_auth_repository.dart';
import 'package:flui/features/auth/domain/app_user.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/profile/presentation/progress_page.dart';
import 'package:flui/features/subscription/data/fake_subscription_repository.dart';
import 'package:flui/features/subscription/domain/access_status.dart';
import 'package:flui/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  late FakeAuthRepository auth;

  tearDown(() => auth.dispose());

  testWidgets('shows the name, trial end and sign out', (tester) async {
    auth = FakeAuthRepository(
      initialUser: const AppUser(
        id: 'user-1',
        email: 'ana@correo.com',
        displayName: 'Ana',
      ),
    );
    final subscriptions =
        FakeSubscriptionRepository(
          clock: FixedClock(DateTime(2026, 9, 13)),
          currentUserId: () => auth.currentUser?.id,
        )..grantAccess(
          AccessStatus(
            hasAccess: true,
            entitlementStatus: EntitlementStatus.trialing,
            trialEndsAt: DateTime(2026, 9, 20),
          ),
        );

    await tester.pumpFlui(
      const ProgressPage(),
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        subscriptionRepositoryProvider.overrideWithValue(subscriptions),
      ],
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(
      find.text('Prueba gratis hasta el 20 de septiembre'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pump();
    expect(auth.currentUser, isNull);
  });
}
