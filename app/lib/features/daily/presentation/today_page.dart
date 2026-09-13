import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/l10n/failure_messages.dart';
import 'package:flui/core/l10n/formatters.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:flui/features/daily/domain/session_plan.dart';
import 'package:flui/features/daily/presentation/providers/daily_providers.dart';
import 'package:flui/features/daily/presentation/providers/learning_data_controller.dart';
import 'package:flui/features/daily/presentation/providers/today_overview.dart';
import 'package:flui/features/reading/presentation/providers/context_readings.dart';
import 'package:flui/features/reading/presentation/widgets/reading_card.dart';
import 'package:flui/features/vocabulary/presentation/providers/vocabulary_providers.dart';
import 'package:flui/shared/widgets/content_column.dart';
import 'package:flui/shared/widgets/empty_state.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_card.dart';
import 'package:flui/shared/widgets/loading_wave.dart';
import 'package:flui/shared/widgets/page_header.dart';
import 'package:flui/shared/widgets/section_header.dart';
import 'package:flui/shared/widgets/stat_tile.dart';
import 'package:flui/shared/widgets/state_chip.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// "Hoy": today's session, what the user has to show for it, the word of the
/// day, "repaso extra" and a few scenes.
class TodayPage extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final overview = ref.watch(todayOverviewProvider);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: FluiSpacing.lg),
          child: ContentColumn(
            maxWidth: FluiSpacing.appContentMaxWidth,
            child: switch (overview) {
              AsyncValue(hasValue: true, :final value?) => _TodayContent(
                overview: value,
              ),
              AsyncError(:final error) => EmptyState(
                title: l10n.todayLoadError,
                message: error is Failure
                    ? failureMessage(l10n, error)
                    : l10n.errorUnexpected,
                actionLabel: l10n.commonRetry,
                onAction: () => retryLearningData(ref),
              ),
              _ => Padding(
                padding: const EdgeInsets.all(FluiSpacing.xxl),
                child: Center(
                  child: LoadingWave(semanticLabel: l10n.commonLoading),
                ),
              ),
            },
          ),
        ),
      ),
    );
  }
}

/// Reloads the catalog and the learning data after a failure.
void retryLearningData(WidgetRef ref) {
  final userId = ref.read(currentUserIdProvider);
  ref.invalidate(catalogProvider);
  if (userId != null) ref.invalidate(learningDataControllerProvider(userId));
}

class _TodayContent extends StatelessWidget {
  const new({required this.overview});

  final TodayOverview overview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = overview.name;
    final word = overview.newWords.firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: name == null
              ? l10n.progressGreetingAnonymous
              : l10n.progressGreeting(name),
          subtitle: l10n.todaySubtitle,
        ),
        const SizedBox(height: FluiSpacing.lg),
        _SessionCard(overview: overview),
        if (overview.dueCount > 0) ...[
          const SizedBox(height: FluiSpacing.xs),
          Center(
            child: FluiButton.text(
              label: l10n.todayExtraReview,
              onPressed: () => context.go(AppRoutes.sessionReview),
            ),
          ),
        ],
        const SizedBox(height: FluiSpacing.lg),
        _Stats(overview: overview),
        if (word != null && !overview.completed) ...[
          const SizedBox(height: FluiSpacing.lg),
          FluiCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.todayWordTitle,
                        style: FluiTypography.label.copyWith(
                          color: FluiColors.gray,
                        ),
                      ),
                      const SizedBox(height: FluiSpacing.xxs),
                      Text(
                        word.lemma,
                        style: FluiTypography.h2.copyWith(
                          color: FluiColors.charcoal,
                        ),
                      ),
                    ],
                  ),
                ),
                const StateChip(state: WordStateKind.nueva),
              ],
            ),
          ),
        ],
        if (overview.reviewCount > 0 && !overview.completed) ...[
          const SizedBox(height: FluiSpacing.md),
          Text(
            l10n.todayReviews(overview.reviewCount),
            style: FluiTypography.bodyEmphasis.copyWith(
              color: FluiColors.charcoal,
            ),
          ),
        ],
        const SizedBox(height: FluiSpacing.xl),
        const _ContextScenes(),
      ],
    );
  }
}

/// Three numbers, and never a bare "0" as the hero: while the mastery gate
/// is closed, the words in practice are the honest headline.
class _Stats extends StatelessWidget {
  const new({required this.overview});

  final TodayOverview overview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final precision = overview.precisionPercent;
    final owned = overview.showsOwnedHero;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StatTile(
                value: owned
                    ? '${overview.ownedWords}'
                    : '${overview.practiceWords}',
                label: owned ? l10n.statOwnedWords : l10n.statPracticeWords,
              ),
            ),
            const SizedBox(width: FluiSpacing.xs),
            Expanded(
              child: StatTile(
                value: owned
                    ? '${overview.practiceWords}'
                    : '${overview.activeDays}',
                label: owned ? l10n.statPracticeWords : l10n.statActiveDays,
              ),
            ),
            const SizedBox(width: FluiSpacing.xs),
            Expanded(
              child: StatTile(
                value: precision == null
                    ? l10n.commonNoData
                    : l10n.statPrecisionValue(precision),
                label: l10n.statPrecisionLabel,
              ),
            ),
          ],
        ),
        const SizedBox(height: FluiSpacing.xs),
        Text(
          l10n.progressWeekDays(overview.activeDaysThisWeek),
          style: FluiTypography.caption.copyWith(color: FluiColors.gray),
        ),
        if (!owned)
          Text(
            l10n.statTowardsFirstOwned,
            style: FluiTypography.caption.copyWith(color: FluiColors.gray),
          ),
      ],
    );
  }
}

