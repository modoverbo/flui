import 'dart:async';

import 'package:flui/core/l10n/gen/app_localizations.dart';
import 'package:flui/core/mic/mic_controller.dart';
import 'package:flui/core/mic/mic_providers.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/training/domain/attempt_comparison.dart';
import 'package:flui/features/training/domain/attempt_kind.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/challenge.dart';
import 'package:flui/features/training/domain/feedback.dart';
import 'package:flui/features/training/domain/training_loop.dart';
import 'package:flui/features/training/presentation/controllers/loop_mic_target.dart';
import 'package:flui/features/training/presentation/controllers/training_loop_controller.dart';
import 'package:flui/features/training/presentation/providers/training_providers.dart';
import 'package:flui/shared/widgets/audio_reactive_bubble.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_card.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:flui/shared/widgets/speaking_bubble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide Feedback;

/// Resolves the [Challenge] a speak step answers, for display only.
///
/// **Deviation (documented, see apply-progress)**: [TrainingLoopController]
/// caches the resolved `Challenge` internally (it needs it for
/// `Skill`->`SkillArea` mapping) but never exposes it through
/// [TrainingLoopControllerState] — there was no "current challenge" field
/// to read. This view resolves it independently through the same
/// `ChallengeRepository` port rather than widening the controller's public
/// state for a display-only concern.
// ignore: specify_nonobvious_property_types
final _challengeByIdProvider = FutureProvider.autoDispose
    .family<Challenge?, String?>((ref, id) async {
      if (id == null) return null;
      final result = await ref.read(challengeRepositoryProvider).fetchCatalog();
      final catalog = result.valueOrNull ?? const <Challenge>[];
      for (final challenge in catalog) {
        if (challenge.id == id) return challenge;
      }
      return null;
    });

/// The reusable training-loop screen body (design §10, §19.8, §13 — U13b).
///
/// Owns NO record affordance of its own: capture happens exclusively
/// through the shell's single mic (decision #448). This widget only shows
/// a passive status panel reflecting [MicController] and a phase-specific
/// card, and registers a [LoopMicTarget] so the mic knows what to deliver
/// recorded audio to.
///
/// **Deviation from design/detail-2 (documented, see apply-progress)**:
/// detail-2's own acceptance line says "`MicTargetScope` wraps the loop
/// view, registering `LoopMicTarget` in `initState`/`didUpdateWidget`/
/// `dispose`" — but `MicTargetScope` (and `MicLayerScope`, which would
/// supply the active branch index) are U23c deliverables, and U13b lands
/// BEFORE U23c in the units' own dependency sequence
/// (`U23a→U23b→U13a→U13b→U16→U23c→...`). This widget therefore performs
/// that exact registration lifecycle itself, directly against
/// [micTargetRegistryProvider], with [MicLayer.branch] at the registry's
/// default active branch (0) — the same effect `MicTargetScope` will have
/// once it exists. U23c/U16 are expected to either supply the real branch
/// index once shell wiring exists, or replace this with the shared
/// `MicTargetScope` widget outright.
class TrainingLoopView extends ConsumerStatefulWidget {
  const new({required this.request, super.key});

  final LoopRequest request;

  @override
  ConsumerState<TrainingLoopView> createState() => _TrainingLoopViewState();
}

class _TrainingLoopViewState extends ConsumerState<TrainingLoopView> {
  MicRegistration? _registration;

  @override
  void initState() {
    super.initState();
    _register();
  }

