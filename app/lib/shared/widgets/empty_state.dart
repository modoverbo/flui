import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_plate.dart';
import 'package:material_ui/material_ui.dart';

/// An empty state is a green plate with something to say, never a grey
/// circle in the middle of a white page.
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
    final type = context.type;
    final actionLabel = this.actionLabel;
    return FluiPlate(
      padding: const EdgeInsets.all(FluiSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: type.titleL.copyWith(color: FluiColors.cream),
            ),
          ),
          const SizedBox(height: FluiSpacing.sm),
          Text(
            message,
            style: type.body.copyWith(color: FluiColors.creamMuted),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: FluiSpacing.lg),
            FluiButton.accent(
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
