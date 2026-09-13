import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_surfaces.dart';
import 'package:material_ui/material_ui.dart';

/// A flat surface for grouped content: hairline border, no shadow.
/// [selected] draws the border in deep green instead of tinting the card.
class FluiCard extends StatelessWidget {
  const new({
    required this.child,
    super.key,
    this.onTap,
    this.selected = false,
    this.color,
    this.onDark = false,
    this.padding = const EdgeInsets.all(FluiSpacing.ml),
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final Color? color;
  final bool onDark;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final border = selected
        ? BorderSide(
            color: onDark ? FluiColors.yellowElectric : FluiColors.greenDeep,
            width: 2,
          )
        : FluiSurfaces.hairline(onDark: onDark);
    final shape = RoundedRectangleBorder(
      borderRadius: FluiRadii.cardAll,
      side: border,
    );
    return Material(
      color:
          color ??
          (onDark
              ? FluiColors.greenDeep
              : (selected ? FluiColors.greenTint : FluiColors.surface)),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
