import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/l10n/failure_messages.dart';
import 'package:flui/core/l10n/formatters.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/daily/domain/session_plan.dart';
import 'package:flui/features/daily/presentation/providers/daily_providers.dart';
import 'package:flui/features/daily/presentation/providers/learning_data_controller.dart';
import 'package:flui/features/daily/presentation/providers/today_overview.dart';
import 'package:flui/features/profile/presentation/widgets/week_dots.dart';
import 'package:flui/features/reading/presentation/providers/context_readings.dart';
import 'package:flui/features/reading/presentation/widgets/reading_card.dart';
import 'package:flui/features/themes/domain/theme.dart';
import 'package:flui/features/vocabulary/presentation/providers/vocabulary_providers.dart';
import 'package:flui/shared/layout/bento_layout.dart';
import 'package:flui/shared/widgets/bento_grid.dart';
import 'package:flui/shared/widgets/empty_state.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_glyph.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:flui/shared/widgets/loading_wave.dart';
import 'package:flui/shared/widgets/page_frame.dart';
import 'package:flui/shared/widgets/sticky_cta_dock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// The domain entity is called Theme, like Flutter's inherited widget; this
// screen needs the entity, never the widget.
import 'package:material_ui/material_ui.dart' hide Theme;

/// "Hoy": an asymmetric bento that reaches the fold, and the one action of
/// the day docked at the bottom instead of floating over empty space.
class TodayPage extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final overview = ref.watch(todayOverviewProvider);
    return Scaffold(
      body: switch (overview) {
        AsyncValue(hasValue: true, :final value?) => _TodayScaffold(
          overview: value,
        ),
        AsyncError(:final error) => SafeArea(
          child: SingleChildScrollView(
            child: PageFrame(
              child: Padding(
                padding: const EdgeInsets.only(top: FluiSpacing.xl),
                child: EmptyState(
                  title: l10n.todayLoadError,
                  message: error is Failure
                      ? failureMessage(l10n, error)
                      : l10n.errorUnexpected,
                  actionLabel: l10n.commonRetry,
                  onAction: () => retryLearningData(ref),
                ),
              ),
            ),
          ),
        ),
        _ => Center(child: LoadingWave(semanticLabel: l10n.commonLoading)),
      },
    );
  }
}

/// Reloads the catalog and the learning data after a failure.
void retryLearningData(WidgetRef ref) {
  final userId = ref.read(currentUserIdProvider);
  ref.invalidate(catalogProvider);
  if (userId != null) ref.invalidate(learningDataControllerProvider(userId));
}

/// What the day's single action is, and what it is called.
@immutable
final class TodayAction {
  const new({required this.label, required this.route, this.hint});

  /// `null` when the day is done and there is nothing honest left to offer.
  static TodayAction? of(AppLocalizations l10n, TodayOverview overview) {
    if (overview.session == null) {
      return TodayAction(
        label: l10n.todayChooseTime,
        route: AppRoutes.timeBudget,
      );
    }
    if (overview.completed) {
      return overview.canReviewFreely
          ? TodayAction(
              label: l10n.todayFreeReview,
              route: AppRoutes.sessionFree,
              hint: l10n.todayFreeReviewHint,
            )
          : null;
    }
    if (overview.emptyPlan) {
      final reason = overview.emptyReason ?? EmptyPlanReason.budgetTooSmall;
      if (reason != EmptyPlanReason.budgetTooSmall &&
          overview.canReviewFreely) {
        return TodayAction(
          label: l10n.todayFreeReview,
          route: AppRoutes.sessionFree,
          hint: l10n.todayFreeReviewHint,
        );
      }
      return TodayAction(
        label: reason == EmptyPlanReason.budgetTooSmall
            ? l10n.todayEmptyPlanAction
            : l10n.todayChangeTime,
        route: AppRoutes.timeBudget,
      );
    }
    return TodayAction(
      label: overview.started ? l10n.todayContinue : l10n.todayStart,
      route: AppRoutes.session,
      hint: l10n.todaySessionMinutes(overview.session!.minutes),
    );
  }

  final String label;
  final String route;
  final String? hint;
}

class _TodayScaffold extends StatelessWidget {
  const new({required this.overview});

  final TodayOverview overview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layout = context.layout;
    final action = TodayAction.of(l10n, overview);
    final name = overview.name;

