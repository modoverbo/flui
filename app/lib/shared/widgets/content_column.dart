import 'package:flui/core/theme/flui_spacing.dart';
import 'package:material_ui/material_ui.dart';

/// Centers content in a readable column on wide screens.
class ContentColumn extends StatelessWidget {
  const new({
    required this.child,
    super.key,
    this.maxWidth = FluiSpacing.contentMaxWidth,
    this.padding = const EdgeInsets.symmetric(horizontal: FluiSpacing.lg),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
