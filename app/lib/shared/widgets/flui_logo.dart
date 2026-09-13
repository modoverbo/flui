import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:flui/shared/widgets/flui_symbol.dart';
import 'package:material_ui/material_ui.dart';

/// Symbol plus the lowercase "flui" wordmark (Plus Jakarta Sans ExtraBold).
class FluiLogo extends StatelessWidget {
  const new({
    super.key,
    this.axis = Axis.horizontal,
    this.onDark = false,
    this.symbolSize = 40,
    this.accentSymbol = false,
  });

  static const wordmark = 'flui';

  final Axis axis;

  /// On deep green: cream wordmark and cream symbol.
  final bool onDark;
  final double symbolSize;

  /// Yellow symbol on deep green, when the screen has no other highlight.
  final bool accentSymbol;

  @override
  Widget build(BuildContext context) {
    final symbol = FluiSymbol(
      size: symbolSize,
      tone: onDark && accentSymbol
          ? FluiSymbolTone.yellow
          : FluiSymbolTone.green,
      color: onDark && !accentSymbol ? FluiColors.cream : null,
    );
    final text = Text(
      wordmark,
      style: FluiTypography.h1.copyWith(
        fontSize: symbolSize * 0.9,
        height: 1,
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
