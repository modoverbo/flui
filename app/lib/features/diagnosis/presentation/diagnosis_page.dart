import 'dart:async';

import 'package:flui/app/router/app_router.dart';
import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/mic/mic_providers.dart';
import 'package:flui/core/mic/presentation/mic_dock.dart';
import 'package:flui/core/mic/presentation/mic_target_scope.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/daily/presentation/providers/daily_providers.dart';
import 'package:flui/features/diagnosis/presentation/providers/diagnosis_providers.dart';
import 'package:flui/features/training/domain/diagnosis_profiler.dart';
import 'package:flui/features/training/domain/retake_policy.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:flui/features/training/domain/training_loop.dart';
import 'package:flui/features/training/presentation/controllers/loop_mic_target.dart';
import 'package:flui/features/training/presentation/controllers/training_loop_controller.dart';
import 'package:flui/features/training/presentation/providers/training_providers.dart';
import 'package:flui/shared/widgets/empty_state.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_card.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:flui/shared/widgets/page_frame.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The mandatory diagnosis's live screen (design part-3 §11, §19.9, D30,
/// U14a): root-navigator, no shell chrome, so it renders its own
/// [MicDock] rather than relying on the shell's bottom-bar mic.
///
/// `LoopScript.diagnosis` is measure-only (D13): it never reaches
/// `feedback`/`comparison`, so this screen shows only the current
/// challenge's prompt and slot — never a score, never AI feedback text.
class DiagnosisPage extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final asyncChallenges = ref.watch(diagnosisChallengesProvider);
    return asyncChallenges.when(
      data: (challenges) => challenges.length < DiagnosisProfiler.totalSlots
          ? Scaffold(
              body: SafeArea(
                child: PageFrame.column(
                  child: EmptyState(
                    title: l10n.diagnosisUnavailableTitle,
                    message: l10n.diagnosisUnavailableBody,
                  ),
                ),
              ),
            )
          : _DiagnosisLoop(challengeIds: [for (final c in challenges) c.id]),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(
        body: SafeArea(
          child: PageFrame.column(
            child: EmptyState(
              title: l10n.diagnosisUnavailableTitle,
              message: l10n.diagnosisUnavailableBody,
            ),
          ),
        ),
      ),
    );
  }
}

class _DiagnosisLoop extends ConsumerStatefulWidget {
  const new({required this.challengeIds});

  final List<String> challengeIds;

  @override
  ConsumerState<_DiagnosisLoop> createState() => _DiagnosisLoopState();
}

class _DiagnosisLoopState extends ConsumerState<_DiagnosisLoop> {
  String? _saveError;
  bool _finishing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sessionId = ref.watch(diagnosisSessionIdProvider);
    final request = LoopRequest(
      context: TrainingContext.diagnosis,
      sessionId: sessionId,
      script: LoopScript.diagnosis(totalSlots: widget.challengeIds.length),
      challengeIds: widget.challengeIds,
    );
    final state = ref.watch(trainingLoopControllerProvider(request));
    final micController = ref.watch(micControllerProvider);
    // Keeps the autoDispose target alive for this widget's lifetime,
    // matching `TrainingLoopView`'s own established pattern (U23c).
    final target = ref.watch(loopMicTargetProvider(request));

    ref.listen(trainingLoopControllerProvider(request), (previous, next) {
      final wasSummary = previous?.loop.phase == LoopPhase.summary;
      if (next.loop.phase == LoopPhase.summary && !wasSummary) {
        unawaited(_finish(request));
      }
    });

