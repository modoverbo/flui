import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_motion.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_type_scale.dart';
import 'package:material_ui/material_ui.dart';

/// Monday to Sunday of the current week. An active day is a yellow bar: a
/// streak moment, one of yellow's four roles.
class WeekDots extends StatelessWidget {
  const new({required this.activeDays, super.key, this.onDark = true});

  /// Seven values, Monday first.
  final List<bool> activeDays;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final initials = l10n.weekdayInitials.split(',');
    final names = l10n.weekdayNames.split(',');
    return Row(
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              label: activeDays[i]
                  ? l10n.progressWeekdayActive(names[i])
                  : l10n.progressWeekdayInactive(names[i]),
              excludeSemantics: true,
              child: Column(
                children: [
                  AnimatedContainer(
                    key: ValueKey('week-dot-$i'),
                    duration: FluiMotion.resolve(context, FluiMotion.quick),
                    curve: FluiMotion.enter,
                    height: activeDays[i] ? 28 : 14,
                    decoration: BoxDecoration(
                      color: activeDays[i]
                          ? FluiColors.yellowElectric
                          : (onDark
                                ? FluiColors.greenSecondary
                                : FluiColors.outline),
                      borderRadius: FluiRadii.pill,
                    ),
                  ),
                  const SizedBox(height: FluiSpacing.xxs),
                  Text(
                    initials[i],
                    style: FluiTypeScale.compact.label.copyWith(
                      color: onDark ? FluiColors.creamMuted : FluiColors.gray,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
