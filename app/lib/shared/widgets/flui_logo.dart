import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_type_scale.dart';
import 'package:flui/shared/widgets/flui_brand_mark.dart';
import 'package:material_ui/material_ui.dart';

/// The multicolor brand mark plus the lowercase "flui" wordmark.
class FluiLogo extends StatelessWidget {
  const new({
    super.key,
    this.axis = Axis.horizontal,
    this.onDark = false,
    this.symbolSize = 40,
  });

  static const wordmark = 'flui';

  final Axis axis;

  /// On deep green: cream wordmark; the multicolor mark remains unchanged.
  final bool onDark;
  final double symbolSize;

  @override
  Widget build(BuildContext context) {
    final symbol = FluiBrandMark(size: symbolSize);
    final text = Text(
      wordmark,
      style: FluiTypeScale.compact.displayL.copyWith(
        fontSize: symbolSize * 0.9,
        height: 1,
        letterSpacing: symbolSize * 0.9 * -0.03,
        color: onDark ? FluiColors.cream : FluiColors.greenDeep,
      ),
    );
    final gap = SizedBox.square(dimension: symbolSize * 0.25);
    return Semantics(
      label: wordmark,
      excludeSemantics: true,
      child: Flex(
        direction: axis,
        mainAxisSize: MainAxisSize.min,
        children: [symbol, gap, text],
      ),
    );
  }
}
