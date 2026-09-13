import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:material_ui/material_ui.dart';

/// Monday to Sunday of the current week, for dark surfaces.
class WeekDots extends StatelessWidget {
  const new({required this.activeDays, super.key});

  /// Seven values, Monday first.
  final List<bool> activeDays;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final initials = l10n.weekdayInitials.split(',');
    final names = l10n.weekdayNames.split(',');
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < 7; i++)
          Semantics(
            label: activeDays[i]
                ? l10n.progressWeekdayActive(names[i])
                : l10n.progressWeekdayInactive(names[i]),
            excludeSemantics: true,
            child: Column(
              children: [
                Text(
                  initials[i],
                  style: FluiTypography.caption.copyWith(
                    color: FluiColors.greenTint,
                  ),
                ),
                const SizedBox(height: FluiSpacing.xxs),
                Container(
                  key: ValueKey('week-dot-$i'),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: activeDays[i]
                        ? FluiColors.yellowElectric
                        : Colors.transparent,
                    border: Border.all(
                      color: activeDays[i]
                          ? FluiColors.yellowElectric
                          : FluiColors.greenSecondary,
                      width: 2,
                    ),
                  ),
                  child: activeDays[i]
                      ? const Icon(
                          LucideIcons.check,
                          size: 16,
                          color: FluiColors.charcoal,
                        )
                      : null,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