  @override
  void didUpdateWidget(covariant TrainingLoopView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request != widget.request) {
      _registration?.dispose();
      _register();
    }
  }

  void _register() {
    final target = ref.read(loopMicTargetProvider(widget.request));
    _registration = ref
        .read(micTargetRegistryProvider)
        .register(target, layer: MicLayer.branch);
  }

  @override
  void dispose() {
    _registration?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trainingLoopControllerProvider(widget.request));
    final micController = ref.watch(micControllerProvider);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatusPanel(controller: micController),
              const SizedBox(height: FluiSpacing.lg),
              _PhaseBody(
                state: state,
                request: widget.request,
                controller: ref.read(
                  trainingLoopControllerProvider(widget.request).notifier,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The passive status panel: a bubble reflecting [MicController.states]
/// (never a widget-owned record button), plus the currently latched
/// block's message/CTA when the mic itself is not ready (design §19.8).
class _StatusPanel extends StatelessWidget {
  const new({required this.controller});

  final MicController? controller;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return StreamBuilder<MicState>(
      stream: controller.states,
      initialData: controller.state,
      builder: (context, snapshot) {
        final micState = snapshot.data ?? controller.state;
        return switch (micState) {
          MicIdle(:final block) when block != null => _BlockedPanel(
            block: block,
            controller: controller,
          ),
          MicIdle() => const Center(
            child: AudioReactiveBubble(state: BubbleState.ready, size: 96),
          ),
          MicRequestingPermission() => _BusyPanel(
            message: l10n.loopStatusPreparingMic,
          ),
          MicRecording(:final secondsLeft) => _RecordingPanel(
            secondsLeft: secondsLeft,
            levels: controller.levels,
          ),
          MicFinishing() => _BusyPanel(message: l10n.loopStatusFinishing),
          MicDelivering() => _BusyPanel(message: l10n.loopStatusAnalyzing),
        };
      },
    );
  }
}

class _BusyPanel extends StatelessWidget {
  const new({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const AudioReactiveBubble(state: BubbleState.processing, size: 120),
      const SizedBox(height: FluiSpacing.sm),
      Semantics(
        liveRegion: true,
        label: message,
        child: Text(message, textAlign: TextAlign.center),
      ),
    ],
  );
}

class _RecordingPanel extends StatelessWidget {
  const new({required this.secondsLeft, required this.levels});

  final int secondsLeft;
  final Stream<double> levels;

  @override
  Widget build(BuildContext context) => Center(
    child: AudioReactiveBubble(
      state: BubbleState.recording,
      amplitudeStream: levels,
      recordingSeconds: secondsLeft,
      size: 140,
    ),
  );
}

/// The message/CTA for a controller-level latch (access/quota/permission) —
/// the exact same [MicBlocked] shape U23d's blocked sheets will render.
/// A generic renderer, not a permission-specific one: the "actionable
/// settings message" scenario reaches this same code path as every other
/// latch (design §19.5).
class _BlockedPanel extends StatelessWidget {
  const new({required this.block, required this.controller});

  final MicBlocked block;
  final MicController controller;

  @override
  Widget build(BuildContext context) {
    final cta = block.cta;
    return Semantics(
      liveRegion: true,
      label: block.message,
      child: FluiCard(
        color: FluiColors.yellowTint,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              block.message,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (cta != null) ...[
              const SizedBox(height: FluiSpacing.sm),
              FluiButton.outline(
                label: cta.label,
                onPressed: () {
                  final route = cta.route;
                  if (route != null) {
                    context.go(route);
                  } else {
                    controller.retryPermission();
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The closed-catalog Spanish rendering of an observed behavior — never a
/// number, never the raw wire code (spec `training-engine`: feedback is
/// expressed as observable behaviors).
String _behaviorLine(AppLocalizations l10n, BehaviorCode code) =>
    switch (code) {
      BehaviorCode.mainPointLate => l10n.behaviorMainPointLate,
      BehaviorCode.noClearStructure => l10n.behaviorNoClearStructure,
      BehaviorCode.missingExample => l10n.behaviorMissingExample,
      BehaviorCode.noClosing => l10n.behaviorNoClosing,
      BehaviorCode.clearMainPoint => l10n.behaviorClearMainPoint,
      BehaviorCode.orderedIdeas => l10n.behaviorOrderedIdeas,
      BehaviorCode.vagueWord => l10n.behaviorVagueWord,
      BehaviorCode.repeatedWord => l10n.behaviorRepeatedWord,
      BehaviorCode.weakConnector => l10n.behaviorWeakConnector,
      BehaviorCode.registerMismatch => l10n.behaviorRegisterMismatch,
      BehaviorCode.preciseWord => l10n.behaviorPreciseWord,
      BehaviorCode.variedVocabulary => l10n.behaviorVariedVocabulary,
      BehaviorCode.paceFast => l10n.behaviorPaceFast,
      BehaviorCode.paceSlow => l10n.behaviorPaceSlow,
      BehaviorCode.longPauses => l10n.behaviorLongPauses,
      BehaviorCode.fillerHeavy => l10n.behaviorFillerHeavy,
      BehaviorCode.volumeUnstable => l10n.behaviorVolumeUnstable,
      BehaviorCode.steadyPace => l10n.behaviorSteadyPace,
      BehaviorCode.controlledFillers => l10n.behaviorControlledFillers,
      BehaviorCode.steadyVolume => l10n.behaviorSteadyVolume,
      BehaviorCode.usefulPauses => l10n.behaviorUsefulPauses,
    };

/// The current phase's card, plus the ordinary (non-speech) taps design
/// §19.8 keeps: Continuar, Salir. Reintentar/Reintentar-guardar/Reactivar
/// live inside their own phase card since they only apply there.
class _PhaseBody extends StatelessWidget {
  const new({
    required this.state,
    required this.request,
    required this.controller,
  });

  final TrainingLoopControllerState state;
  final LoopRequest request;
  final TrainingLoopController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loop = state.loop;
    final content = switch (loop.phase) {
      LoopPhase.focus || LoopPhase.permissionDenied => _FocusCard(
        step: loop.attemptStep,
        challengeId: request.challengeIdFor(loop.slot),
        l10n: l10n,
      ),
      LoopPhase.recording || LoopPhase.analyzing => const SizedBox.shrink(),
      LoopPhase.feedback => _FeedbackCard(feedback: state.feedback, l10n: l10n),
      LoopPhase.comparison => _ComparisonCard(
        comparison: state.comparison,
        l10n: l10n,
      ),
      LoopPhase.summary => _SummaryCard(l10n: l10n),
      LoopPhase.accessRequired => _AccessRequiredCard(
        feedback: state.feedback,
        comparison: state.comparison,
        l10n: l10n,
      ),
      LoopPhase.analysisFailed => _AnalysisFailedCard(
        failureCode: loop.failureCode,
        onRetry: controller.resubmit,
        onRetrySave: controller.retrySave,
        l10n: l10n,
      ),
    };
    final showContinue =
        loop.phase == LoopPhase.feedback || loop.phase == LoopPhase.comparison;
    final showExit = loop.phase != LoopPhase.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        content,
        if (showContinue || showExit) ...[
          const SizedBox(height: FluiSpacing.lg),
          Row(
            children: [
              if (showExit)
                Expanded(
                  child: FluiButton.text(
                    label: l10n.loopExitAction,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              if (showContinue) ...[
                if (showExit) const SizedBox(width: FluiSpacing.sm),
                Expanded(
                  child: FluiButton.outline(
                    label: l10n.loopContinueAction,
                    onPressed: controller.continueToNextStep,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _FocusCard extends ConsumerWidget {
  const new({
    required this.step,
    required this.challengeId,
    required this.l10n,
  });

  final AttemptKind? step;
  final String? challengeId;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncChallenge = ref.watch(_challengeByIdProvider(challengeId));
    return asyncChallenge.when(
      data: (challenge) =>
          _FocusBody(step: step, challenge: challenge, l10n: l10n),
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(FluiSpacing.lg),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, _) => _FocusBody(step: step, challenge: null, l10n: l10n),
    );
  }
}

class _FocusBody extends StatelessWidget {
  const new({required this.step, required this.challenge, required this.l10n});

  final AttemptKind? step;
  final Challenge? challenge;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final challenge = this.challenge;
    final prompt = challenge == null
        ? null
        : (step == AttemptKind.transfer && challenge.transferPrompts.isNotEmpty
              ? challenge.transferPrompts.first
              : challenge.prompt);
    final hint = switch (step) {
      AttemptKind.first => l10n.loopHintFirst,
      AttemptKind.repeat => l10n.loopHintRepeat,
      AttemptKind.transfer => l10n.loopHintTransfer,
      null => l10n.loopHintNextStep,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (prompt != null)
          FluiCard(
            color: FluiColors.aqua,
            child: Text(
              prompt,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: FluiColors.ink,
              ),
            ),
          ),
        if (challenge?.focus case final focus?) ...[
          const SizedBox(height: FluiSpacing.md),
          Text(focus),
        ],
        const SizedBox(height: FluiSpacing.xl),
        Semantics(
          liveRegion: true,
          label: hint,
          child: Text(hint, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const new({required this.feedback, required this.l10n});

  final Feedback? feedback;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _FeedbackBody(feedback: feedback, l10n: l10n),
      const SizedBox(height: FluiSpacing.lg),
      Text(l10n.loopHintRepeat, textAlign: TextAlign.center),
    ],
  );
}

class _FeedbackBody extends StatelessWidget {
  const new({required this.feedback, required this.l10n});

  final Feedback? feedback;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final feedback = this.feedback;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FluiLabel(l10n.loopFeedbackLabel),
        const SizedBox(height: FluiSpacing.sm),
        Text(
          l10n.loopFeedbackHeadline,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800, color: FluiColors.ink),
        ),
        const SizedBox(height: FluiSpacing.lg),
        if (feedback?.primary case final primary?) ...[
          FluiLabel(l10n.loopOpportunityLabel),
          const SizedBox(height: FluiSpacing.xs),
          FluiCard(child: Text(_behaviorLine(l10n, primary.code))),
          const SizedBox(height: FluiSpacing.sm),
        ],
        if (feedback?.strength case final strength?) ...[
          FluiLabel(l10n.loopStrengthLabel),
          const SizedBox(height: FluiSpacing.xs),
          FluiCard(child: Text(_behaviorLine(l10n, strength.code))),
          const SizedBox(height: FluiSpacing.sm),
        ],
        if (feedback != null) ...[
          const SizedBox(height: FluiSpacing.sm),
          FluiCard(
            color: FluiColors.yellowTint,
            child: Text('${l10n.loopRetryCueLabel}: ${feedback.retryCue}'),
          ),
        ],
      ],
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const new({required this.comparison, required this.l10n});

  final AttemptComparison? comparison;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _ComparisonBody(comparison: comparison, l10n: l10n),
      const SizedBox(height: FluiSpacing.lg),
      Text(l10n.loopHintTransfer, textAlign: TextAlign.center),
    ],
  );
}

class _ComparisonBody extends StatelessWidget {
  const new({required this.comparison, required this.l10n});

  final AttemptComparison? comparison;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final comparison = this.comparison;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FluiLabel(l10n.loopComparisonLabel),
        const SizedBox(height: FluiSpacing.sm),
        Text(
          l10n.loopComparisonHeadline,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800, color: FluiColors.ink),
        ),
        const SizedBox(height: FluiSpacing.lg),
        if (comparison == null)
          const SizedBox.shrink()
        else if (comparison.isMateriallySame)
          Text(l10n.loopComparisonSame)
        else ...[
          FluiLabel(l10n.loopComparisonWhatChangedLabel),
          const SizedBox(height: FluiSpacing.xs),
          for (final change in comparison.observationChanges)
            if (change.kind != ObservationChangeKind.persisted)
              _ChangeLine(change: change, l10n: l10n),
          for (final metric in comparison.metricChanges)
            _MetricLine(metric: metric, l10n: l10n),
        ],
      ],
    );
  }
}

class _ChangeLine extends StatelessWidget {
  const new({required this.change, required this.l10n});

  final ObservationChange change;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final behavior = _behaviorLine(l10n, change.code);
    final text = change.kind == ObservationChangeKind.resolved
        ? l10n.loopChangeResolved(behavior)
        : l10n.loopChangeAppeared(behavior);
    return Padding(
      padding: const EdgeInsets.only(bottom: FluiSpacing.xs),
      child: FluiCard(child: Text(text)),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const new({required this.metric, required this.l10n});

  final MetricChange metric;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final label = switch (metric.kind) {
      MetricKind.pace => l10n.loopMetricLabelPace,
      MetricKind.fillers => l10n.loopMetricLabelFillers,
      MetricKind.pauses => l10n.loopMetricLabelPauses,
      MetricKind.volume => l10n.loopMetricLabelVolume,
    };
    final direction = metric.direction == MetricDirection.improved
        ? l10n.loopMetricImproved
        : l10n.loopMetricWorsened;
    return Padding(
      padding: const EdgeInsets.only(bottom: FluiSpacing.xs),
      child: FluiCard(child: Text('$label: $direction')),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const new({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FluiLabel(l10n.loopSummaryTitle),
      const SizedBox(height: FluiSpacing.sm),
      Text(l10n.loopSummaryBody),
      const SizedBox(height: FluiSpacing.lg),
      FluiButton.primary(
        label: l10n.loopSummaryExit,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    ],
  );
}

/// [LoopPhase.accessRequired]: the prior step's own content stays visible
/// (spec `ai-cost-gating`: "already-completed steps stay visible/
/// persisted") with a "Reactivar" CTA underneath — never a bare blocked
/// screen that hides what was already answered.
class _AccessRequiredCard extends StatelessWidget {
  const new({
    required this.feedback,
    required this.comparison,
    required this.l10n,
  });

  final Feedback? feedback;
  final AttemptComparison? comparison;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (comparison != null)
        _ComparisonBody(comparison: comparison, l10n: l10n)
      else if (feedback != null)
        _FeedbackBody(feedback: feedback, l10n: l10n),
      const SizedBox(height: FluiSpacing.lg),
      FluiCard(
        color: FluiColors.yellowTint,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.loopAccessRequiredMessage),
            const SizedBox(height: FluiSpacing.sm),
            FluiButton.primary(
              label: l10n.loopReactivateAction,
              onPressed: () => context.go('/paywall'),
            ),
          ],
        ),
      ),
    ],
  );
}

/// [LoopPhase.analysisFailed]: `dailyLimitReached` has no retry (design
/// §4); [notSavedFailureCode] offers "Reintentar guardar" (`retrySave`,
/// U13a.7) and never presents feedback as saved; every other code offers
/// an ordinary "Reintentar" (`resubmit`, keeps the same audio bytes).
class _AnalysisFailedCard extends StatelessWidget {
  const new({
    required this.failureCode,
    required this.onRetry,
    required this.onRetrySave,
    required this.l10n,
  });

  final String? failureCode;
  final Future<MicDelivery> Function() onRetry;
  final Future<MicDelivery> Function() onRetrySave;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (failureCode == 'dailyLimitReached') {
      return FluiCard(
        color: FluiColors.yellowTint,
        child: Text(l10n.loopDailyLimitMessage),
      );
    }
    if (failureCode == notSavedFailureCode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FluiCard(
            color: FluiColors.softPink,
            child: Text(l10n.loopNotSavedMessage),
          ),
          const SizedBox(height: FluiSpacing.sm),
          FluiButton.primary(
            label: l10n.loopRetrySaveAction,
            onPressed: () => unawaited(onRetrySave()),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FluiCard(
          color: FluiColors.softPink,
          child: Text(l10n.loopAnalysisFailedMessage),
        ),
        const SizedBox(height: FluiSpacing.sm),
        FluiButton.primary(
          label: l10n.loopRetryAction,
          onPressed: () => unawaited(onRetry()),
        ),
      ],
    );
  }
}
