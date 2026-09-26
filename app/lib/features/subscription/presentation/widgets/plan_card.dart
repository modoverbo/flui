import 'package:flui/core/l10n/formatters.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_motion.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_type_scale.dart';
import 'package:flui/features/subscription/domain/subscription_plan.dart';
import 'package:material_ui/material_ui.dart';

/// A plan on the paywall.
///
/// Plans share one hierarchy so catalog prices and billing terms are easy to
/// compare. Recommendation is conveyed by ordering; the selected state is
/// explicit and independent from that recommendation. Prices always come
/// from `subscription_plans`.
class PlanCard extends StatelessWidget {
  const new({
    required this.plan,
    required this.selected,
    required this.recommended,
    required this.onSelected,
    super.key,
  });

  final SubscriptionPlan plan;
  final bool selected;

  /// The catalog's recommendation; the surrounding list controls ordering.
  final bool recommended;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    final price = formatPrice(plan.priceCents, plan.currency);
    final priceText = switch (plan.months) {
      1 => l10n.planPriceMonthly(price),
      final months when plan.billingPeriodDays % 30 == 0 =>
        l10n.planPriceMonths(price, months),
      _ => l10n.planPriceDays(price, plan.billingPeriodDays),
    };
    final savingsLabel = plan.savingsLabel;
    final monthly = plan.months > 1
        ? l10n.planMonthlyEquivalent(
            formatPrice(plan.monthlyEquivalentCents, plan.currency),
          )
        : null;

    final card = Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      label: [plan.label, priceText, ?monthly, ?savingsLabel].join('. '),
      onTap: onSelected,
      excludeSemantics: true,
      child: Material(
        animationDuration: FluiMotion.resolve(
          context,
          const Duration(milliseconds: 160),
        ),
        color: selected ? FluiColors.greenTint : FluiColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: FluiRadii.cardAll,
          side: selected
              ? const BorderSide(color: FluiColors.greenDeep, width: 2)
              : const BorderSide(color: FluiColors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: FluiRadii.cardAll,
          focusColor: FluiColors.greenDeep.withValues(alpha: 0.16),
          splashColor: FluiColors.greenDeep.withValues(alpha: 0.16),
          onTap: onSelected,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: FluiSpacing.minTapTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.all(FluiSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          plan.label,
                          style: type.titleM.copyWith(
                            fontWeight: FontWeight.w600,
                            color: FluiColors.charcoal,
                          ),
                        ),
                      ),
                      _SelectionMark(selected: selected),
                    ],
                  ),
                  if (selected) ...[
                    const SizedBox(height: FluiSpacing.xxs),
                    Text(
                      l10n.paywallPlanSelected,
                      style: FluiTypeScale.compact.label.copyWith(
                        color: FluiColors.greenDeep,
                      ),
                    ),
                  ],
                  const SizedBox(height: FluiSpacing.xs),
                  Text(
                    priceText,
                    style: type.bodyL.copyWith(color: FluiColors.charcoal),
                  ),
                  if (monthly != null)
                    Text(
                      monthly,
                      style: type.body.copyWith(color: FluiColors.gray),
                    ),
                  if (savingsLabel != null) ...[
                    const SizedBox(height: FluiSpacing.xs),
                    _SavingsBadge(label: savingsLabel),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return card;
  }
}

class _SavingsBadge extends StatelessWidget {
  const new({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: FluiColors.yellowElectric,
        borderRadius: FluiRadii.chipAll,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          FluiTypeScale.labelText(label),
          // Yellow always carries charcoal.
          style: FluiTypeScale.compact.label.copyWith(
            color: FluiColors.charcoal,
          ),
          semanticsLabel: label,
        ),
      ),
    );
  }
}

class _SelectionMark extends StatelessWidget {
  const new({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 24,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? FluiColors.greenDeep : FluiColors.outline,
            width: 2,
          ),
          color: selected ? FluiColors.greenDeep : Colors.transparent,
        ),
        child: selected
            ? const Icon(
                Icons.check_rounded,
                color: FluiColors.surface,
                size: 16,
              )
            : null,
      ),
    );
  }
}