    final page = SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: action == null ? 0 : StickyCtaDock.reservedHeight,
        ),
        child: PageFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: layout.blockGap),
              PageHeader(
                title: name == null
                    ? l10n.progressGreetingAnonymous
                    : l10n.progressGreeting(name),
                subtitle: _subtitleFor(l10n, overview),
              ),
              if (overview.theme case final theme?) ...[
                const SizedBox(height: FluiSpacing.md),
                _TodayTheme(theme: theme, overview: overview),
              ],
              SizedBox(height: layout.blockGap),
              _TodayBento(overview: overview),
              SizedBox(height: layout.sectionGap),
              const _ContextScenes(),
            ],
          ),
        ),
      ),
    );

    if (action == null) return page;
    return StickyCtaDock(
      dock: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FluiButton.primary(
            label: action.label,
            onPressed: () => context.go(action.route),
          ),
          if (action.hint case final hint?) ...[
            const SizedBox(height: FluiSpacing.xs),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: layout.type.body.copyWith(color: FluiColors.gray),
            ),
          ],
          // The budget stays changeable until the day has started.
          if (!overview.started &&
              overview.session != null &&
              !overview.completed)
            FluiButton.text(
              label: l10n.todayChangeTime,
              onPressed: () => context.go(AppRoutes.timeBudget),
            ),
        ],
      ),
      child: page,
    );
  }

  /// The honest one-liner under the greeting.
  static String _subtitleFor(AppLocalizations l10n, TodayOverview overview) {
    if (overview.completed) return l10n.todayDone;
    if (overview.session == null) return l10n.todayNoSession;
    if (overview.emptyPlan) {
      return switch (overview.emptyReason ?? EmptyPlanReason.budgetTooSmall) {
        EmptyPlanReason.budgetTooSmall => l10n.todayEmptyPlan,
        EmptyPlanReason.noCandidatesLeft => l10n.todayNoCandidates,
        EmptyPlanReason.allReviewsDone => l10n.todayBlockedCandidates,
      };
    }
    if (overview.afianzar) return l10n.todayAfianzar;
    return l10n.todaySubtitle;
  }
}

/// The theme of the day, and the one tap that changes it.
///
/// When the theme could not supply today's word, this is where the day says
/// so. A silent substitution would be the same screen either way, and a user
/// who picked "Entrevistas" deserves to know the word came from somewhere
/// else.
class _TodayTheme extends StatelessWidget {
  const new({required this.theme, required this.overview});

  final Theme theme;
  final TodayOverview overview;

  /// The cascade, in words. `null` when the day is on theme.
  static String? fallbackMessage(
    AppLocalizations l10n,
    TodayOverview overview,
  ) {
    final theme = overview.theme;
    if (theme == null) return null;
    final other = overview.otherTheme;
    return switch (overview.themeFallback) {
      null => null,
      ThemeFallback.themedPractice => l10n.todayThemeFallbackPractice(
        theme.name,
      ),
      ThemeFallback.neighbourTheme || ThemeFallback.globalCatalog =>
        other == null
            ? l10n.todayThemeFallbackCatalog(theme.name)
            : l10n.todayThemeFallbackOther(theme.name, other.name),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    final message = fallbackMessage(l10n, overview);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const FluiGlyphIcon(
              FluiGlyph.onda,
              color: FluiColors.greenSecondary,
            ),
            const SizedBox(width: FluiSpacing.xs),
            Expanded(child: FluiLabel(l10n.todayThemeLabel)),
            // Changing theme is free and always available: no minimum streak,
            // no "you are on a roll with Reuniones".
            FluiButton.text(
              label: l10n.todayChangeTheme,
              onPressed: () => context.go(AppRoutes.timeBudget),
            ),
          ],
        ),
        Text(
          theme.name,
          style: type.titleM.copyWith(color: FluiColors.greenDeep),
        ),
        if (message != null) ...[
          const SizedBox(height: FluiSpacing.xxs),
          Text(message, style: type.body.copyWith(color: FluiColors.gray)),
        ],
      ],
    );
  }
}

class _TodayBento extends StatelessWidget {
  const new({required this.overview});

  final TodayOverview overview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    final word = overview.newWords.firstOrNull;
    final precision = overview.precisionPercent;
    final owned = overview.showsOwnedHero;
    // Before the first word there is nothing to count, and a tile reading
    // "0" is the trope this screen exists to avoid.
    final counts = owned || overview.practiceWords > 0;

