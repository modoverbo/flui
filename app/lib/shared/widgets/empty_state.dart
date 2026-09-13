import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_symbol.dart';
import 'package:material_ui/material_ui.dart';

/// Friendly placeholder with the wave symbol.
class EmptyState extends StatelessWidget {
  const new({
    required this.title,
    required this.message,
    super.key,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final actionLabel = this.actionLabel;
    return Padding(
      padding: const EdgeInsets.all(FluiSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              color: FluiColors.greenTint,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(FluiSpacing.lg),
              child: FluiSymbol(size: 56),
            ),
          ),
          const SizedBox(height: FluiSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: FluiTypography.h2.copyWith(color: FluiColors.charcoal),
          ),
          const SizedBox(height: FluiSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: FluiTypography.body.copyWith(color: FluiColors.gray),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: FluiSpacing.lg),
            FluiButton.outline(
              label: actionLabel,
              onPressed: onAction,
              expand: false,
            ),
          ],
        ],
      ),
    );
  }
}
