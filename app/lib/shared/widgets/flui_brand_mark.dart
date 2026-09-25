import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

/// The overlapping cards and flowing wave selected for the production brand.
class FluiBrandMark extends StatelessWidget {
  const new({super.key, this.size = 48, this.semanticLabel});

  static const asset = 'assets/brand/flui_brand_mark.svg';

  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    asset,
    width: size,
    height: size,
    semanticsLabel: semanticLabel,
    excludeFromSemantics: semanticLabel == null,
  );
}