    return MicTargetScope(
      target: target,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            child: PageFrame.column(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: FluiSpacing.lg),
                  if (state.loop.slot case final slot?)
                    FluiLabel(
                      l10n.diagnosisSlotLabel(slot, widget.challengeIds.length),
                    ),
                  const SizedBox(height: FluiSpacing.md),
                  _DiagnosisPhaseBody(
                    state: state,
                    request: request,
                    saveError: _saveError,
                    finishing: _finishing,
                    onRetrySave: () => unawaited(_finish(request)),
                    l10n: l10n,
                  ),
                  const SizedBox(height: FluiSpacing.xl),
                  if (micController != null) MicDock(controller: micController),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The loop reached `summary`: computes the profile from the just-saved
  /// attempts and persists it — never fabricated, and never advancing past
  /// an incomplete/failed save (design part-3 §5 D20, D38).
  Future<void> _finish(LoopRequest request) async {
    if (_finishing) return;
    setState(() {
      _finishing = true;
      _saveError = null;
    });

    final rowsResult = await ref
        .read(speakingAttemptRepositoryProvider)
        .latestDiagnosisAttempts();
    if (!mounted) return;
    final rows = rowsResult.valueOrNull ?? const [];
    final diagnosisAttempts = <DiagnosisAttempt>[
      for (final row in rows)
        if (row.challengeId case final challengeId?)
          if (request.challengeIds.indexOf(challengeId) case final index
              when index >= 0)
            DiagnosisAttempt(
              attemptId: row.id,
              slot: index + 1,
              observations: row.observations,
            ),
    ];

    final profiled = const DiagnosisProfiler().profile(diagnosisAttempts);
    if (profiled is! DiagnosisProfileComplete) {
      setState(() {
        _finishing = false;
        _saveError = context.l10n.diagnosisSaveFailedMessage;
      });
      return;
    }

    final saved = await ref
        .read(skillProfileRepositoryProvider)
        .save(sessionId: request.sessionId, profile: profiled.profile);
    if (!mounted) return;

    switch (saved) {
      case Ok(:final value):
        final userId = ref.read(currentUserIdProvider);
        if (userId != null) {
          ref.read(latestSkillProfileProvider(userId).notifier).publish(value);
        }
        ref.read(goRouterProvider).go(AppRoutes.diagnosisResult);
      case Err(:final failure)
          when failure is SkillProfileFailure &&
              failure.code == SkillProfileErrorCode.retakeTooSoon:
        final last = await ref.read(
          latestSkillProfileProvider(ref.read(currentUserIdProvider) ?? '')
              .future,
        );
        if (!mounted) return;
        final available = last == null
            ? null
            : const RetakePolicy().nextAvailableOn(
                LocalDate.fromDateTime(last.diagnosedAt),
              );
        setState(() {
          _finishing = false;
          _saveError = available == null
              ? context.l10n.diagnosisSaveFailedMessage
              : context.l10n.diagnosisRetakeTooSoonMessage(available.toIso());
        });
      case Err():
        setState(() {
          _finishing = false;
          _saveError = context.l10n.diagnosisSaveFailedMessage;
        });
    }
  }
}

class _DiagnosisPhaseBody extends ConsumerWidget {
  const new({
    required this.state,
    required this.request,
    required this.saveError,
    required this.finishing,
    required this.onRetrySave,
    required this.l10n,
  });

  final TrainingLoopControllerState state;
  final LoopRequest request;
  final String? saveError;
  final bool finishing;
  final VoidCallback onRetrySave;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loop = state.loop;
    final saveError = this.saveError;
    if (saveError != null) {
      return FluiCard(
        color: FluiColors.yellowTint,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(saveError),
            const SizedBox(height: FluiSpacing.sm),
            FluiButton.outline(
              label: l10n.diagnosisRetryAction,
              onPressed: onRetrySave,
            ),
          ],
        ),
      );
    }
    return switch (loop.phase) {
      LoopPhase.focus || LoopPhase.recording || LoopPhase.analyzing =>
        _DiagnosisFocusCard(challengeId: request.challengeIdFor(loop.slot)),
      LoopPhase.summary =>
        finishing
            ? const Center(child: CircularProgressIndicator())
            : const SizedBox.shrink(),
      LoopPhase.accessRequired => FluiCard(
        color: FluiColors.yellowTint,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.loopAccessRequiredMessage),
            const SizedBox(height: FluiSpacing.sm),
            FluiButton.outline(
              label: l10n.loopReactivateAction,
              onPressed: () => context.go('/paywall'),
            ),
          ],
        ),
      ),
      LoopPhase.analysisFailed => FluiCard(
        color: FluiColors.yellowTint,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              loop.failureCode == SpeechAnalysisErrorCode.dailyLimitReached.name
                  ? l10n.loopDailyLimitMessage
                  : l10n.loopAnalysisFailedMessage,
            ),
            if (loop.failureCode !=
                SpeechAnalysisErrorCode.dailyLimitReached.name) ...[
              const SizedBox(height: FluiSpacing.sm),
              FluiButton.outline(
                label: l10n.loopRetryAction,
                onPressed: () => unawaited(
                  ref
                      .read(trainingLoopControllerProvider(request).notifier)
                      .resubmit(),
                ),
              ),
            ],
          ],
        ),
      ),
      LoopPhase.feedback ||
      LoopPhase.comparison ||
      LoopPhase.permissionDenied => const SizedBox.shrink(),
    };
  }
}

class _DiagnosisFocusCard extends ConsumerWidget {
  const new({required this.challengeId});

  final String? challengeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = challengeId;
    if (id == null) return const SizedBox.shrink();
    final asyncCatalog = ref.watch(diagnosisChallengesProvider);
    final challenge = asyncCatalog.value?.where((c) => c.id == id).firstOrNull;
    if (challenge == null) return const SizedBox.shrink();
    return FluiCard(
      color: FluiColors.aqua,
      child: Text(
        challenge.prompt,
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w800, color: FluiColors.ink),
      ),
    );
  }
}
