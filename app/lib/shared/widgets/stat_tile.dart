import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:material_ui/material_ui.dart';

/// A number and its meaning ("5 de 7" · "días esta semana").
class StatTile extends StatelessWidget {
  const new({required this.value, required this.label, super.key, this.icon});

  final String value;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = this.icon;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: FluiRadii.lgAll,
      ),
      child: Padding(
        padding: const EdgeInsets.all(FluiSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: scheme.primary, size: 20),
              const SizedBox(height: FluiSpacing.xs),
            ],
            Text(
              value,
              style: FluiTypography.h2.copyWith(color: scheme.onSurface),
            ),
            Text(
              label,
              style: FluiTypography.caption.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
