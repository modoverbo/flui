import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/features/subscription/data/fake_checkout_launcher.dart';
import 'package:flui/features/subscription/data/fake_subscription_repository.dart';
import 'package:flui/features/subscription/domain/access_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeSubscriptionRepository repository;
  late FixedClock clock;
  String? userId = 'user-1';

  setUp(() {
    userId = 'user-1';
    clock = FixedClock(DateTime(2026, 9, 13, 10));
    repository = FakeSubscriptionRepository(
      clock: clock,
      currentUserId: () => userId,
    );
  });

  test('lists the seed plans ordered by sort order', () async {
    final plans = (await repository.fetchPlans()).valueOrNull!;

    expect(plans.map((plan) => plan.id), ['monthly', 'quarterly']);
    expect(plans.last.savingsLabel, isNotNull);
  });

  test('new users have no access', () async {
    expect((await repository.fetchAccess()).valueOrNull, AccessStatus.none);
  });

  test('checkout returns a purchase url for a known plan', () async {
    final result = await repository.createCheckout(planId: 'quarterly');

    expect(result.valueOrNull?.path, contains('quarterly'));
    expect(repository.checkoutRequests, ['quarterly']);
  });

  test('checkout for an unknown plan fails', () async {
    final result = await repository.createCheckout(planId: 'yearly');

    expect(
      result.failureOrNull,
      const SubscriptionFailure(SubscriptionErrorCode.unknownPlan),
    );
  });

  test(
    'completing checkout grants a 7-day trial after the webhook lag',
    () async {
      repository.completeCheckout();

      expect((await repository.fetchAccess()).valueOrNull?.hasAccess, isFalse);
      final access = (await repository.fetchAccess()).valueOrNull!;
      expect(access.hasAccess, isTrue);
      expect(access.entitlementStatus, EntitlementStatus.trialing);
      expect(access.trialEndsAt, DateTime(2026, 9, 20, 10));
    },
  );

  test('checkout while having access is rejected (409)', () async {
    repository.grantAccess(
      const AccessStatus(
        hasAccess: true,
        entitlementStatus: EntitlementStatus.active,
      ),
    );

    final result = await repository.createCheckout(planId: 'monthly');

    expect(
      result.failureOrNull,
      const SubscriptionFailure(SubscriptionErrorCode.alreadySubscribed),
    );
  });

  test('access is stored per user', () async {
    repository.grantAccess(const AccessStatus(hasAccess: true));
    userId = 'user-2';

    expect((await repository.fetchAccess()).valueOrNull?.hasAccess, isFalse);
  });

  test('scheduled failures are returned once', () async {
    repository.nextFailure = const NetworkFailure();

    expect(
      (await repository.fetchPlans()).failureOrNull,
      const NetworkFailure(),
    );
    expect((await repository.fetchPlans()).isOk, isTrue);
  });

  test('fake launcher completes the checkout and returns to the app', () async {
    var returned = 0;
    final launcher = FakeCheckoutLauncher(
      subscriptions: repository,
      onReturn: () => returned++,
    );
    final url = Uri.parse('https://fake.flui.app/checkout/monthly');

    final opened = await launcher.open(url);

    expect(opened, isTrue);
    expect(launcher.openedUrls, [url]);
    expect(returned, 1);
    await repository.fetchAccess();
    expect((await repository.fetchAccess()).valueOrNull?.hasAccess, isTrue);
  });
}
