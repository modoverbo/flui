import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/core/l10n/failure_messages.dart';
import 'package:flui/core/l10n/formatters.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/mic/presentation/mic_target_scope.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_motion.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_theme_colors.dart';
import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:flui/features/daily/domain/session_plan.dart';
import 'package:flui/features/daily/domain/time_budget.dart';
import 'package:flui/features/daily/presentation/category_artwork.dart';
import 'package:flui/features/daily/presentation/controllers/plan_today.dart';
import 'package:flui/features/daily/presentation/controllers/time_budget_controller.dart';
import 'package:flui/features/daily/presentation/controllers/today_start_target.dart';
import 'package:flui/features/daily/presentation/providers/daily_providers.dart';
import 'package:flui/features/daily/presentation/providers/learning_data_controller.dart';
import 'package:flui/features/daily/presentation/providers/today_overview.dart';
import 'package:flui/features/profile/presentation/widgets/week_dots.dart';
import 'package:flui/features/reading/presentation/providers/context_readings.dart';
import 'package:flui/features/reading/presentation/widgets/reading_card.dart';
import 'package:flui/features/themes/domain/theme.dart';
import 'package:flui/features/themes/presentation/widgets/theme_explorer_sheet.dart';
import 'package:flui/features/training/domain/training_planner.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/features/vocabulary/presentation/providers/vocabulary_providers.dart';
import 'package:flui/shared/widgets/card_stack.dart';
import 'package:flui/shared/widgets/editorial_stat.dart';
import 'package:flui/shared/widgets/empty_state.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_glyph.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:flui/shared/widgets/loading_wave.dart';
import 'package:flui/shared/widgets/page_frame.dart';
import 'package:flui/shared/widgets/sticky_cta_dock.dart';
import 'package:flui/shared/widgets/training_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// The domain entity is called Theme, like Flutter's inherited widget; this
// screen needs the entity, never the widget.
import 'package:material_ui/material_ui.dart' hide Theme;

/// "Hoy": today's workout, not a dashboard. The front card of a small stack
/// is the one unmistakable action of the day; everything else — the theme,
/// the streak, the editorial numbers — is secondary and reachable below it.
///
/// Registers `TodayStartTarget` with the shell's mic via `MicTargetScope`
/// (U15a, design D41).
class TodayPage extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final overview = ref.watch(todayOverviewProvider);
    final body = Scaffold(
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
    final target = ref.watch(todayStartTargetProvider)
      ..onSessionStarted = () => context.go(AppRoutes.todayTrain);
    return MicTargetScope(target: target, child: body);
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

/// The honest one-liner under the greeting — reused as the stack's front
/// card message whenever there is no word or review to lead with.
String todaySubtitleFor(AppLocalizations l10n, TodayOverview overview) {
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
                subtitle: todaySubtitleFor(l10n, overview),
              ),
              const SizedBox(height: FluiSpacing.lg),
              _TrainingGoalCard(session: overview.session),
              const SizedBox(height: FluiSpacing.lg),
              const _SpeakingWorkoutCard(),
              const SizedBox(height: FluiSpacing.lg),
              const _CategoryDeck(),
              if (overview.theme case final theme?) ...[
                const SizedBox(height: FluiSpacing.md),
                _TodayTheme(theme: theme, overview: overview),
              ],
              if (_TodayStack.hasContent(overview)) ...[
                SizedBox(height: layout.blockGap),
                _TodayStack(overview: overview),
              ],
              SizedBox(height: layout.blockGap),
              _TodayStreakBlock(overview: overview),
              SizedBox(height: layout.sectionGap),
              _TodayEditorialStats(overview: overview),
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
}

/// The five existing content families as a browsable, horizontal card deck.
/// The overlapping paper layers are decorative; each card is independently
/// focusable and opens immediately, with no animation gate or extra picker.
class _CategoryDeck extends StatefulWidget {
  const new();

  @override
  State<_CategoryDeck> createState() => _CategoryDeckState();
}

