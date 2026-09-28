import 'dart:async';

import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/config/feature_flags.dart';
import 'package:flui/core/l10n/formatters.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/auth/presentation/controllers/sign_out_controller.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/diagnosis/domain/diagnosis_resume_policy.dart';
import 'package:flui/features/diagnosis/presentation/providers/diagnosis_providers.dart';
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
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// "Tu progreso": training progress, not a spreadsheet. The week and the
/// streak leads, editorial numbers follow, then achievements as cards, the
/// plan and the way out — on the same paper surface as the rest of the app.
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

    return Scaffold(
      backgroundColor: FluiColors.paper,
      body: SafeArea(
        child: SingleChildScrollView(
          child: PageFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: layout.blockGap),
                PageHeader(
                  title: l10n.progressTitle,
                  subtitle: name == null || name.trim().isEmpty
                      ? l10n.progressGreetingAnonymous
                      : l10n.progressGreeting(name),
                ),
                SizedBox(height: layout.blockGap),
                switch (overview) {
                  AsyncValue(hasValue: true, :final value?) => _ProgressContent(
                    overview: value,
                  ),
                  AsyncError() => Text(
                    l10n.todayLoadError,
                    style: layout.type.bodyL.copyWith(color: FluiColors.gray),
                  ),
                  _ => Center(
                    child: LoadingWave(semanticLabel: l10n.commonLoading),
                  ),
                },
                SizedBox(height: layout.sectionGap),
                SectionHeader(
                  title: l10n.progressAccountTitle,
                  glyph: const FluiGlyphIcon(FluiGlyph.goal),
                ),
                FluiCard(
                  child: Text(
                    subscriptionSummary(l10n, access),
                    style: layout.type.bodyL.copyWith(color: FluiColors.ink),
                  ),
                ),
                // Only ever built while the flag is on: flag-off never
                // watches `speakingGymEnabledProvider`'s dependents, so
                // production (flag off) makes no new diagnosis queries and
                // shows no diagnosis entry here (U14c).
                if (ref.watch(speakingGymEnabledProvider)) ...[
                  SizedBox(height: layout.blockGap),
                  const _DiagnosisResumeEntry(),
                ],
                SizedBox(height: layout.blockGap),
                FluiButton.outline(
                  label: l10n.progressSignOut,
                  isLoading: signingOut,
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
          glyph: const FluiGlyphIcon(FluiGlyph.goal),
        ),
        _ProgressNumbers(stats: overview.stats),
        if (repairable != null && repairAfter != null) ...[
          SizedBox(height: layout.blockGap),
          FluiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.progressRepairOffer(
                    formatLongDate(repairable.toDateTime()),
                    repairAfter,
                  ),
                  style: type.body.copyWith(color: FluiColors.gray),
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
            style: type.body.copyWith(color: FluiColors.gray),
          ),
        ],
        SizedBox(height: layout.sectionGap),
        SectionHeader(
          title: l10n.progressAchievementsTitle,
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
    return FluiCard(
      color: FluiColors.aqua,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const FluiGlyphIcon(FluiGlyph.streak, color: FluiColors.ink),
              const SizedBox(width: FluiSpacing.xs),
              Expanded(child: FluiLabel(l10n.progressBentoTitle)),
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
              style: type.displayL.copyWith(color: FluiColors.ink),
            ),
          ),
          const SizedBox(height: FluiSpacing.xs),
          Text(
            l10n.progressWeekDays(streak.activeDaysThisWeek),
            style: type.body.copyWith(color: FluiColors.ink),
          ),
          const SizedBox(height: FluiSpacing.md),
          Semantics(
            explicitChildNodes: true,
            child: WeekDots(activeDays: streak.weekDays, onDark: false),
          ),
        ],
      ),
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
          ),
        ),
        SizedBox(
          width: 150,
          child: EditorialStat(
            value: '${stats.tuya}',
            label: l10n.statOwnedWords,
          ),
        ),
        SizedBox(
          width: 150,
          child: EditorialStat(
            value: '${stats.practica}',
            label: l10n.statPracticeWords,
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
          ),
        ),
      ],
    );
  }
}

/// PROGRESO's paused-retake entry point (design §10, U14c): shown only
/// while an open (unanswered/unclosed) diagnosis session already exists —
/// only reachable here once the gate is `completed` (a retake in
/// progress), since a `required` baseline blocks navigation to this page
/// entirely. Starting a brand-new retake (when none is in progress) is a
/// later unit's entry point (U18b); this is resume-only.
class _DiagnosisResumeEntry extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final resume = ref.watch(diagnosisResumeProvider).value;
    if (resume is! DiagnosisResume) return const SizedBox.shrink();
    return FluiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.progressDiagnosisResumeTitle),
          const SizedBox(height: FluiSpacing.sm),
          FluiButton.outline(
            label: l10n.progressDiagnosisResumeAction,
            onPressed: () => context.go('${AppRoutes.diagnosisLive}?retake=1'),
          ),
        ],
      ),
    );
  }
}