/// A few scenes of the user's own words, so an empty day still has something
/// worth opening.
class _ContextScenes extends ConsumerWidget {
  const new();

  static const _limit = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final readings = ref.watch(contextReadingsProvider).value ?? const [];
    if (readings.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l10n.todayContextTitle),
        for (final item in readings.take(_limit)) ...[
          Text(
            item.word.lemma,
            style: FluiTypography.label.copyWith(
              color: FluiColors.greenSecondary,
            ),
          ),
          const SizedBox(height: FluiSpacing.xxs),
          ReadingCard(reading: item.reading, forms: item.word.forms),
          const SizedBox(height: FluiSpacing.md),
        ],
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const new({required this.overview});

  final TodayOverview overview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = overview.session;

    if (overview.completed) {
      return DecoratedBox(
        decoration: const BoxDecoration(
          color: FluiColors.greenTint,
          borderRadius: FluiRadii.lgAll,
        ),
        child: Padding(
          padding: const EdgeInsets.all(FluiSpacing.lg),
          child: Row(
            children: [
              const Icon(LucideIcons.circle_check, color: FluiColors.greenDeep),
              const SizedBox(width: FluiSpacing.md),
              Expanded(
                child: Text(
                  l10n.todayDone,
                  style: FluiTypography.h3.copyWith(
                    color: FluiColors.greenDeep,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (session == null) {
      return FluiCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.todayNoSession,
              style: FluiTypography.body.copyWith(color: FluiColors.charcoal),
            ),
            const SizedBox(height: FluiSpacing.md),
            FluiButton.primary(
              label: l10n.todayChooseTime,
              onPressed: () => context.go(AppRoutes.timeBudget),
            ),
          ],
        ),
      );
    }

    if (overview.emptyPlan) return _EmptyPlanCard(overview: overview);

    return FluiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: FluiColors.greenDeep,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(FluiSpacing.xs),
                  child: Icon(
                    LucideIcons.clock,
                    color: FluiColors.cream,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: FluiSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.todaySessionTitle,
                      style: FluiTypography.label.copyWith(
                        color: FluiColors.gray,
                      ),
                    ),
                    Text(
                      l10n.todaySessionMinutes(session.minutes),
                      style: FluiTypography.h3.copyWith(
                        color: FluiColors.charcoal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (overview.afianzar) ...[
            const SizedBox(height: FluiSpacing.sm),
            Text(
              l10n.todayAfianzar,
              style: FluiTypography.bodyEmphasis.copyWith(
                color: FluiColors.greenSecondary,
              ),
            ),
          ],
          const SizedBox(height: FluiSpacing.md),
          FluiButton.primary(
            label: overview.started ? l10n.todayContinue : l10n.todayStart,
            onPressed: () => context.go(AppRoutes.session),
          ),
          if (!overview.started) ...[
            const SizedBox(height: FluiSpacing.xs),
            Center(
              child: FluiButton.text(
                label: l10n.todayChangeTime,
                onPressed: () => context.go(AppRoutes.timeBudget),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// An empty day says which of the three things happened and offers the one
/// action that actually helps. Suggesting 10 minutes to a user who finished
/// the catalog is a dead end, not advice.
class _EmptyPlanCard extends StatelessWidget {
  const new({required this.overview});

  final TodayOverview overview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reason = overview.emptyReason ?? EmptyPlanReason.budgetTooSmall;
    final next = overview.nextReviewOn;
    final message = switch (reason) {
      EmptyPlanReason.budgetTooSmall => l10n.todayEmptyPlan,
      EmptyPlanReason.noCandidatesLeft => l10n.todayNoCandidates,
      EmptyPlanReason.allReviewsDone => l10n.todayBlockedCandidates,
    };
    final offersFreeRun =
        reason != EmptyPlanReason.budgetTooSmall && overview.canReviewFreely;

    return FluiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            style: FluiTypography.body.copyWith(color: FluiColors.charcoal),
          ),
          if (next != null) ...[
            const SizedBox(height: FluiSpacing.xs),
            Text(
              l10n.todayNextReviews(
                overview.nextReviewCount,
                formatLongDate(next.toDateTime()),
              ),
              style: FluiTypography.bodyEmphasis.copyWith(
                color: FluiColors.greenSecondary,
              ),
            ),
          ],
          const SizedBox(height: FluiSpacing.md),
          if (offersFreeRun) ...[
            FluiButton.primary(
              label: l10n.todayFreeReview,
              onPressed: () => context.go(AppRoutes.sessionFree),
            ),
            const SizedBox(height: FluiSpacing.xxs),
            Text(
              l10n.todayFreeReviewHint,
              textAlign: TextAlign.center,
              style: FluiTypography.caption.copyWith(color: FluiColors.gray),
            ),
            const SizedBox(height: FluiSpacing.xs),
            Center(
              child: FluiButton.text(
                label: l10n.todayChangeTime,
                onPressed: () => context.go(AppRoutes.timeBudget),
              ),
            ),
          ] else
            FluiButton.primary(
              label: reason == EmptyPlanReason.budgetTooSmall
                  ? l10n.todayEmptyPlanAction
                  : l10n.todayChangeTime,
              onPressed: () => context.go(AppRoutes.timeBudget),
            ),
        ],
      ),
    );
  }
}
