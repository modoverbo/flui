import 'package:flui/features/exercises/domain/text_matching.dart';
import 'package:flui/features/exercises/domain/word_forms.dart';
import 'package:material_ui/material_ui.dart';

/// [text] with every form of a word in bold ("Su mirada era **perspicaz**").
class HighlightedText extends StatelessWidget {
  const new({
    required this.text,
    required this.forms,
    required this.style,
    super.key,
    this.highlightStyle,
  });

  final String text;
  final WordForms forms;
  final TextStyle style;
  final TextStyle? highlightStyle;

  @override
  Widget build(BuildContext context) {
    final highlight =
        highlightStyle ?? style.copyWith(fontWeight: FontWeight.w700);
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final span in wordSpans(text)) {
      if (!forms.matchesToken(span.text)) continue;
      if (span.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, span.start)));
      }
      spans.add(TextSpan(text: span.text, style: highlight));
      cursor = span.end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
    return Text.rich(TextSpan(style: style, children: spans));
  }
}
