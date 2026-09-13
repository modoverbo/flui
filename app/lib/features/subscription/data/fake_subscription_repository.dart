import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/features/subscription/domain/access_status.dart';
import 'package:flui/features/subscription/domain/subscription_plan.dart';
import 'package:flui/features/subscription/domain/subscription_repository.dart';

/// In-memory plans and entitlements for `BACKEND=fake` and tests.
///
/// [completeCheckout] simulates the Whop webhook: access appears after
/// [webhookLagPolls] calls to [fetchAccess], like the real redirect race.
final class FakeSubscriptionRepository implements SubscriptionRepository {
  new({
    required this.clock,
    required this.currentUserId,
    this.plans = seedPlans,
    this.latency = Duration.zero,
    this.webhookLagPolls = 1,
  });

  /// Same plans as `supabase/seed.sql` (kept in sync by a test).
  static const seedPlans = [
    SubscriptionPlan(
      id: 'monthly',
      billingPeriodDays: 30,
      priceCents: 699,
      currency: 'USD',
      label: 'Mensual',
      sortOrder: 1,
    ),
    SubscriptionPlan(
      id: 'quarterly',
      billingPeriodDays: 90,
      priceCents: 1615,
      currency: 'USD',
      label: 'Trimestral',
      savingsLabel: 'Ahorra 23%',
      sortOrder: 2,
    ),
  ];

  final Clock clock;
  final String? Function() currentUserId;
  final List<SubscriptionPlan> plans;
  final Duration latency;
  final int webhookLagPolls;

  final List<String> checkoutRequests = [];
  final _access = <String, AccessStatus>{};
  final _pendingActivation = <String, int>{};

  /// Returned once by the next call, then cleared.
  Failure? nextFailure;

  /// Grants [status] to the current user right away.
  void grantAccess(AccessStatus status) {
    final userId = currentUserId();
    if (userId != null) _access[userId] = status;
  }

  /// Simulates a finished Whop checkout for the current user.
  void completeCheckout() {
    final userId = currentUserId();
    if (userId != null) _pendingActivation[userId] = webhookLagPolls;
  }

  @override
  Future<Result<List<SubscriptionPlan>>> fetchPlans() async {
    await _simulateLatency();
    if (_takeFailure() case final failure?) return Result.err(failure);
    final sorted = [...plans]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return Result.ok(sorted);
  }

  @override
  Future<Result<AccessStatus>> fetchAccess() async {
    await _simulateLatency();
    if (_takeFailure() case final failure?) return Result.err(failure);
    final userId = currentUserId();
    if (userId == null) {
      return const Result.err(
        SubscriptionFailure(SubscriptionErrorCode.unauthorized),
      );
    }

    final pending = _pendingActivation[userId];
    if (pending != null) {
      if (pending <= 0) {
        _pendingActivation.remove(userId);
        final trialEnd = clock.now().add(const Duration(days: 7));
        _access[userId] = AccessStatus(
          hasAccess: true,
          entitlementStatus: EntitlementStatus.trialing,
          currentPeriodEnd: trialEnd,
          trialEndsAt: trialEnd,
        );
      } else {
        _pendingActivation[userId] = pending - 1;
      }
    }
    return Result.ok(_access[userId] ?? AccessStatus.none);
  }

  @override
  Future<Result<Uri>> createCheckout({required String planId}) async {
    await _simulateLatency();
    if (_takeFailure() case final failure?) return Result.err(failure);
    checkoutRequests.add(planId);

    if (!plans.any((plan) => plan.id == planId)) {
      return const Result.err(
        SubscriptionFailure(SubscriptionErrorCode.unknownPlan),
      );
    }
    final userId = currentUserId();
    if (userId != null && (_access[userId]?.hasAccess ?? false)) {
      return const Result.err(
        SubscriptionFailure(SubscriptionErrorCode.alreadySubscribed),
      );
    }
    return Result.ok(Uri.parse('https://fake.flui.app/checkout/$planId'));
  }

  Failure? _takeFailure() {
    final failure = nextFailure;
    nextFailure = null;
    return failure;
  }

  Future<void> _simulateLatency() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }
}
