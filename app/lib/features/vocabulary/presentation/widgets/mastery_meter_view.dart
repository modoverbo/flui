import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:flui/features/vocabulary/domain/mastery_meter.dart';
import 'package:flui/features/vocabulary/domain/word_progress.dart';
import 'package:flui/shared/widgets/flui_progress_bar.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:material_ui/material_ui.dart';

/// The five rungs of one word, so effort shows before the word is "tuya".
class MasteryMeterView extends StatelessWidget {
  const new({required this.progress, super.key, this.compact = false});

  final WordProgress progress;

  /// Only the bar and the count, for the end-of-session summary.
  final bool compact;

  static String labelOf(AppLocalizations l10n, MasteryStep step) =>
      switch (step) {
        MasteryStep.discovered => l10n.masteryStepDiscovered,
        MasteryStep.practiced => l10n.masteryStepPracticed,
        MasteryStep.recall => l10n.masteryStepRecall,
        MasteryStep.production => l10n.masteryStepProduction,
        MasteryStep.owned => l10n.masteryStepOwned,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reached = MasteryMeter.reached(progress);
    final count = reached.length;
    final caption = l10n.masteryProgress(count, MasteryMeter.total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) ...[
          Semantics(
            header: true,
            child: Text(
              l10n.masteryTitle,
              style: FluiTypography.h3.copyWith(color: FluiColors.charcoal),
            ),
          ),
          const SizedBox(height: FluiSpacing.sm),
        ],
        Row(
          children: [
            Text(
              caption,
              style: FluiTypography.label.copyWith(color: FluiColors.gray),
            ),
            const SizedBox(width: FluiSpacing.sm),
            Expanded(
              child: FluiProgressBar(
                value: count / MasteryMeter.total,
                semanticLabel: caption,
                height: 6,
              ),
            ),
          ],
        ),
        if (!compact)
          for (final step in MasteryStep.values) ...[
            const SizedBox(height: FluiSpacing.xs),
            Row(
              children: [
                Icon(
                  reached.contains(step)
                      ? LucideIcons.circle_check
                      : LucideIcons.circle,
                  size: 18,
                  color: reached.contains(step)
                      ? FluiColors.greenDeep
                      : FluiColors.gray,
                ),
                const SizedBox(width: FluiSpacing.sm),
                Expanded(
                  child: Text(
                    labelOf(l10n, step),
                    style: FluiTypography.body.copyWith(
                      color: reached.contains(step)
                          ? FluiColors.charcoal
                          : FluiColors.gray,
                    ),
                  ),
                ),
              ],
            ),
          ],
      ],
    );
  }
}
