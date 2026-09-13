import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/features/auth/data/fake_auth_repository.dart';
import 'package:flui/features/auth/domain/app_user.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/subscription/data/fake_checkout_launcher.dart';
import 'package:flui/features/subscription/data/fake_subscription_repository.dart';
import 'package:flui/features/subscription/domain/access_gate.dart';
import 'package:flui/features/subscription/domain/access_status.dart';
import 'package:flui/features/subscription/domain/checkout_launcher.dart';
import 'package:flui/features/subscription/presentation/controllers/checkout_controller.dart';
import 'package:flui/features/subscription/presentation/controllers/checkout_return_controller.dart';
import 'package:flui/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_container.dart';

class _RefusingLauncher implements CheckoutLauncher {
  @override
  Future<bool> open(Uri purchaseUrl) async => false;
}

void main() {
  const user = AppUser(id: 'user-1', email: 'ana@correo.com');
  late FakeAuthRepository auth;
  late FakeSubscriptionRepository subscriptions;
  late FixedClock clock;
  late List<Duration> sleeps;
  late int returns;
  late ProviderContainer container;

  ProviderContainer build({CheckoutLauncher? launcher}) {
    return createTestContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        subscriptionRepositoryProvider.overrideWithValue(subscriptions),
        checkoutLauncherProvider.overrideWithValue(
          launcher ??
              FakeCheckoutLauncher(
                subscriptions: subscriptions,
                onReturn: () => returns++,
              ),
        ),
        clockProvider.overrideWithValue(clock),
        sleepProvider.overrideWithValue((duration) async {
          sleeps.add(duration);
          clock.advance(duration);
        }),
      ],
    );
  }

  setUp(() {
    auth = FakeAuthRepository(initialUser: user);
    clock = FixedClock(DateTime(2026, 9, 13, 10));
    subscriptions = FakeSubscriptionRepository(
      clock: clock,
      currentUserId: () => auth.currentUser?.id,
    );
    sleeps = [];
    returns = 0;
    container = build();
  });

  tearDown(() => auth.dispose());

  void keepAlive(ProviderListenable<Object?> provider) =>
      container.listen(provider, (_, _) {});

  group('subscriptionPlansProvider', () {
    test('loads the active plans', () async {
      keepAlive(subscriptionPlansProvider);

      final plans = await container.read(subscriptionPlansProvider.future);

      expect(plans.map((plan) => plan.id), ['monthly', 'quarterly']);
    });

    test('surfaces failures as errors', () async {
      keepAlive(subscriptionPlansProvider);
      subscriptions.nextFailure = const NetworkFailure();

      await expectLater(
        container.read(subscriptionPlansProvider.future),
        throwsA(const NetworkFailure()),
      );
    });
  });

  group('accessGateProvider', () {
    test('is unknown while loading, then denied without entitlement', () async {
      keepAlive(accessGateProvider);
      expect(container.read(accessGateProvider), AccessGate.unknown);

      await container.read(authUserProvider.future);
      await container.read(accessStatusControllerProvider(user.id).future);

      expect(container.read(accessGateProvider), AccessGate.denied);
    });

    test('is granted with an entitlement', () async {
      subscriptions.grantAccess(const AccessStatus(hasAccess: true));
      keepAlive(accessGateProvider);

      await container.read(authUserProvider.future);
      await container.read(accessStatusControllerProvider(user.id).future);

      expect(container.read(accessGateProvider), AccessGate.granted);
    });

    test('is error when my_access fails', () async {
      subscriptions.nextFailure = const NetworkFailure();
      keepAlive(accessGateProvider);

      await container.read(authUserProvider.future);
      await expectLater(
        container.read(accessStatusControllerProvider(user.id).future),
        throwsA(const NetworkFailure()),
      );

      expect(container.read(accessGateProvider), AccessGate.error);
    });

    test('keeps the known gate while refreshing', () async {
      subscriptions.grantAccess(const AccessStatus(hasAccess: true));
      keepAlive(accessGateProvider);
      await container.read(authUserProvider.future);
      await container.read(accessStatusControllerProvider(user.id).future);

      final refresh = container
          .read(accessStatusControllerProvider(user.id).notifier)
          .refresh();

      expect(container.read(accessGateProvider), AccessGate.granted);
      await refresh;
    });
  });

  group('CheckoutController', () {
    test('creates the checkout and opens it', () async {
      keepAlive(checkoutControllerProvider);

      await container
          .read(checkoutControllerProvider.notifier)
          .start('quarterly');

      final state = container.read(checkoutControllerProvider);
      expect(state.status, CheckoutStatus.redirecting);
      expect(state.planId, 'quarterly');
      expect(subscriptions.checkoutRequests, ['quarterly']);
      expect(returns, 1);
    });

    test('409 refreshes access so the router can leave the paywall', () async {
      keepAlive(checkoutControllerProvider);
      keepAlive(accessGateProvider);
      await container.read(authUserProvider.future);
      await container.read(accessStatusControllerProvider(user.id).future);
      subscriptions.grantAccess(const AccessStatus(hasAccess: true));

      await container
          .read(checkoutControllerProvider.notifier)
          .start('monthly');

      expect(
        container.read(checkoutControllerProvider).status,
        CheckoutStatus.alreadySubscribed,
      );
      expect(container.read(accessGateProvider), AccessGate.granted);
    });

    test('other failures are kept for the paywall message', () async {
      keepAlive(checkoutControllerProvider);
      subscriptions.nextFailure = const SubscriptionFailure(
        SubscriptionErrorCode.checkoutUnavailable,
      );

      await container
          .read(checkoutControllerProvider.notifier)
          .start('monthly');

      final state = container.read(checkoutControllerProvider);
      expect(state.status, CheckoutStatus.failed);
      expect(
        state.failure,
        const SubscriptionFailure(SubscriptionErrorCode.checkoutUnavailable),
      );
    });

    test('a launcher that cannot open fails', () async {
      container = build(launcher: _RefusingLauncher());
      keepAlive(checkoutControllerProvider);

      await container
          .read(checkoutControllerProvider.notifier)
          .start('monthly');

      expect(
        container.read(checkoutControllerProvider).failure,
        const SubscriptionFailure(SubscriptionErrorCode.couldNotOpenCheckout),
      );
    });

    test('ignores taps while a checkout is being created', () async {
      keepAlive(checkoutControllerProvider);
      final controller = container.read(checkoutControllerProvider.notifier);

      await Future.wait([
        controller.start('monthly'),
        controller.start('quarterly'),
      ]);

      expect(subscriptions.checkoutRequests, ['monthly']);
    });
  });

  group('CheckoutReturnController', () {
    Future<void> settle() async {
      for (var i = 0; i < 100; i++) {
        await pumpEventQueue();
      }
    }

    test('polls until access appears and publishes it', () async {
      keepAlive(accessGateProvider);
      await container.read(authUserProvider.future);
      await container.read(accessStatusControllerProvider(user.id).future);
      subscriptions.completeCheckout();

      keepAlive(checkoutReturnControllerProvider);
      expect(
        container.read(checkoutReturnControllerProvider),
        CheckoutReturnState.activating,
      );
      await settle();

      expect(
        container.read(checkoutReturnControllerProvider),
        CheckoutReturnState.activated,
      );
      expect(sleeps, [const Duration(seconds: 2)]);
      expect(container.read(accessGateProvider), AccessGate.granted);
    });

    test('times out after about a minute and can retry', () async {
      // Riverpod pauses providers without listeners; keep auth active.
      keepAlive(authUserProvider);
      await container.read(authUserProvider.future);
      keepAlive(checkoutReturnControllerProvider);
      await settle();

      expect(
        container.read(checkoutReturnControllerProvider),
        CheckoutReturnState.timedOut,
      );
      expect(sleeps, hasLength(30));

      subscriptions.grantAccess(const AccessStatus(hasAccess: true));
      container.read(checkoutReturnControllerProvider.notifier).retry();
      expect(
        container.read(checkoutReturnControllerProvider),
        CheckoutReturnState.activating,
      );
      await settle();

      expect(
        container.read(checkoutReturnControllerProvider),
        CheckoutReturnState.activated,
      );
    });
  });
}