class _CategoryDeckState extends State<_CategoryDeck> {
  late final PageController _pageController = PageController(
    viewportFraction: 0.84,
  );

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _movePage(BuildContext context, int delta) {
    if (!_pageController.hasClients) return;
    final currentPage = _pageController.page?.round() ?? 0;
    final targetPage = (currentPage + delta).clamp(
      0,
      ThemeFamily.values.length - 1,
    );
    if (FluiMotion.reduced(context)) {
      _pageController.jumpToPage(targetPage);
      return;
    }
    _pageController.animateToPage(
      targetPage,
      duration: FluiMotion.standard,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layout = context.layout;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.categoryDeckTitle, style: layout.type.titleL),
        const SizedBox(height: FluiSpacing.xs),
        Text(l10n.categoryDeckSubtitle, style: layout.type.body),
        const SizedBox(height: FluiSpacing.md),
        SizedBox(
          height: 216,
          child: LayoutBuilder(
            builder: (context, constraints) => PageView.builder(
              key: const ValueKey('category-deck'),
              controller: _pageController,
              itemCount: ThemeFamily.values.length,
              itemBuilder: (context, index) => AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  final page = _pageController.hasClients
                      ? _pageController.page ??
                            _pageController.initialPage.toDouble()
                      : _pageController.initialPage.toDouble();
                  final progress = (page - index).clamp(-1.0, 1.0);
                  final distance = progress.abs();
                  final isIncoming = progress < 0;
                  final scale = isIncoming
                      ? 0.74 + ((1 - distance) * 0.26)
                      : 1 - (distance * 0.08);
                  final horizontalOffset =
                      progress * constraints.maxWidth * 0.65;
                  final verticalOffset = isIncoming
                      ? distance * 32
                      : -distance * 30;
                  final depthOffset = isIncoming
                      ? -distance * 80
                      : distance * 60;
                  final transform = Matrix4.identity()
                    ..setEntry(3, 2, 0.0016)
                    ..translateByDouble(
                      horizontalOffset,
                      verticalOffset,
                      depthOffset,
                      1,
                    )
                    ..rotateY(-progress * 0.42)
                    ..rotateX(distance * (isIncoming ? 0.12 : -0.1))
                    ..scaleByDouble(scale, scale, 1, 1);
                  return Transform(
                    key: ValueKey('category-card-transform-$index'),
                    alignment: Alignment.center,
                    transform: transform,
                    child: child,
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: FluiSpacing.sm),
                  child: _CategoryDeckCard(
                    family: ThemeFamily.values[index],
                    index: index,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: FluiSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              tooltip: l10n.categoryDeckPrevious,
              onPressed: () => _movePage(context, -1),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            IconButton(
              tooltip: l10n.categoryDeckNext,
              onPressed: () => _movePage(context, 1),
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
          ],
        ),
      ],
    );
  }
}

class _CategoryDeckCard extends StatelessWidget {
  const new({required this.family, required this.index});

