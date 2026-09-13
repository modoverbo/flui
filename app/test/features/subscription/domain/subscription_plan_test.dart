import 'package:flui/features/subscription/domain/subscription_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const monthly = SubscriptionPlan(
    id: 'monthly',
    billingPeriodDays: 30,
    priceCents: 999,
    currency: 'USD',
    label: 'Mensual',
    sortOrder: 1,
  );
  const quarterly = SubscriptionPlan(
    id: 'quarterly',
    billingPeriodDays: 90,
    priceCents: 2499,
    currency: 'USD',
    label: 'Trimestral',
    savingsLabel: 'Ahorra 17%',
    sortOrder: 2,
  );

  test('months rounds the billing period to whole months', () {
    expect(monthly.months, 1);
    expect(quarterly.months, 3);
    expect(monthly.copyWith(billingPeriodDays: 365).months, 12);
  });

  test('monthly equivalent spreads the price over 30-day months', () {
    expect(monthly.monthlyEquivalentCents, 999);
    expect(quarterly.monthlyEquivalentCents, 833);
  });

  group('recommendedPlanId', () {
    test('prefers the plan with a savings label', () {
      expect(recommendedPlanId([monthly, quarterly]), 'quarterly');
    });

    test('falls back to the longest billing period', () {
      final plans = [monthly, quarterly.copyWith(savingsLabel: null)];
      expect(recommendedPlanId(plans), 'quarterly');
    });

    test('is null without plans', () {
      expect(recommendedPlanId(const []), isNull);
    });
  });
}