    return BentoGrid(
      tiles: [
        // The 2x2 anchor: the week, in the one dark tile of the screen.
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
                    child: FluiLabel(l10n.todayBentoStreakLabel, onDark: true),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                // Has a zero case of its own: "Tu racha empieza con tu
                // próxima sesión".
                l10n.progressStreak(overview.streak),
                style: type.titleL.copyWith(color: FluiColors.cream),
              ),
              const SizedBox(height: FluiSpacing.xs),
              Text(
                l10n.progressWeekDays(overview.activeDaysThisWeek),
                style: type.body.copyWith(color: FluiColors.creamMuted),
              ),
              const SizedBox(height: FluiSpacing.md),
              WeekDots(activeDays: overview.weekDays),
            ],
          ),
        ),
        if (word != null && !overview.completed)
          BentoTile(
            span: BentoSpan.wide,
            tone: BentoTone.yellow,
            onTap: () => context.go(AppRoutes.wordDetail(word.id)),
            semanticLabel: '${l10n.todayWordTitle}: ${word.lemma}',
            child: Row(
              children: [
                const FluiGlyphIcon(
                  FluiGlyph.wordOfTheDay,
                  color: FluiColors.charcoal,
                ),
                const SizedBox(width: FluiSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FluiLabel(
                        l10n.todayWordTitle,
                        color: FluiColors.charcoal,
                      ),
                      Text(
                        word.lemma,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.titleM.copyWith(color: FluiColors.charcoal),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else if (overview.dueCount > 0)
          BentoTile(
            span: BentoSpan.wide,
            onTap: () => context.go(AppRoutes.sessionReview),
            semanticLabel: l10n.todayExtraReview,
            child: Row(
              children: [
                const FluiGlyphIcon(
                  FluiGlyph.review,
                  color: FluiColors.greenSecondary,
                ),
                const SizedBox(width: FluiSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FluiLabel(l10n.todayExtraReview),
                      Text(
                        l10n.todayReviews(overview.dueCount),
                        style: type.body.copyWith(color: FluiColors.charcoal),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else if (overview.nextReviewOn case final next?)
          BentoTile(
            span: BentoSpan.wide,
            child: Row(
              children: [
                const FluiGlyphIcon(
                  FluiGlyph.review,
                  color: FluiColors.greenSecondary,
                ),
                const SizedBox(width: FluiSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.todayNextReviews(
                      overview.nextReviewCount,
                      formatLongDate(next.toDateTime()),
                    ),
                    style: type.body.copyWith(color: FluiColors.charcoal),
                  ),
                ),
              ],
            ),
          ),
        if (counts)
          _numberTile(
            context,
            value: owned
                ? '${overview.ownedWords}'
                : '${overview.practiceWords}',
            label: owned ? l10n.statOwnedWords : l10n.statPracticeWords,
            glyph: owned ? FluiGlyph.achievement : FluiGlyph.review,
          ),
        if (precision != null)
          _numberTile(
            context,
            value: l10n.statPrecisionValue(precision),
            label: l10n.statPrecisionLabel,
            glyph: FluiGlyph.goal,
          ),
        if (!owned)
          // A sentence needs width: this one is never squeezed into a cell.
          BentoTile(
            span: BentoSpan.wide,
            semanticLabel: l10n.statTowardsFirstOwned,
            child: Row(
              children: [
                const FluiGlyphIcon(
                  FluiGlyph.goal,
                  color: FluiColors.greenSecondary,
                ),
                const SizedBox(width: FluiSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.statTowardsFirstOwned,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: type.body.copyWith(color: FluiColors.charcoal),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// A number that is only ever rendered when there is something to count.
  BentoTile _numberTile(
    BuildContext context, {
    required String value,
    required String label,
    required FluiGlyph glyph,
  }) {
    final type = context.type;
    return BentoTile(
      span: BentoSpan.small,
      semanticLabel: '$value $label',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FluiGlyphIcon(glyph, color: FluiColors.greenSecondary),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: type.titleL.copyWith(color: FluiColors.charcoal),
            ),
          ),
          FluiLabel(label),
        ],
      ),
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
        SectionHeader(
          title: l10n.todayContextTitle,
          glyph: const FluiGlyphIcon(FluiGlyph.inContext),
        ),
        for (final item in readings.take(_limit)) ...[
          ReadingCard(reading: item.reading, forms: item.word.forms),
          const SizedBox(height: FluiSpacing.sm),
        ],
      ],
    );
  }
}
