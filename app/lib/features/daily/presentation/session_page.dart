import 'dart:async';

import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/l10n/failure_messages.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/mic/mic_providers.dart';
import 'package:flui/core/mic/presentation/mic_notice_host.dart';
import 'package:flui/core/mic/presentation/mic_target_scope.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/daily/domain/session_step.dart';
import 'package:flui/features/daily/presentation/controllers/session_controller.dart';
import 'package:flui/features/daily/presentation/providers/learning_data_controller.dart';
import 'package:flui/features/daily/presentation/widgets/session_summary_view.dart';
import 'package:flui/features/profile/domain/streak_calculator.dart';
import 'package:flui/features/reading/domain/reading.dart';
import 'package:flui/features/reading/presentation/widgets/readings_carousel.dart';
import 'package:flui/features/themes/domain/theme.dart' as taxonomy;
import 'package:flui/features/themes/presentation/providers/theme_providers.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/features/vocabulary/presentation/controllers/form_recall_mic_target.dart';
import 'package:flui/features/vocabulary/presentation/controllers/production_mic_target.dart';
import 'package:flui/features/vocabulary/presentation/widgets/cloze_view.dart';
import 'package:flui/features/vocabulary/presentation/widgets/form_recall_view.dart';
import 'package:flui/features/vocabulary/presentation/widgets/production_view.dart';
import 'package:flui/features/vocabulary/presentation/widgets/word_detail_view.dart';
import 'package:flui/features/vocabulary/presentation/word_state_kind.dart';
import 'package:flui/shared/widgets/card_stack.dart';
import 'package:flui/shared/widgets/empty_state.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_card.dart';
import 'package:flui/shared/widgets/flui_glyph.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:flui/shared/widgets/flui_notice.dart';
import 'package:flui/shared/widgets/flui_progress_bar.dart';
import 'package:flui/shared/widgets/loading_wave.dart';
import 'package:flui/shared/widgets/page_frame.dart';
import 'package:flui/shared/widgets/training_card.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// `/session`: the full-screen session runner (outside the shell).
class SessionPage extends ConsumerWidget {
  const new({super.key, this.mode = SessionMode.daily});

  final SessionMode mode;

  // Every mode is entered from Hoy now that "Practica" is a tab no longer.
  String get _exitLocation => AppRoutes.today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(sessionControllerProvider(mode));
    final scaffold = Scaffold(
      body: SafeArea(
        child: switch (session) {
          AsyncValue(hasValue: true, :final value?) => _SessionBody(
            state: value,
            controller: ref.read(sessionControllerProvider(mode).notifier),
            onExit: () => context.go(_exitLocation),
          ),
          AsyncError(:final error) => Center(
            child: EmptyState(
              title: l10n.sessionLoadError,
              message: error is Failure
                  ? failureMessage(l10n, error)
                  : l10n.errorUnexpected,
              actionLabel: l10n.commonRetry,
              onAction: () => ref.invalidate(sessionControllerProvider(mode)),
            ),
          ),
          _ => Center(child: LoadingWave(semanticLabel: l10n.commonLoading)),
        },
      ),
    );
    // `/session` is a root-navigator screen outside the shell (design D36),
    // so it never gets `AppShell`'s own `MicNoticeHost` — wired here
    // instead.
    return MicNoticeHost(
      controller: ref.watch(micControllerProvider),
      child: scaffold,
    );
  }
}

class _SessionBody extends StatelessWidget {
  const new({
    required this.state,
    required this.controller,
    required this.onExit,
  });

  final SessionState state;
  final SessionController controller;
  final VoidCallback onExit;