  final ThemeFamily family;
  final int index;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = themeFamilyLabel(l10n, family);
    final color = CategoryArtwork.cardColorFor(family);
    const families = ThemeFamily.values;
    const ink = FluiColors.ink;
    return Semantics(
      button: true,
      label: label,
      onTap: () => context.push(AppRoutes.categoryCatalog(family.name)),
      excludeSemantics: true,
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          children: [
            for (var layer = 0; layer < 3; layer++)
              Positioned(
                left: 8 + (layer * 4),
                right: layer * 2,
                top: 8 + (layer * 5),
                bottom: 0,
                child: ExcludeSemantics(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      key: ValueKey('category-card-back-$index-$layer'),
                      decoration: BoxDecoration(
                        color: CategoryArtwork.cardColorFor(
                          families[(index + layer + 1) % families.length],
                        ),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: FluiColors.ink),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              right: 18,
              bottom: 12,
              child: AnimatedContainer(
                key: ValueKey('category-card-${family.name}'),
                duration: FluiMotion.resolve(context, FluiMotion.quick),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: FluiColors.ink, width: 1.5),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () =>
                        context.push(AppRoutes.categoryCatalog(family.name)),
                    borderRadius: BorderRadius.circular(26),
                    child: Padding(
                      padding: const EdgeInsets.all(FluiSpacing.ml),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${index + 1}'.padLeft(2, '0'),
                                  style: context.type.label.copyWith(
                                    color: ink,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 92,
                                height: 72,
                                child: CategoryArtwork(family: family),
                              ),
                            ],
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Text(
                                  label,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.type.titleL.copyWith(
                                    color: ink,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.arrow_outward_rounded,
                                semanticLabel: '',
                                color: FluiColors.ink,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A provisional (never persisted) preview of today's speaking goal at the
/// requested `TimeBudget` — recomputed whenever the chip selection
/// changes, so the card re-plans in memory without writing anything until
/// START/the mic is tapped (design part-3 §11, U15a).
// ignore: specify_nonobvious_property_types
final _provisionalTrainingGoalProvider = FutureProvider.autoDispose
    .family<DailyTrainingPlan?, TimeBudget>(
      (ref, budget) => ref.read(planTodayProvider).previewTrainingGoal(budget),
    );

/// HOY's budget-free speaking-goal card (U15a, design D41, decision
/// #450.4).
///
/// With NO [session] yet: duration chips (preselected via
/// `preselectedBudgetProvider`), a provisional plan preview, and a START
/// button that calls `PlanToday.run` then navigates to
/// `AppRoutes.todayTrain`. With a [session] already planned: the same card
/// shows its persisted goal and a "Continuar" button that only navigates
/// (the plan was already saved — see `TodayStartTarget`'s own equivalent
/// mic-driven path for the exact same two states).
class _TrainingGoalCard extends ConsumerWidget {
  const new({required this.session});

  final DailySession? session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final type = context.type;
    final existingBudget = session == null
        ? null
        : TimeBudget.tryFromMinutes(session!.minutes);
    final selected =
        existingBudget ??
        ref.watch(todaySelectedBudgetProvider) ??
        ref.watch(preselectedBudgetProvider).value ??
        TimeBudget.fallback;
    final preview = session == null
        ? ref.watch(_provisionalTrainingGoalProvider(selected)).value
        : null;
    final prompt = existingBudget != null
        ? null // The persisted plan speaks for itself once /today/train opens.
        : (preview?.challenge?.prompt ?? l10n.todayTrainingGoalUnavailable);

    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: FluiColors.greenTint,
          borderRadius: FluiRadii.cardAll,
          border: Border.all(color: FluiColors.greenDeep, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(FluiSpacing.ml),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FluiLabel(l10n.todayTrainingGoalLabel),
              const SizedBox(height: FluiSpacing.xs),
              Text(
                prompt ?? l10n.todayTrainingGoalSubtitle,
                style: type.titleM.copyWith(color: FluiColors.charcoal),
              ),
              const SizedBox(height: FluiSpacing.md),
              Wrap(
                spacing: FluiSpacing.sm,
                children: [
                  for (final budget in TimeBudget.values)
                    ChoiceChip(
                      label: Text('${budget.minutes} min'),
                      selected: budget == selected,
                      onSelected: existingBudget != null
                          ? null
                          : (_) => ref
                                .read(todaySelectedBudgetProvider.notifier)
                                .select(budget),
                    ),
                ],
              ),
              const SizedBox(height: FluiSpacing.md),
              FluiButton.primary(
                label: existingBudget != null
                    ? l10n.todayContinue
                    : l10n.todayStart,
                onPressed: () async {
                  if (existingBudget == null) {
                    final result = await ref
                        .read(planTodayProvider)
                        .run(budget: selected);
                    if (result case Err()) return;
                  }
                  if (context.mounted) context.go(AppRoutes.todayTrain);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The always-available entry point to Habla: a soft, neutral integration
/// (`docs/redesign/02-navigation-model.md` §1) — speaking is not tied to a
/// theme, so it never borrows a theme colour (`01-design-system.md` §1.3).
class _SpeakingWorkoutCard extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    return Semantics(
      button: true,
      label: 'Entrena tu voz, desafío de 45 segundos',
      child: InkWell(
        onTap: () => context.push(AppRoutes.speakingChallenge),
        borderRadius: FluiRadii.cardAll,
        child: Ink(
          padding: const EdgeInsets.all(FluiSpacing.ml),
          decoration: BoxDecoration(
            color: FluiColors.greenTint,
            borderRadius: FluiRadii.cardAll,
            border: Border.all(color: FluiColors.greenDeep, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: FluiColors.greenDeep,
                  shape: BoxShape.circle,
                ),
                child: const FluiGlyphIcon(
                  FluiGlyph.microphone,
                  color: FluiColors.cream,
                ),
              ),
              const SizedBox(width: FluiSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FluiLabel('TU GIMNASIO DE HOY'),
                    const SizedBox(height: 3),
                    Text(
                      'Entrena tu voz',
                      style: type.titleM.copyWith(color: FluiColors.charcoal),
                    ),
                    Text(
                      'Pausa de poder · 45 s',
                      style: type.body.copyWith(color: FluiColors.gray),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: FluiColors.greenDeep,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The theme of the day, and the one tap that changes it. Its name renders
/// in that theme's own colour — one of the 28 (`01-design-system.md` §1.2)
/// — instead of a fixed green, so the theme reads as itself.
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
    final accent = FluiThemeColors.resolve(theme.slug).surface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            FluiGlyphIcon(FluiGlyph.onda, color: accent),
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
        Text(theme.name, style: type.titleM.copyWith(color: accent)),
        if (message != null) ...[
          const SizedBox(height: FluiSpacing.xxs),
          Text(message, style: type.body.copyWith(color: FluiColors.gray)),
        ],
      ],
    );
  }
}

/// The front card of a small stack that previews what is coming: today's
/// one thing to do up front — the new word or the extra reviews — with a
/// peek of what is behind it (`docs/redesign/08-screen-plan.md` —
/// TodayPage). Rendered only when there is something to lead with; an
/// empty, done or session-less day already says so once, in the page's
/// subtitle — the stack never repeats it.
class _TodayStack extends StatelessWidget {
  const new({required this.overview});

  final TodayOverview overview;

  /// Whether [overview] has a word or a review to show up front.
  static bool hasContent(TodayOverview overview) {
    if (overview.completed) return false;
    return overview.newWords.isNotEmpty ||
        overview.dueCount > 0 ||
        overview.nextReviewOn != null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final themeSlug = overview.theme?.slug;
    final word = overview.newWords.firstOrNull;
    final showsWord = word != null;

    final next = overview.nextReviewOn;
    final Widget frontChild;
    final Key frontKey;
    if (showsWord) {
      frontChild = _TodayWordCard(word: word);
      frontKey = ValueKey('today-word-${word.id}');
    } else if (overview.dueCount > 0) {
      frontChild = _TodayExtraReviewCard(overview: overview);
      frontKey = const ValueKey('today-extra-review');
    } else {
      // hasContent guarantees nextReviewOn is set when the two branches
      // above are not taken.
      frontChild = _TodayNextReviewCard(overview: overview, next: next!);
      frontKey = ValueKey('today-next-review-$next');
    }

    final cards = <Widget>[
      TrainingCard(key: frontKey, themeSlug: themeSlug, child: frontChild),
    ];

    // Only the word front card leaves the due/next-review peek unclaimed;
    // every other front already used it.
    if (showsWord && overview.dueCount > 0) {
      cards.add(
        TrainingCard(
          key: const ValueKey('today-peek-reviews'),
          position: cards.length,
          themeSlug: themeSlug,
          child: _TodayPeekCard(
            glyph: FluiGlyph.review,
            headline: l10n.todayExtraReview,
            caption: l10n.todayReviews(overview.dueCount),
          ),
        ),
      );
    } else if (showsWord && next != null) {
      cards.add(
        TrainingCard(
          key: ValueKey('today-peek-next-review-$next'),
          position: cards.length,
          themeSlug: themeSlug,
          child: _TodayPeekCard(
            glyph: FluiGlyph.review,
            headline: l10n.todayNextReviews(
              overview.nextReviewCount,
              formatLongDate(next.toDateTime()),
            ),
          ),
        ),
      );
    }

    if (cards.length < 3) {
      cards.add(
        TrainingCard(
          key: const ValueKey('today-peek-speaking'),
          position: cards.length,
          child: const _TodayPeekCard(
            glyph: FluiGlyph.microphone,
            headline: 'Pausa de poder',
            caption: '45 s',
          ),
        ),
      );
    }

    return CardStack(cards: cards);
  }
}

/// Today's new word, at the same hero size a word gets everywhere else in
/// the app (`01-design-system.md` §2): a headword is never metadata.
class _TodayWordCard extends StatelessWidget {
  const new({required this.word});

  final Word word;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    return Semantics(
      button: true,
      label: '${l10n.todayWordTitle}: ${word.lemma}. ${l10n.todayOpenWord}',
      child: InkWell(
        onTap: () => context.go(AppRoutes.wordDetail(word.id)),
        child: Padding(
          padding: const EdgeInsets.all(FluiSpacing.ml),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FluiLabel(l10n.todayWordTitle),
              const SizedBox(height: FluiSpacing.xs),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  word.lemma,
                  maxLines: 1,
                  style: type.wordHero.copyWith(color: FluiColors.charcoal),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reviews due today beyond what the plan already covers — a number, not a
/// KPI tile, and one tap into a free review run.
class _TodayExtraReviewCard extends StatelessWidget {
  const new({required this.overview});

  final TodayOverview overview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(FluiSpacing.ml),
      child: EditorialStat(
        value: '${overview.dueCount}',
        label: l10n.todayExtraReview,
        caption: l10n.todayReviews(overview.dueCount),
        semanticLabel: l10n.todayExtraReview,
        onTap: () => context.go(AppRoutes.sessionReview),
      ),
    );
  }
}

/// The next day with reviews waiting, when nothing is due yet today.
class _TodayNextReviewCard extends StatelessWidget {
  const new({required this.overview, required this.next});

  final TodayOverview overview;
  final LocalDate next;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    return Padding(
      padding: const EdgeInsets.all(FluiSpacing.ml),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          l10n.todayNextReviews(
            overview.nextReviewCount,
            formatLongDate(next.toDateTime()),
          ),
          style: type.titleM.copyWith(color: FluiColors.charcoal),
        ),
      ),
    );
  }
}

/// A back-of-stack peek: themed, non-interactive, just enough to read "what
/// is coming" at a glance (mirrors `_PreviewCardContent` in
/// `session_page.dart`).
class _TodayPeekCard extends StatelessWidget {
  const new({required this.glyph, required this.headline, this.caption});

  final FluiGlyph glyph;
  final String headline;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final caption = this.caption;
    return Padding(
      padding: const EdgeInsets.all(FluiSpacing.ml),
      child: Row(
        children: [
          FluiGlyphIcon(glyph, color: FluiColors.greenSecondary),
          const SizedBox(width: FluiSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  headline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.titleM.copyWith(color: FluiColors.charcoal),
                ),
                if (caption != null)
                  Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.body.copyWith(color: FluiColors.gray),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The week, the streak, on the one dark accent block of the screen — an
/// editorial block, not a cell in a grid of identical ones.
class _TodayStreakBlock extends StatelessWidget {
  const new({required this.overview});

  final TodayOverview overview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: FluiColors.ink,
        borderRadius: FluiRadii.cardAll,
      ),
      child: Padding(
        padding: const EdgeInsets.all(FluiSpacing.lg),
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
            const SizedBox(height: FluiSpacing.sm),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                // Has a zero case of its own: "Tu racha empieza con tu
                // próxima sesión".
                l10n.progressStreak(overview.streak),
                style: type.displayL.copyWith(color: FluiColors.cream),
              ),
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
    );
  }
}

/// The rest of the numbers: editorial, secondary, and never a bare zero.
class _TodayEditorialStats extends StatelessWidget {
  const new({required this.overview});

  final TodayOverview overview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final owned = overview.showsOwnedHero;
    // Before the first word there is nothing to count, and a stat reading
    // "0" is the trope this screen exists to avoid.
    final counts = owned || overview.practiceWords > 0;
    final precision = overview.precisionPercent;

    final children = <Widget>[
      if (counts)
        SizedBox(
          width: 150,
          child: EditorialStat(
            value: owned
                ? '${overview.ownedWords}'
                : '${overview.practiceWords}',
            label: owned ? l10n.statOwnedWords : l10n.statPracticeWords,
          ),
        ),
      if (precision != null)
        SizedBox(
          width: 150,
          child: EditorialStat(
            value: l10n.statPrecisionValue(precision),
            label: l10n.statPrecisionLabel,
            caption: l10n.statPrecisionWindow,
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (children.isNotEmpty)
          Wrap(
            spacing: FluiSpacing.xl,
            runSpacing: FluiSpacing.lg,
            children: children,
          ),
        if (!owned) ...[
          if (children.isNotEmpty) const SizedBox(height: FluiSpacing.md),
          Semantics(
            label: l10n.statTowardsFirstOwned,
            child: ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FluiGlyphIcon(
                    FluiGlyph.goal,
                    color: FluiColors.greenSecondary,
                  ),
                  const SizedBox(width: FluiSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.statTowardsFirstOwned,
                      style: context.type.body.copyWith(
                        color: FluiColors.charcoal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
