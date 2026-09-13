import 'package:flui/core/theme/flui_radii.dart';
import 'package:material_ui/material_ui.dart';

/// Rounded progress bar (0 to 1).
class FluiProgressBar extends StatelessWidget {
  const new({
    required this.value,
    required this.semanticLabel,
    super.key,
    this.height = 8,
  });

  final double value;
  final String semanticLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return Semantics(
      label: semanticLabel,
      value: '${(clamped * 100).round()} %',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: FluiRadii.pill,
        child: LinearProgressIndicator(value: clamped, minHeight: height),
      ),
    );
  }
}
