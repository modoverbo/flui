import 'package:freezed_annotation/freezed_annotation.dart';

part 'subscription_plan.freezed.dart';

/// A purchasable plan (`subscription_plans` row). Prices are in cents.
@freezed
abstract class SubscriptionPlan with _$SubscriptionPlan {
  const factory({
    required String id,
    required int billingPeriodDays,
    required int priceCents,
    required String currency,
    required String label,
    String? savingsLabel,
    @Default(0) int sortOrder,
  }) = _SubscriptionPlan;

  const new _();

  /// Billing period in whole months (30 days per month).
  int get months => (billingPeriodDays / 30).round();

  /// Price per 30 days, rounded to the cent.
  int get monthlyEquivalentCents =>
      (priceCents * 30 / billingPeriodDays).round();
}

/// The plan to highlight: the one with savings, else the longest period.
String? recommendedPlanId(List<SubscriptionPlan> plans) {
  if (plans.isEmpty) return null;
  final withSavings = plans.where((plan) => plan.savingsLabel != null);
  if (withSavings.isNotEmpty) return withSavings.first.id;
  final longest = plans.reduce(
    (a, b) => b.billingPeriodDays > a.billingPeriodDays ? b : a,
  );
  return longest.id;
}
