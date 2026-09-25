import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/profile/domain/achievements.dart';
import 'package:flui/shared/widgets/flui_glyph.dart';
import 'package:flui/shared/widgets/flui_progress_bar.dart';
import 'package:material_ui/material_ui.dart';

class AchievementTile extends StatelessWidget {
  const new({required this.achievement, super.key});

  final Achievement achievement;

  static String titleOf(AppLocalizations l10n, Achievement achievement) =>
      switch (achievement.kind) {
        AchievementKind.firstWord => l10n.achievementFirstWord,
        AchievementKind.firstOwnedWord => l10n.achievementFirstOwnedWord,
        AchievementKind.fiveActiveDays => l10n.achievementFiveActiveDays,
        AchievementKind.repertoire => l10n.achievementRepertoire(
          achievement.target,
        ),
        AchievementKind.firstOwnSentence => l10n.achievementFirstOwnSentence,
      };

  static FluiGlyph glyphOf(Achievement achievement) =>
      switch (achievement.kind) {
        AchievementKind.firstWord => FluiGlyph.wordOfTheDay,
        AchievementKind.firstOwnedWord => FluiGlyph.achievement,
        AchievementKind.fiveActiveDays => FluiGlyph.streak,
        AchievementKind.repertoire => FluiGlyph.onda,
        AchievementKind.firstOwnSentence => FluiGlyph.microphone,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    final done = achievement.isCompleted;
    final progress = l10n.achievementProgress(
      achievement.current,
      achievement.target,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FluiColors.surface,
        borderRadius: FluiRadii.cardAll,
        border: Border.fromBorderSide(
          done
              // An unlocked achievement gets the stronger accent border.
              ? const BorderSide(color: FluiColors.greenSecondary, width: 2)
              : const BorderSide(color: FluiColors.outline),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(FluiSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: FluiGlyphIcon(
                glyphOf(achievement),
                color: done ? FluiColors.greenSecondary : FluiColors.gray,
              ),
            ),
            const SizedBox(width: FluiSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titleOf(l10n, achievement),
                    style: type.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: FluiColors.ink,
                    ),
                  ),
                  Text(
                    done ? l10n.achievementCompleted : progress,
                    style: type.body.copyWith(color: FluiColors.gray),
                  ),
                  if (!done && achievement.target > 1) ...[
                    const SizedBox(height: FluiSpacing.xs),
                    FluiProgressBar(
                      value: achievement.fraction,
                      semanticLabel: progress,
                      height: 6,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
