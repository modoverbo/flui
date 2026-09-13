import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/vocabulary/domain/mastery_meter.dart';
import 'package:flui/features/vocabulary/domain/word_progress.dart';
import 'package:flui/shared/widgets/flui_glyph.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:flui/shared/widgets/flui_progress_bar.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:material_ui/material_ui.dart';

/// The five rungs of one word, so effort shows before the word is "tuya".
class MasteryMeterView extends StatelessWidget {
  const new({
    required this.progress,
    super.key,
    this.compact = false,
    this.onDark = false,
  });

  final WordProgress progress;

  /// Only the bar and the count, for the end-of-session summary.
  final bool compact;
  final bool onDark;

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
    final type = context.type;
    final reached = MasteryMeter.reached(progress);
    final count = reached.length;
    final caption = l10n.masteryProgress(count, MasteryMeter.total);
    final text = onDark ? FluiColors.cream : FluiColors.charcoal;
    final muted = onDark ? FluiColors.creamMuted : FluiColors.gray;

    // One statement instead of the caption three times and five loose
    // labels: the count, then what has actually been reached.
    final reachedLabels = [
      for (final step in MasteryStep.values)
        if (reached.contains(step)) labelOf(l10n, step).toLowerCase(),
    ];

    return Semantics(
      label: [
        '${l10n.masteryTitle}: $caption',
        if (reachedLabels.isNotEmpty) reachedLabels.join(', '),
      ].join('. '),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FluiLabel(caption, onDark: onDark),
              const SizedBox(width: FluiSpacing.sm),
              Expanded(
                child: FluiProgressBar(
                  value: count / MasteryMeter.total,
                  semanticLabel: caption,
                  height: 6,
                  onDark: onDark,
                ),
              ),
            ],
          ),
          if (!compact)
            for (final step in MasteryStep.values) ...[
              const SizedBox(height: FluiSpacing.sm),
              Row(
                children: [
                  if (reached.contains(step))
                    const FluiGlyphIcon(
                      FluiGlyph.achievement,
                      size: FluiIconSize.inline,
                      color: FluiColors.greenSecondary,
                    )
                  else
                    Icon(LucideIcons.circle, size: 18, color: muted),
                  const SizedBox(width: FluiSpacing.sm),
                  Expanded(
                    child: Text(
                      labelOf(l10n, step),
                      style: type.body.copyWith(
                        color: reached.contains(step) ? text : muted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
        ],
      ),
    );
  }
}
