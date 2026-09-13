import 'dart:async';

import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/l10n/failure_messages.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:flui/features/daily/domain/session_step.dart';
import 'package:flui/features/daily/presentation/controllers/session_controller.dart';
import 'package:flui/features/daily/presentation/providers/learning_data_controller.dart';
import 'package:flui/features/daily/presentation/widgets/session_summary_view.dart';
import 'package:flui/features/exercises/presentation/widgets/cloze_view.dart';
import 'package:flui/features/exercises/presentation/widgets/form_recall_view.dart';
import 'package:flui/features/exercises/presentation/widgets/production_view.dart';
import 'package:flui/features/profile/domain/streak_calculator.dart';
import 'package:flui/features/reading/domain/reading.dart';
import 'package:flui/features/reading/presentation/widgets/readings_carousel.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/features/vocabulary/presentation/widgets/word_detail_view.dart';
import 'package:flui/features/vocabulary/presentation/word_state_kind.dart';
import 'package:flui/shared/widgets/content_column.dart';
import 'package:flui/shared/widgets/empty_state.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_notice.dart';
import 'package:flui/shared/widgets/flui_progress_bar.dart';
import 'package:flui/shared/widgets/loading_wave.dart';
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
    return Scaffold(
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
          ContentColumn(
            maxWidth: FluiSpacing.appContentMaxWidth,
            padding: const EdgeInsets.fromLTRB(
              FluiSpacing.xs,
              FluiSpacing.xs,
              FluiSpacing.lg,
              0,
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: l10n.sessionCloseTooltip,
                  onPressed: () => unawaited(_confirmClose(context)),
                  icon: const Icon(LucideIcons.x),
                ),
                const SizedBox(width: FluiSpacing.xs),
                Text(
                  l10n.sessionProgress(flow.position, flow.total),
                  style: FluiTypography.label.copyWith(color: FluiColors.gray),
                ),
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
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: FluiSpacing.lg),
            child: ContentColumn(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (failure != null) ...[
                    FluiNotice(message: failureMessage(l10n, failure)),
                    const SizedBox(height: FluiSpacing.sm),
                    FluiButton.outline(
                      label: l10n.commonRetry,
                      isLoading: state.saving,
                      onPressed: () => unawaited(controller.retrySave()),
                    ),
                    const SizedBox(height: FluiSpacing.lg),
                  ],
                  _StepContent(
                    state: state,
                    controller: controller,
                    onExit: onExit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
          const SizedBox(height: FluiSpacing.xl),
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
              icon: LucideIcons.sprout,
              message: l10n.sessionSeeding,
            ),
            const SizedBox(height: FluiSpacing.lg),
          ],
          Semantics(
            header: true,
            child: Text(
              l10n.readingsTitle,
              style: FluiTypography.h2.copyWith(color: FluiColors.charcoal),
            ),
          ),
          const SizedBox(height: FluiSpacing.xxs),
          Text(
            word.lemma,
            style: FluiTypography.bodyEmphasis.copyWith(
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
        (final check?, final prompt?) => FormRecallView(
          key: stepKey,
          check: check,
          explanation: prompt.explanation,
          sentenceBefore: prompt.before,
          sentenceAfter: prompt.after,
          syllableCount: word.syllables.length,
          busy: busy,
          onSubmit: (text) => unawaited(controller.submitFormRecall(text)),
          onHint: () => unawaited(controller.takeFormRecallHint()),
          onContinue: next,
        ),
        _ => const SizedBox.shrink(),
      },
      ProductionStep() => switch (state.production) {
        final production? => ProductionView(
          key: stepKey,
          flow: production,
          lemma: word.lemma,
          beforePhrase: _situation(word),
          busy: busy,
          onSubmit: controller.submitProduction,
          onConfirm: () => unawaited(controller.confirmProduction()),
          onRevise: controller.reviseProduction,
          onToggle: controller.toggleProductionRubric,
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
            const Icon(
              LucideIcons.sparkles,
              size: 14,
              color: FluiColors.charcoal,
            ),
            const SizedBox(width: FluiSpacing.xxs),
            Flexible(
              child: Text(
                label,
                style: FluiTypography.label.copyWith(
                  color: FluiColors.charcoal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
