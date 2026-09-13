import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:flui/features/exercises/domain/word_forms.dart';
import 'package:flui/features/reading/domain/reading.dart';
import 'package:flui/features/reading/presentation/scene_label.dart';
import 'package:flui/features/vocabulary/presentation/widgets/highlighted_text.dart';
import 'package:flui/shared/widgets/flui_card.dart';
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
    return FluiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sceneLabel(l10n, reading.scene).toUpperCase(),
            style: FluiTypography.caption.copyWith(
              color: FluiColors.greenSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: FluiSpacing.xs),
          Semantics(
            header: true,
            child: Text(
              reading.title,
              style: FluiTypography.h3.copyWith(color: FluiColors.charcoal),
            ),
          ),
          const SizedBox(height: FluiSpacing.sm),
          HighlightedText(
            text: reading.body,
            forms: forms,
            style: FluiTypography.body.copyWith(color: FluiColors.charcoal),
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
    final label = FluiTypography.caption.copyWith(color: FluiColors.gray);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: FluiColors.cream,
        borderRadius: FluiRadii.mdAll,
      ),
      child: Padding(
        padding: const EdgeInsets.all(FluiSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.readingBefore, style: label),
            Text(
              '«$before»',
              style: FluiTypography.body.copyWith(
                color: FluiColors.gray,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const SizedBox(height: FluiSpacing.xs),
            Text(l10n.readingAfter, style: label),
            HighlightedText(
              text: '«$after»',
              forms: forms,
              style: FluiTypography.bodyEmphasis.copyWith(
                color: FluiColors.greenDeep,
              ),
              highlightStyle: FluiTypography.bodyEmphasis.copyWith(
                color: FluiColors.greenDeep,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
