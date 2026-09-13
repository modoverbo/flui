import 'package:flui/core/l10n/formatters.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_surfaces.dart';
import 'package:flui/core/theme/flui_type_scale.dart';
import 'package:flui/features/subscription/domain/subscription_plan.dart';
import 'package:flui/shared/widgets/flui_plate.dart';
import 'package:material_ui/material_ui.dart';

/// A plan on the paywall.
///
/// The recommended plan is the dark one and it is physically bigger; its
/// savings badge sits *above* the card so it is read before the price, not
/// after it. Prices always come from `subscription_plans`.
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

  /// The plan we lead with: dark plate, larger type, badge above the fold.
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

    final body = Padding(
      padding: EdgeInsets.all(recommended ? FluiSpacing.lg : FluiSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.label,
                  style: (recommended ? type.titleM : type.body).copyWith(
                    fontWeight: FontWeight.w600,
                    color: recommended ? FluiColors.cream : FluiColors.charcoal,
                  ),
                ),
                const SizedBox(height: FluiSpacing.xxs),
                Text(
                  priceText,
                  style: (recommended ? type.titleL : type.bodyL).copyWith(
                    color: recommended ? FluiColors.cream : FluiColors.charcoal,
                  ),
                ),
                if (monthly != null)
                  Text(
                    monthly,
                    style: type.body.copyWith(
                      color: recommended
                          ? FluiColors.creamMuted
                          : FluiColors.gray,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: FluiSpacing.sm),
          _SelectionMark(selected: selected, onDark: recommended),
        ],
      ),
    );

    final card = Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      label: [plan.label, priceText, ?monthly, ?savingsLabel].join('. '),
      excludeSemantics: true,
      child: Material(
        color: recommended ? Colors.transparent : FluiColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: FluiRadii.cardAll,
          side: selected
              ? BorderSide(
                  color: recommended
                      ? FluiColors.yellowElectric
                      : FluiColors.greenDeep,
                  width: 2,
                )
              : FluiSurfaces.hairline(onDark: recommended),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (recommended)
              const Positioned.fill(
                child: FluiPlate(
                  borderRadius: FluiRadii.cardAll,
                  child: SizedBox.expand(),
                ),
              ),
            InkWell(onTap: onSelected, child: body),
          ],
        ),
      ),
    );

    if (savingsLabel == null) return card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Above the card fold: the reason to look at this one first.
        _SavingsBadge(label: savingsLabel),
        const SizedBox(height: FluiSpacing.xs),
        card,
      ],
    );
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
  const new({required this.selected, required this.onDark});

  final bool selected;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final color = onDark ? FluiColors.cream : FluiColors.greenDeep;
    return SizedBox.square(
      dimension: 24,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? (onDark ? FluiColors.yellowElectric : color)
                : (onDark ? FluiColors.creamMuted : FluiColors.outline),
            width: 2,
          ),
          color: selected
              ? (onDark ? FluiColors.yellowElectric : color)
              : Colors.transparent,
        ),
        child: selected
            ? Center(
                child: SizedBox.square(
                  dimension: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: onDark ? FluiColors.charcoal : FluiColors.cream,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
