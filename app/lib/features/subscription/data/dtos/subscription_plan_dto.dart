import 'package:flui/features/subscription/domain/subscription_plan.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'subscription_plan_dto.freezed.dart';
part 'subscription_plan_dto.g.dart';

/// A row of `public.subscription_plans`.
@freezed
abstract class SubscriptionPlanDto with _$SubscriptionPlanDto {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory({
    required String id,
    required int billingPeriodDays,
    required int priceCents,
    required String currency,
    required String label,
    String? savingsLabel,
    @Default(0) int sortOrder,
  }) = _SubscriptionPlanDto;

  factory fromJson(Map<String, dynamic> json) =>
      _$SubscriptionPlanDtoFromJson(json);

  const new _();

  /// Columns to select, matching the fields above.
  static const columns =
      'id, billing_period_days, price_cents, currency, label, savings_label, '
      'sort_order';

  SubscriptionPlan toDomain() => SubscriptionPlan(
    id: id,
    billingPeriodDays: billingPeriodDays,
    priceCents: priceCents,
    currency: currency,
    label: label,
    savingsLabel: savingsLabel,
    sortOrder: sortOrder,
  );
}
