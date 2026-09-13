import 'dart:async';

import 'package:flui/core/l10n/formatters.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_theme.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:flui/features/auth/presentation/controllers/sign_out_controller.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/profile/presentation/providers/progress_overview.dart';
import 'package:flui/features/profile/presentation/subscription_summary.dart';
import 'package:flui/features/profile/presentation/widgets/achievement_tile.dart';
import 'package:flui/features/profile/presentation/widgets/week_dots.dart';
import 'package:flui/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:flui/shared/widgets/content_column.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/loading_wave.dart';
import 'package:flui/shared/widgets/page_header.dart';
import 'package:flui/shared/widgets/section_header.dart';
import 'package:flui/shared/widgets/stat_tile.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// "Tu progreso": the only dark-surface screen. Weekly consistency, streak
/// with its free repair, numbers, achievements, plan and sign out.
class ProgressPage extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final user = ref.watch(authUserProvider).value;
    final access = ref.watch(currentAccessProvider);
    final signingOut = ref.watch(signOutControllerProvider);
    final overview = ref.watch(progressOverviewProvider);
    final name = user?.displayName;

    return Theme(
      data: FluiTheme.progressSurface(),
      child: Scaffold(
        backgroundColor: FluiColors.progressSurface,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: FluiSpacing.lg),
            child: ContentColumn(
              maxWidth: FluiSpacing.appContentMaxWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageHeader(
                    title: l10n.progressTitle,
                    subtitle: name == null || name.trim().isEmpty
                        ? l10n.progressGreetingAnonymous
                        : l10n.progressGreeting(name),
                  ),
                  const SizedBox(height: FluiSpacing.lg),
                  switch (overview) {
                    AsyncValue(hasValue: true, :final value?) =>
                      _ProgressContent(overview: value),
                    AsyncError() => Text(
                      l10n.todayLoadError,
                      style: FluiTypography.body.copyWith(
                        color: FluiColors.greenTint,
                      ),
                    ),
                    _ => Center(
                      child: LoadingWave(
                        semanticLabel: l10n.commonLoading,
                        color: FluiColors.cream,
                      ),
                    ),
                  },
                  const SizedBox(height: FluiSpacing.xl),
                  SectionHeader(title: l10n.progressAccountTitle),
                  _DarkCard(
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.badge_check,
                          color: FluiColors.cream,
                        ),
                        const SizedBox(width: FluiSpacing.md),
                        Expanded(
                          child: Text(
                            subscriptionSummary(l10n, access),
                            style: FluiTypography.bodyEmphasis.copyWith(
                              color: FluiColors.cream,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: FluiSpacing.lg),
                  FluiButton.outline(
                    label: l10n.progressSignOut,
                    icon: LucideIcons.log_out,
                    isLoading: signingOut,
                    onDark: true,
                    onPressed: () => unawaited(
                      ref.read(signOutControllerProvider.notifier).signOut(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressContent extends ConsumerWidget {
  const new({required this.overview});

  final ProgressOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final streak = overview.streak;
    final stats = overview.stats;
    final repairable = streak.repairableDate;
    final repairAfter = streak.streakAfterRepair;
    final repairing = ref.watch(streakRepairControllerProvider);
    final precision = stats.firstTryPrecisionPercent;
    final light = FluiTypography.body.copyWith(color: FluiColors.greenTint);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DarkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WeekDots(activeDays: streak.weekDays),
              const SizedBox(height: FluiSpacing.md),
              Text(
                l10n.progressWeekDays(streak.activeDaysThisWeek),
                style: FluiTypography.h3.copyWith(color: FluiColors.cream),
              ),
              const SizedBox(height: FluiSpacing.xs),
              Row(
                children: [
                  const Icon(
                    LucideIcons.flame,
                    size: 18,
                    color: FluiColors.greenTint,
                  ),
                  const SizedBox(width: FluiSpacing.xs),
                  Expanded(
                    child: Text(
                      l10n.progressStreak(streak.currentStreak),
                      style: light,
                    ),
                  ),
                ],
              ),
              if (repairable != null && repairAfter != null) ...[
                const SizedBox(height: FluiSpacing.md),
                Text(
                  l10n.progressRepairOffer(
                    formatLongDate(repairable.toDateTime()),
                    repairAfter,
                  ),
                  style: light,
                ),
                const SizedBox(height: FluiSpacing.sm),
                FluiButton.accent(
                  label: l10n.progressRepairAction,
                  isLoading: repairing,
                  onPressed: () => unawaited(
                    ref
                        .read(streakRepairControllerProvider.notifier)
                        .repair(repairable),
                  ),
                ),
              ] else if (streak.repairUsedThisWeek) ...[
                const SizedBox(height: FluiSpacing.sm),
                Text(l10n.progressRepairUsed, style: light),
              ],
            ],
          ),
        ),
        const SizedBox(height: FluiSpacing.xl),
        SectionHeader(title: l10n.progressStatsTitle),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StatTile(
                value: '${stats.tuya}',
                label: l10n.statOwnedWords,
              ),
            ),
            const SizedBox(width: FluiSpacing.xs),
            Expanded(
              child: StatTile(
                value: '${stats.practica}',
                label: l10n.statPracticeWords,
              ),
            ),
          ],
        ),
        const SizedBox(height: FluiSpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StatTile(
                value: precision == null
                    ? l10n.commonNoData
                    : l10n.statPrecisionValue(precision),
                label: l10n.statPrecisionLabel,
              ),
            ),
            const SizedBox(width: FluiSpacing.xs),
            Expanded(
              child: StatTile(
                value: '${stats.activeDays}',
                label: l10n.statActiveDays,
              ),
            ),
          ],
        ),
        const SizedBox(height: FluiSpacing.xl),
        SectionHeader(title: l10n.progressAchievementsTitle),
        for (final achievement in overview.achievements) ...[
          AchievementTile(achievement: achievement),
          const SizedBox(height: FluiSpacing.xs),
        ],
      ],
    );
  }
}

class _DarkCard extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: FluiColors.greenDeep,
        borderRadius: FluiRadii.xlAll,
      ),
      child: Padding(
        padding: const EdgeInsets.all(FluiSpacing.lg),
        child: child,
      ),
    );
  }
}
