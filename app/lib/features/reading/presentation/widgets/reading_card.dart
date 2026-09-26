import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/reading/domain/reading.dart';
import 'package:flui/features/reading/presentation/scene_label.dart';
import 'package:flui/features/vocabulary/domain/exercises/word_forms.dart';
import 'package:flui/features/vocabulary/presentation/widgets/highlighted_text.dart';
import 'package:flui/shared/widgets/flui_card.dart';
import 'package:flui/shared/widgets/flui_glyph.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:material_ui/material_ui.dart';

/// A scene: label, title, body with the word in bold and "Antes decías… /
/// Ahora:".
class ReadingCard extends StatelessWidget {
  const new({required this.reading, required this.forms, super.key});

  final Reading reading;
  final WordForms forms;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    return FluiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const FluiGlyphIcon(
                FluiGlyph.inContext,
                size: FluiIconSize.inline,
                color: FluiColors.greenSecondary,
              ),
              const SizedBox(width: FluiSpacing.xs),
              Expanded(child: FluiLabel(sceneLabel(l10n, reading.scene))),
            ],
          ),
          const SizedBox(height: FluiSpacing.sm),
          Semantics(
            header: true,
            child: Text(
              reading.title,
              style: type.titleM.copyWith(color: FluiColors.charcoal),
            ),
          ),
          const SizedBox(height: FluiSpacing.sm),
          HighlightedText(
            text: reading.body,
            forms: forms,
            style: type.body.copyWith(color: FluiColors.charcoal),
          ),
          const SizedBox(height: FluiSpacing.md),
          BeforeAfterBlock(
            before: reading.beforePhrase,
            after: reading.afterPhrase,
            forms: forms,
          ),
        ],
      ),
    );
  }
}

class BeforeAfterBlock extends StatelessWidget {
  const new({
    required this.before,
    required this.after,
    required this.forms,
    super.key,
  });

  final String before;
  final String after;
  final WordForms forms;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: FluiColors.cream,
        borderRadius: FluiRadii.chipAll,
      ),
      child: Padding(
        padding: const EdgeInsets.all(FluiSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FluiLabel(l10n.readingBefore, color: FluiColors.gray),
            const SizedBox(height: FluiSpacing.xxs),
            Text(
              '«$before»',
              style: type.body.copyWith(
                color: FluiColors.gray,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const SizedBox(height: FluiSpacing.sm),
            FluiLabel(l10n.readingAfter),
            const SizedBox(height: FluiSpacing.xxs),
            HighlightedText(
              text: '«$after»',
              forms: forms,
              style: type.bodyL.copyWith(
                color: FluiColors.greenDeep,
                fontWeight: FontWeight.w600,
              ),
              highlightStyle: type.bodyL.copyWith(
                color: FluiColors.greenDeep,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: FluiColors.greenSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
