import 'package:flui/core/theme/flui_colors.dart';
import 'package:material_ui/material_ui.dart';

/// A headline whose last words are yellow.
///
/// This is one of yellow's four roles: one word of a marketing headline.
/// Yellow text only ever lands on deep green (8.59:1), never on cream
/// (1.33:1), so this widget only exists for dark surfaces.
class HeadlineText extends StatelessWidget {
  const new({
    required this.text,
    required this.highlight,
    required this.style,
    super.key,
    this.textAlign,
  });

  final String text;

  /// The exact tail of [text] to set in yellow. Ignored when it does not
  /// match, so a translation can drop the highlight without breaking.
  final String highlight;
  final TextStyle style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final split = text.endsWith(highlight) && highlight.isNotEmpty
        ? text.length - highlight.length
        : text.length;
    return Semantics(
      header: true,
      child: Text.rich(
        TextSpan(
          style: style.copyWith(color: FluiColors.cream),
          children: [
            TextSpan(text: text.substring(0, split)),
            if (split < text.length)
              TextSpan(
                text: text.substring(split),
                style: const TextStyle(color: FluiColors.yellowElectric),
              ),
          ],
        ),
        textAlign: textAlign,
      ),
    );
  }
}
