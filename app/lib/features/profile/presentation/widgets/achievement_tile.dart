import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:flui/features/profile/domain/achievements.dart';
import 'package:flui/shared/widgets/flui_progress_bar.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final done = achievement.isCompleted;
    final progress = l10n.achievementProgress(
      achievement.current,
      achievement.target,
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: FluiColors.greenDeep,
        borderRadius: FluiRadii.lgAll,
      ),
      child: Padding(
        padding: const EdgeInsets.all(FluiSpacing.md),
        child: Row(
          children: [
            Icon(switch (achievement.kind) {
              AchievementKind.firstWord => LucideIcons.sparkles,
              AchievementKind.firstOwnedWord => LucideIcons.badge_check,
              AchievementKind.fiveActiveDays => LucideIcons.calendar_check,
              AchievementKind.repertoire => LucideIcons.library,
              AchievementKind.firstOwnSentence => LucideIcons.message_circle,
            }, color: FluiColors.cream),
            const SizedBox(width: FluiSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titleOf(l10n, achievement),
                    style: FluiTypography.bodyEmphasis.copyWith(
                      color: FluiColors.cream,
                    ),
                  ),
                  Text(
                    done ? l10n.achievementCompleted : progress,
                    style: FluiTypography.caption.copyWith(
                      color: FluiColors.greenTint,
                    ),
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
            const SizedBox(width: FluiSpacing.sm),
            Icon(
              done ? LucideIcons.circle_check : LucideIcons.circle,
              color: done ? FluiColors.yellowElectric : FluiColors.greenTint,
              semanticLabel: done ? l10n.achievementCompleted : null,
            ),
          ],
        ),
      ),
    );
  }
}
