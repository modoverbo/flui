import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:material_ui/material_ui.dart';

/// The web hero: a 12-column grid split 7 / 5 inside 1120 px.
///
/// On a compact window the two halves stack, [content] first.
class SplitHero extends StatelessWidget {
  const new({
    required this.content,
    required this.support,
    super.key,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  /// The seven columns: headline, body, action.
  final Widget content;

  /// The five columns: the plate, the word, the proof.
  final Widget support;

  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    if (!layout.isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          content,
          SizedBox(height: layout.blockGap),
          support,
        ],
      );
    }
    return Row(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Expanded(flex: FluiLayout.heroContentColumns, child: content),
        const SizedBox(width: FluiSpacing.xxl),
        Expanded(flex: FluiLayout.heroSupportColumns, child: support),
      ],
    );
  }
}
