import 'dart:async';

import 'package:flui/core/l10n/formatters.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_theme.dart';
import 'package:flui/features/auth/presentation/controllers/sign_out_controller.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/profile/presentation/providers/progress_overview.dart';
import 'package:flui/features/profile/presentation/subscription_summary.dart';
import 'package:flui/features/profile/presentation/widgets/achievement_tile.dart';
import 'package:flui/features/profile/presentation/widgets/week_dots.dart';
import 'package:flui/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:flui/shared/layout/bento_layout.dart';
import 'package:flui/shared/widgets/bento_grid.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_card.dart';
import 'package:flui/shared/widgets/flui_glyph.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:flui/shared/widgets/loading_wave.dart';
import 'package:flui/shared/widgets/page_frame.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// "Tu progreso": the only dark screen. A bento of the week, the numbers and
/// the reachable achievements, then the plan and the way out.
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
    final stats = overview.stats;
    final repairable = streak.repairableDate;
    final repairAfter = streak.streakAfterRepair;
    final repairing = ref.watch(streakRepairControllerProvider);
    final precision = stats.firstTryPrecisionPercent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BentoGrid(
          tiles: [
            BentoTile(
              span: BentoSpan.large,
              tone: BentoTone.green,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const FluiGlyphIcon(
                        FluiGlyph.streak,
                        color: FluiColors.creamMuted,
                      ),
                      const SizedBox(width: FluiSpacing.xs),
                      Expanded(
                        child: FluiLabel(l10n.progressBentoTitle, onDark: true),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    l10n.progressStreak(streak.currentStreak),
                    style: type.titleL.copyWith(color: FluiColors.cream),
                  ),
                  const SizedBox(height: FluiSpacing.xs),
                  Text(
                    l10n.progressWeekDays(streak.activeDaysThisWeek),
                    style: type.body.copyWith(color: FluiColors.creamMuted),
                  ),
                  const SizedBox(height: FluiSpacing.md),
                  WeekDots(activeDays: streak.weekDays),
                ],
              ),
            ),
            _tile(
              context,
              value: '${stats.tuya}',
              label: l10n.statOwnedWords,
              glyph: FluiGlyph.achievement,
            ),
            _tile(
              context,
              value: '${stats.practica}',
              label: l10n.statPracticeWords,
              glyph: FluiGlyph.review,
            ),
            _tile(
              context,
              value: precision == null
                  ? l10n.commonNoData
                  : l10n.statPrecisionValue(precision),
              label: l10n.statPrecisionLabel,
              glyph: FluiGlyph.goal,
            ),
            _tile(
              context,
              value: '${stats.activeDays}',
              label: l10n.statActiveDays,
              glyph: FluiGlyph.onda,
            ),
          ],
        ),
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

  BentoTile _tile(
    BuildContext context, {
    required String value,
    required String label,
    required FluiGlyph glyph,
  }) {
    final type = context.type;
    return BentoTile(
      span: BentoSpan.small,
      tone: BentoTone.green,
      semanticLabel: '$value $label',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FluiGlyphIcon(glyph, color: FluiColors.creamMuted),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: type.titleL.copyWith(color: FluiColors.cream),
            ),
          ),
          FluiLabel(label, onDark: true),
        ],
      ),
    );
  }
}
