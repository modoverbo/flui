import 'package:flui/core/l10n/formatters.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:flui/features/subscription/domain/subscription_plan.dart';
import 'package:flui/shared/widgets/flui_card.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:material_ui/material_ui.dart';

/// A selectable plan on the paywall.
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
  final bool recommended;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final price = formatPrice(plan.priceCents, plan.currency);
    final priceText = switch (plan.months) {
      1 => l10n.planPriceMonthly(price),
      final months when plan.billingPeriodDays % 30 == 0 =>
        l10n.planPriceMonths(price, months),
      _ => l10n.planPriceDays(price, plan.billingPeriodDays),
    };
    final savingsLabel = plan.savingsLabel;

    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: FluiCard(
        selected: selected,
        onTap: onSelected,
        padding: const EdgeInsets.all(FluiSpacing.md),
        child: Row(
          children: [
            Icon(
              selected ? LucideIcons.circle_check : LucideIcons.circle,
              color: selected ? FluiColors.greenDeep : FluiColors.gray,
            ),
            const SizedBox(width: FluiSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: FluiSpacing.xs,
                    runSpacing: FluiSpacing.xxs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        plan.label,
                        style: FluiTypography.h3.copyWith(
                          color: FluiColors.charcoal,
                        ),
                      ),
                      if (recommended)
                        _Badge(
                          label: l10n.paywallRecommended,
                          background: FluiColors.yellowElectric,
                          foreground: FluiColors.charcoal,
                        ),
                    ],
                  ),
                  const SizedBox(height: FluiSpacing.xxs),
                  Text(
                    priceText,
                    style: FluiTypography.bodyEmphasis.copyWith(
                      color: FluiColors.charcoal,
                    ),
                  ),
                  if (plan.months > 1)
                    Text(
                      l10n.planMonthlyEquivalent(
                        formatPrice(plan.monthlyEquivalentCents, plan.currency),
                      ),
                      style: FluiTypography.caption.copyWith(
                        color: FluiColors.gray,
                      ),
                    ),
                  if (savingsLabel != null) ...[
                    const SizedBox(height: FluiSpacing.xs),
                    _Badge(
                      label: savingsLabel,
                      background: selected
                          ? FluiColors.surface
                          : FluiColors.greenTint,
                      foreground: FluiColors.greenDeep,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const new({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: FluiRadii.pill,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: Text(
          label,
          style: FluiTypography.caption.copyWith(
            color: foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
