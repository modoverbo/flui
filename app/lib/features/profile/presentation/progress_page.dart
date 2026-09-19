import 'dart:async';

import 'package:flui/core/l10n/formatters.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_theme.dart';
import 'package:flui/features/auth/presentation/controllers/sign_out_controller.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/profile/domain/progress_stats.dart';
import 'package:flui/features/profile/domain/streak_calculator.dart';
import 'package:flui/features/profile/presentation/providers/progress_overview.dart';
import 'package:flui/features/profile/presentation/subscription_summary.dart';
import 'package:flui/features/profile/presentation/widgets/achievement_tile.dart';
import 'package:flui/features/profile/presentation/widgets/week_dots.dart';
import 'package:flui/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:flui/shared/widgets/editorial_stat.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_card.dart';
import 'package:flui/shared/widgets/flui_glyph.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:flui/shared/widgets/loading_wave.dart';
import 'package:flui/shared/widgets/page_frame.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// "Tu progreso": training progress, not a spreadsheet. The week and the
/// streak lead, editorial numbers follow, then the achievements as cards,
/// the plan and the way out — all on the app's one dark surface.
class ProgressPage extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final layout = context.layout;
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
            child: PageFrame(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: layout.blockGap),
                  PageHeader(
                    title: l10n.progressTitle,
                    onDark: true,
                    subtitle: name == null || name.trim().isEmpty
                        ? l10n.progressGreetingAnonymous
                        : l10n.progressGreeting(name),
                  ),
                  SizedBox(height: layout.blockGap),
                  switch (overview) {
                    AsyncValue(hasValue: true, :final value?) =>
                      _ProgressContent(overview: value),
                    AsyncError() => Text(
                      l10n.todayLoadError,
                      style: layout.type.bodyL.copyWith(
                        color: FluiColors.creamMuted,
                      ),
                    ),
                    _ => Center(
                      child: LoadingWave(
                        semanticLabel: l10n.commonLoading,
                        color: FluiColors.cream,
                      ),
                    ),
                  },
                  SizedBox(height: layout.sectionGap),
                  SectionHeader(
                    title: l10n.progressAccountTitle,
                    onDark: true,
                    glyph: const FluiGlyphIcon(FluiGlyph.goal),
                  ),
                  FluiCard(
                    onDark: true,
                    child: Text(
                      subscriptionSummary(l10n, access),
                      style: layout.type.bodyL.copyWith(
                        color: FluiColors.cream,
                      ),
                    ),
                  ),
                  SizedBox(height: layout.blockGap),
                  FluiButton.outline(
                    label: l10n.progressSignOut,
                    isLoading: signingOut,
                    onDark: true,
                    onPressed: () => unawaited(
                      ref.read(signOutControllerProvider.notifier).signOut(),
                    ),
                  ),
                  SizedBox(height: layout.sectionGap),
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
    final layout = context.layout;
    final type = layout.type;
    final streak = overview.streak;
    final repairable = streak.repairableDate;
    final repairAfter = streak.streakAfterRepair;
    final repairing = ref.watch(streakRepairControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProgressStreakBlock(streak: streak),
        SizedBox(height: layout.sectionGap),
        SectionHeader(
          title: l10n.progressStatsTitle,
          onDark: true,
          glyph: const FluiGlyphIcon(FluiGlyph.goal),
        ),
        _ProgressNumbers(stats: overview.stats),
        if (repairable != null && repairAfter != null) ...[
          SizedBox(height: layout.blockGap),
          FluiCard(
            onDark: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.progressRepairOffer(
                    formatLongDate(repairable.toDateTime()),
                    repairAfter,
                  ),
                  style: type.body.copyWith(color: FluiColors.creamMuted),
                ),
                const SizedBox(height: FluiSpacing.md),
                FluiButton.accent(
                  label: l10n.progressRepairAction,
                  isLoading: repairing,
                  onPressed: () => unawaited(
                    ref
                        .read(streakRepairControllerProvider.notifier)
                        .repair(repairable),
                  ),
                ),
              ],
            ),
          ),
        ] else if (streak.repairUsedThisWeek) ...[
          SizedBox(height: layout.blockGap),
          Text(
            l10n.progressRepairUsed,
            style: type.body.copyWith(color: FluiColors.creamMuted),
          ),
        ],
        SizedBox(height: layout.sectionGap),
        SectionHeader(
          title: l10n.progressAchievementsTitle,
          onDark: true,
          glyph: const FluiGlyphIcon(FluiGlyph.achievement),
        ),
        for (final achievement in overview.achievements) ...[
          AchievementTile(achievement: achievement),
          const SizedBox(height: FluiSpacing.xs),
        ],
      ],
    );
  }
}

/// The week and the streak: the page's one editorial hero, not a cell in a
/// grid of identical stat boxes.
class _ProgressStreakBlock extends StatelessWidget {
  const new({required this.streak});

  final StreakSummary streak;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const FluiGlyphIcon(FluiGlyph.streak, color: FluiColors.creamMuted),
            const SizedBox(width: FluiSpacing.xs),
            Expanded(child: FluiLabel(l10n.progressBentoTitle, onDark: true)),
          ],
        ),
        const SizedBox(height: FluiSpacing.sm),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            // Has a zero case of its own: "Tu racha empieza con tu próxima
            // sesión".
            l10n.progressStreak(streak.currentStreak),
            style: type.displayL.copyWith(color: FluiColors.cream),
          ),
        ),
        const SizedBox(height: FluiSpacing.xs),
        Text(
          l10n.progressWeekDays(streak.activeDaysThisWeek),
          style: type.body.copyWith(color: FluiColors.creamMuted),
        ),
        const SizedBox(height: FluiSpacing.md),
        WeekDots(activeDays: streak.weekDays),
      ],
    );
  }
}

/// Días activos, palabras tuyas, en práctica y precisión — editorial
/// numerals, not a KPI tile grid (`docs/redesign/01-design-system.md` §2).
///
/// `ProgressStats` has no notion of speaking-attempt counts (the speaking
/// feature records single attempts but nothing aggregates them into the
/// learning data this provider reads), so "intentos de habla" is not one of
/// the numbers here — see the implementation report.
class _ProgressNumbers extends StatelessWidget {
  const new({required this.stats});

  final ProgressStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final precision = stats.firstTryPrecisionPercent;
    return Wrap(
      spacing: FluiSpacing.xl,
      runSpacing: FluiSpacing.lg,
      children: [
        SizedBox(
          width: 150,
          child: EditorialStat(
            value: '${stats.activeDays}',
            label: l10n.statActiveDays,
            onDark: true,
          ),
        ),
        SizedBox(
          width: 150,
          child: EditorialStat(
            value: '${stats.tuya}',
            label: l10n.statOwnedWords,
            onDark: true,
          ),
        ),
        SizedBox(
          width: 150,
          child: EditorialStat(
            value: '${stats.practica}',
            label: l10n.statPracticeWords,
            onDark: true,
          ),
        ),
        SizedBox(
          width: 150,
          child: EditorialStat(
            value: precision == null
                ? l10n.commonNoData
                : l10n.statPrecisionValue(precision),
            label: l10n.statPrecisionLabel,
            caption: l10n.statPrecisionWindow,
            onDark: true,
          ),
        ),
      ],
    );
  }
}