  Future<void> _confirmClose(BuildContext context) async {
    final l10n = context.l10n;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sessionCloseTitle),
        content: Text(l10n.sessionCloseBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.sessionCloseStay),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.sessionCloseLeave),
          ),
        ],
      ),
    );
    if (leave ?? false) onExit();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final flow = state.flow;
    final failure = state.failure;

    return Column(
      children: [
        if (!state.isFinished)
          PageFrame.column(
            child: Padding(
              padding: const EdgeInsets.only(top: FluiSpacing.sm),
              child: FluiCard(
                color: FluiColors.aqua,
                padding: const EdgeInsets.symmetric(
                  horizontal: FluiSpacing.xs,
                  vertical: FluiSpacing.xxs,
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: l10n.sessionCloseTooltip,
                      onPressed: () => unawaited(_confirmClose(context)),
                      icon: const Icon(LucideIcons.x),
                    ),
                    const SizedBox(width: FluiSpacing.xs),
                    FluiLabel(l10n.sessionStepOf(flow.position, flow.total)),
                    const SizedBox(width: FluiSpacing.sm),
                    Expanded(
                      child: FluiProgressBar(
                        value: flow.total == 0 ? 1 : flow.index / flow.total,
                        semanticLabel: l10n.sessionProgress(
                          flow.position,
                          flow.total,
                        ),
                        height: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (failure != null)
          PageFrame.column(
            child: Padding(
              padding: EdgeInsets.only(top: context.layout.blockGap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FluiNotice(message: failureMessage(l10n, failure)),
                  const SizedBox(height: FluiSpacing.sm),
                  FluiButton.outline(
                    label: l10n.commonRetry,
                    isLoading: state.saving,
                    onPressed: () => unawaited(controller.retrySave()),
                  ),
                ],
              ),
            ),
          ),
        // A fixed, layout-stable area: `CardStack` needs bounded height to
        // give every card the same stable geometry (`03-card-stack-spec.md`
        // §1) — a card's own content scrolls inside `TrainingCard` instead
        // of growing this region (unlike the old unbounded
        // `SingleChildScrollView` that used to wrap it, which let the front
        // card size the whole stack and hide the shorter preview cards).
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: context.layout.blockGap),
            child: PageFrame.column(
              child: _SessionCardStack(
                state: state,
                controller: controller,
                onExit: onExit,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Composes the current step (and up to two lookahead steps) into a
/// `CardStack` (`docs/redesign/03-card-stack-spec.md` §4,
/// `07-component-hierarchy.md`). This widget owns *which* card represents
/// each `SessionStep`; it hands `CardStack` already-built cards and stops
/// doing the transition itself. `SessionFlow`/`SessionController` are read
/// exactly as they were before — nothing here changes their behaviour.
class _SessionCardStack extends ConsumerWidget {
  const new({
    required this.state,
    required this.controller,
    required this.onExit,
  });

  final SessionState state;
  final SessionController controller;
  final VoidCallback onExit;

  /// Resolves a word's primary theme *id* to its taxonomy *slug*
  /// (`TrainingCard.themeSlug` only ever matches a slug, e.g. `reuniones` —
  /// never the raw UUID). Safe by construction: a themeless word, a
  /// taxonomy still loading, or an id no longer in the taxonomy all resolve
  /// to `null`, which `TrainingCard` already renders as its neutral
  /// fallback (mirrors `today_page.dart`'s `_TodayTheme`).
  static String? _themeSlugOf(
    Word? word,
    Map<String, taxonomy.Theme>? themesById,
  ) => themesById?[word?.themeIds.firstOrNull]?.slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themesById = ref.watch(themesByIdProvider).value;
    final step = state.step;
    final stepKey = step == null
        ? const ValueKey('summary')
        : ValueKey('${state.flow.index}-${step.runtimeType}');
    final frontCard = TrainingCard(
      key: stepKey,
      themeSlug: _themeSlugOf(state.word, themesById),
      child: _StepContent(state: state, controller: controller, onExit: onExit),
    );

    if (step == null) {
      // The summary is the stack's terminal card: nothing queued behind it.
      return CardStack(cards: [frontCard]);
    }

    final lookahead = state.flow.steps
        .skip(state.flow.index + 1)
        .take(2)
        .toList();
    final previewCards = [
      for (var i = 0; i < lookahead.length; i++)
        TrainingCard(
          key: ValueKey(
            '${state.flow.index + 1 + i}-${lookahead[i].runtimeType}',
          ),
          position: i + 1,
          themeSlug: _themeSlugOf(state.words[lookahead[i].wordId], themesById),
          child: _PreviewCardContent(
            word: state.words[lookahead[i].wordId],
            step: lookahead[i],
          ),
        ),
    ];

    // Swipe is only meaningful on read-only steps — nothing to answer, so a
    // swipe can never let the user skip the exercise itself
    // (`03-card-stack-spec.md` §2). `FinalCheckStep` only once its cloze is
    // already resolved: swiping mid-answer would bypass grading.
    final swipeEnabled = switch (step) {
      DiscoverStep() || ReadingsStep() || SeedingReadingStep() => true,
      FinalCheckStep() => state.cloze?.isResolved ?? false,
      _ => false,
    };
    void next() => unawaited(controller.continueStep());

    return CardStack(
      cards: [frontCard, ...previewCards],
      swipeEnabled: swipeEnabled,
      onSwipeAdvance: swipeEnabled ? next : null,
    );
  }
}

/// A lookahead card's content: `SessionController` only materialises the
/// interactive flow state (`cloze`/`formRecall`/`production`) for the
/// *current* step, so positions 1/2 cannot host the literal future step
/// widget without exercising controller internals meant for the current
/// step only. They render a themed, non-interactive peek instead — already
/// `IgnorePointer`-wrapped by `CardStack`, consistent with the spec's own
/// "peeking, not composited beyond position 2" performance rule (§5).
class _PreviewCardContent extends StatelessWidget {
  const new({required this.word, required this.step});

  final Word? word;
  final SessionStep step;

  /// The step's kind, reusing the same labels its own front-card view
  /// would show — never anything from the exercise itself (no options, no
  /// correct answer), just enough to read "what's coming" at a glance.
  static String? _kindLabel(SessionStep step, AppLocalizations l10n) =>
      switch (step) {
        DiscoverStep() => l10n.wordTodayBadge,
        ReadingsStep() || SeedingReadingStep() => l10n.readingsTitle,
        ReviewClozeStep() => l10n.sessionReviewLabel,
        FinalCheckStep() => l10n.sessionFinalCheckLabel,
        RequeueClozeStep() => l10n.sessionRequeueLabel,
        FormRecallStep() => l10n.formRecallTitle,
        ProductionStep() => l10n.productionTitle,
        PracticeClozeStep() => null,
      };

  @override
  Widget build(BuildContext context) {
    final kind = _kindLabel(step, context.l10n);
    return Padding(
      padding: const EdgeInsets.all(FluiSpacing.ml),
      child: Align(
        alignment: Alignment.topLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (kind != null) ...[
              FluiLabel(kind),
              const SizedBox(height: FluiSpacing.xxs),
            ],
            Text(
              word?.lemma ?? '',
              style: context.type.titleL,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepContent extends ConsumerWidget {
  const new({
    required this.state,
    required this.controller,
    required this.onExit,
  });

  final SessionState state;
  final SessionController controller;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final step = state.step;
    final word = state.word;
    final busy = state.saving;
    void next() => unawaited(controller.continueStep());

    if (step == null || word == null) {
      final data = ref.watch(currentLearningDataProvider).value;
      final tomorrow = state.today.addDays(1);
      final streak = StreakCalculator.summarize(
        activityDates: data?.activityDates ?? const {},
        repairedDates: data?.repairs.toSet() ?? const {},
        today: state.today,
      );
      return SessionSummaryView(
        newWordCount: state.summaryNewWordIds.length,
        words: [
          for (final id in {
            ...state.summaryNewWordIds,
            ...state.summaryReviewWordIds,
          })
            if (state.words[id] != null && state.progress[id] != null)
              (
                lemma: state.words[id]!.lemma,
                state: state.progress[id]!.state.chipKind,
                progress: state.progress[id],
              ),
        ],
        ownedLemmas: [
          for (final id in state.ownedWordIds) ?state.words[id]?.lemma,
        ],
        seeding: state.flow.seeding,
        weekDays: streak.weekDays,
        streak: streak.currentStreak,
        tomorrowReviews: (data?.progress ?? const [])
            .where((row) => row.nextDueOn == tomorrow)
            .length,
        accuracyPercent: state.accuracyPercent,
        onDone: onExit,
      );
    }

    final stepKey = ValueKey('${state.flow.index}-${step.runtimeType}');
    return switch (step) {
      DiscoverStep() => Column(
        key: stepKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WordDetailView(
            word: word,
            badge: _TodayBadge(label: l10n.wordTodayBadge),
          ),
          SizedBox(height: context.layout.blockGap),
          FluiButton.primary(
            label: l10n.wordSeeContext,
            isLoading: busy,
            onPressed: next,
          ),
        ],
      ),
      ReadingsStep() || SeedingReadingStep() => Column(
        key: stepKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (step is SeedingReadingStep) ...[
            FluiNotice(
              tone: FluiNoticeTone.info,
              glyph: const FluiGlyphIcon(FluiGlyph.onda),
              message: l10n.sessionSeeding,
            ),
            const SizedBox(height: FluiSpacing.lg),
          ],
          Semantics(
            header: true,
            child: Text(
              l10n.readingsTitle,
              style: context.type.titleL.copyWith(color: FluiColors.charcoal),
            ),
          ),
          const SizedBox(height: FluiSpacing.xxs),
          Text(
            word.lemma,
            style: context.type.bodyL.copyWith(
              fontWeight: FontWeight.w600,
              color: FluiColors.greenSecondary,
            ),
          ),
          const SizedBox(height: FluiSpacing.md),
          ReadingsCarousel(readings: _scenesOf(word, step), forms: word.forms),
          const SizedBox(height: FluiSpacing.lg),
          FluiButton.primary(
            label: l10n.commonContinue,
            isLoading: busy,
            onPressed: next,
          ),
        ],
      ),
      ReviewClozeStep() ||
      PracticeClozeStep() ||
      FinalCheckStep() ||
      RequeueClozeStep() => switch (state.cloze) {
        final cloze? => ClozeView(
          key: stepKey,
          flow: cloze,
          label: switch (step) {
            ReviewClozeStep() => l10n.sessionReviewLabel,
            FinalCheckStep() => l10n.sessionFinalCheckLabel,
            RequeueClozeStep() => l10n.sessionRequeueLabel,
            _ => null,
          },
          busy: busy,
          onConfirm: (id) => unawaited(controller.answerCloze(id)),
          onRetry: controller.retryCloze,
          onContinue: next,
        ),
        null => const SizedBox.shrink(),
      },
      FormRecallStep() => switch ((state.formRecall, state.formRecallPrompt)) {
        (final check?, final prompt?) => MicTargetScope(
          target: ref.watch(formRecallMicTargetProvider(state.mode)),
          child: FormRecallView(
            key: stepKey,
            check: check,
            explanation: prompt.explanation,
            sentenceBefore: prompt.before,
            sentenceAfter: prompt.after,
            syllableCount: word.syllables.length,
            busy: busy,
            onHint: () => unawaited(controller.takeFormRecallHint()),
            onContinue: next,
            micController: ref.watch(micControllerProvider),
            onSkip: () => unawaited(controller.skipSpokenStep()),
          ),
        ),
        _ => const SizedBox.shrink(),
      },
      ProductionStep() => switch (state.production) {
        final production? => MicTargetScope(
          target: ref.watch(productionMicTargetProvider(state.mode)),
          child: ProductionView(
            key: stepKey,
            flow: production,
            lemma: word.lemma,
            beforePhrase: _situation(word),
            busy: busy,
            onConfirm: () => unawaited(controller.confirmProduction()),
            onRevise: controller.reviseProduction,
            onToggle: controller.toggleProductionRubric,
            micController: ref.watch(micControllerProvider),
            onSkip: () => unawaited(controller.skipSpokenStep()),
          ),
        ),
        null => const SizedBox.shrink(),
      },
    };
  }

  /// Discovery splits Mira: one scene before Elige, the rest later on.
  static List<Reading> _scenesOf(Word word, SessionStep step) {
    if (step is! ReadingsStep) return word.readings;
    final rest = word.readings.skip(step.fromIndex);
    final maxCount = step.maxCount;
    return (maxCount == null ? rest : rest.take(maxCount)).toList();
  }

  static String _situation(Word word) =>
      word.replaces.firstOrNull?.before ??
      word.readings.firstOrNull?.beforePhrase ??
      word.explanation;
}

class _TodayBadge extends StatelessWidget {
  const new({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: FluiColors.yellowElectric,
        borderRadius: FluiRadii.pill,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: FluiSpacing.sm,
          vertical: FluiSpacing.xxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FluiGlyphIcon(
              FluiGlyph.wordOfTheDay,
              size: FluiIconSize.inline,
              color: FluiColors.charcoal,
            ),
            const SizedBox(width: 6),
            Flexible(child: FluiLabel(label, color: FluiColors.charcoal)),
          ],
        ),
      ),
    );
  }
}
