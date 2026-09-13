import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:material_ui/material_ui.dart';

/// Rounded surface for grouped content. [selected] highlights it in green.
class FluiCard extends StatelessWidget {
  const new({
    required this.child,
    super.key,
    this.onTap,
    this.selected = false,
    this.color,
    this.padding = const EdgeInsets.all(FluiSpacing.lg),
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final Color? color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: FluiRadii.lgAll,
      side: BorderSide(
        color: selected ? FluiColors.greenDeep : FluiColors.outline,
        width: selected ? 2 : 1,
      ),
    );
    return Material(
      color: color ?? (selected ? FluiColors.greenTint : FluiColors.surface),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
