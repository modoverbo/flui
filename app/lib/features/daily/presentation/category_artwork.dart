import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/features/themes/domain/theme.dart';
import 'package:flutter/material.dart';

/// The approved transparent editorial illustration for a content family.
class CategoryArtwork extends StatelessWidget {
  const new({required this.family, super.key});

  final ThemeFamily family;

  static String assetFor(ThemeFamily family) =>
      'assets/illustrations/categories/${family.name}.png';

  static Color cardColorFor(ThemeFamily family) => switch (family) {
    ThemeFamily.trabajo => FluiColors.electricBlue,
    ThemeFamily.social => FluiColors.softPink,
    ThemeFamily.publico => FluiColors.aqua,
    ThemeFamily.precision => FluiColors.acidLime,
    ThemeFamily.emocion => FluiColors.lavender,
  };

  @override
  Widget build(BuildContext context) => Image.asset(
    assetFor(family),
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );
}
