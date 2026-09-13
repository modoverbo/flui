import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:material_ui/material_ui.dart';

/// Word progress states (docs/brand.md §8).
enum WordStateKind { nueva, practica, tuya }

class StateChip extends StatelessWidget {
  const new({required this.state, super.key});

  final WordStateKind state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (label, background, foreground, icon) = switch (state) {
      WordStateKind.nueva => (
        l10n.wordStateNew,
        FluiColors.yellowElectric,
        FluiColors.charcoal,
        LucideIcons.sparkles,
      ),
      WordStateKind.practica => (
        l10n.wordStatePractice,
        FluiColors.greenSecondary,
        FluiColors.cream,
        LucideIcons.repeat,
      ),
      WordStateKind.tuya => (
        l10n.wordStateOwned,
        FluiColors.greenDeep,
        FluiColors.cream,
        LucideIcons.check,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: FluiRadii.pill,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
            Text(
              label,
              style: FluiTypography.label.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}
