import 'dart:async';

import 'package:flui/app/router/app_router.dart';
import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/mic/mic_controller.dart';
import 'package:flui/core/mic/mic_providers.dart';
import 'package:flui/core/mic/presentation/mic_dock.dart';
import 'package:flui/core/mic/presentation/mic_target_scope.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/daily/presentation/providers/daily_providers.dart';
import 'package:flui/features/diagnosis/domain/diagnosis_resume_policy.dart';
import 'package:flui/features/diagnosis/presentation/providers/diagnosis_providers.dart';
import 'package:flui/features/training/domain/diagnosis_profiler.dart';
import 'package:flui/features/training/domain/retake_policy.dart';
import 'package:flui/features/training/domain/speaking_attempt.dart';
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
    final asyncResume = ref.watch(diagnosisResumeProvider);

    if (asyncChallenges.hasError || asyncResume.hasError) {
      return Scaffold(
        body: SafeArea(
          child: PageFrame.column(
            child: EmptyState(
              title: l10n.diagnosisUnavailableTitle,
              message: l10n.diagnosisUnavailableBody,
            ),
          ),
        ),
      );
    }
    final challenges = asyncChallenges.value;
    final resume = asyncResume.value;
    if (challenges == null || resume == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (challenges.length < DiagnosisProfiler.totalSlots) {
      return Scaffold(
        body: SafeArea(
          child: PageFrame.column(
            child: EmptyState(
              title: l10n.diagnosisUnavailableTitle,
              message: l10n.diagnosisUnavailableBody,
            ),
          ),
        ),
      );
    }

    final challengeIds = [for (final c in challenges) c.id];
    final sessionId = switch (resume) {
      DiagnosisResume(:final sessionId) => sessionId,
      DiagnosisFresh() => ref.watch(diagnosisSessionIdProvider),
    };

    // D38: all 3 slots are already answered but no profile closed the
    // session yet (an earlier save must have failed) — profile directly,
    // no recording needed.
    if (resume case DiagnosisResume(nextSlot: null)) {
      return _DiagnosisResumeProfiling(
        sessionId: sessionId,
        challengeIds: challengeIds,
      );
    }

    final startSlot = switch (resume) {
      DiagnosisResume(:final nextSlot?) => nextSlot,
      DiagnosisResume() || DiagnosisFresh() => 1,
    };

    return _DiagnosisLoop(
      challengeIds: challengeIds,
      sessionId: sessionId,
      startSlot: startSlot,
    );
  }
}

/// The 4 loop phases "Continuar después" stays enabled for (design D39):
/// nothing is being captured or delivered in any of them, so pausing never
/// loses a take. Diagnosis (`LoopScript.diagnosis`, C1) never reaches
/// [LoopPhase.feedback]/[LoopPhase.comparison] itself, but the check stays
/// complete rather than assuming that.
bool _loopAllowsPause(LoopPhase phase) =>
    phase == LoopPhase.focus ||
    phase == LoopPhase.feedback ||
    phase == LoopPhase.analysisFailed ||
    phase == LoopPhase.permissionDenied;

class _DiagnosisLoop extends ConsumerStatefulWidget {
  const new({
    required this.challengeIds,
    required this.sessionId,
    required this.startSlot,
  });

  final List<String> challengeIds;
  final String sessionId;
  final int startSlot;

  @override
  ConsumerState<_DiagnosisLoop> createState() => _DiagnosisLoopState();
}

class _DiagnosisLoopState extends ConsumerState<_DiagnosisLoop> {
  String? _saveError;
  bool _finishing = false;
  MicState? _micState;
  StreamSubscription<MicState>? _micSubscription;

  @override
  void initState() {
    super.initState();
    final controller = ref.read(micControllerProvider);
    _micState = controller?.state;
    _micSubscription = controller?.states.listen((next) {
      if (mounted) setState(() => _micState = next);
    });
  }

  @override
  void dispose() {
    unawaited(_micSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final request = LoopRequest(
      context: TrainingContext.diagnosis,
      sessionId: widget.sessionId,
      script: LoopScript.diagnosis(
        totalSlots: widget.challengeIds.length,
        startSlot: widget.startSlot,
      ),
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

    // "Continuar después" (D39): a take mid-capture/delivery must never be
    // lost, so this is disabled whenever the mic itself is not idle, on
    // top of the loop's own pausable-phase check above.
    final micIdle = _micState == null || _micState is MicIdle;
    final canPause = micIdle && _loopAllowsPause(state.loop.phase);

    return MicTargetScope(
      target: target,
      child: PopScope(
        // System back behaves identically to the "Continuar después" tap
        // (D39): blocked while a take is mid-capture/delivery, otherwise
        // pauses to the intro.
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop || !canPause) return;
          _pause();
        },
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
                        l10n.diagnosisSlotLabel(
                          slot,
                          widget.challengeIds.length,
                        ),
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
                    const SizedBox(height: FluiSpacing.md),
                    FluiButton.text(
                      label: l10n.diagnosisPauseAction,
                      onPressed: canPause ? _pause : null,
                    ),
                    if (!canPause) ...[
                      const SizedBox(height: FluiSpacing.xs),
                      Text(
                        l10n.diagnosisPauseDisabledHint,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: FluiSpacing.xl),
                    if (micController != null)
                      MicDock(controller: micController),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Navigates to the intro (design D39) — nothing further to save, D20
  /// already persisted each answered slot as it completed. Invalidates
  /// [diagnosisResumeProvider] first: it is `autoDispose` and this
  /// same-frame navigation can otherwise resurrect its stale cached
  /// decision (computed before this session's latest attempt was
  /// persisted) instead of recomputing for the intro's next read.
  void _pause() {
    ref.invalidate(diagnosisResumeProvider);
    ref.read(goRouterProvider).go(AppRoutes.diagnosis);
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

    final outcome = await _computeAndSaveDiagnosisProfile(
      ref,
      sessionId: request.sessionId,
      challengeIds: request.challengeIds,
    );
    if (!mounted) return;
    _handleOutcome(outcome);
  }

  void _handleOutcome(_ProfileOutcome outcome) {
    switch (outcome) {
      case _ProfileSaved():
        ref.read(goRouterProvider).go(AppRoutes.diagnosisResult);
      case _ProfileIncomplete():
        setState(() {
          _finishing = false;
          _saveError = context.l10n.diagnosisSaveFailedMessage;
        });
      case _ProfileRetakeTooSoon(:final availableOn):
        setState(() {
          _finishing = false;
          _saveError = availableOn == null
              ? context.l10n.diagnosisSaveFailedMessage
              : context.l10n.diagnosisRetakeTooSoonMessage(availableOn.toIso());
        });
      case _ProfileSaveFailed():
        setState(() {
          _finishing = false;
          _saveError = context.l10n.diagnosisSaveFailedMessage;
        });
    }
  }
}

/// Resuming a session whose 3 slots are already answered but whose profile
/// save never completed (D38): computes and saves the profile directly,
/// without mounting the loop or recording anything.
class _DiagnosisResumeProfiling extends ConsumerStatefulWidget {
  const new({required this.sessionId, required this.challengeIds});

  final String sessionId;
  final List<String> challengeIds;

  @override
  ConsumerState<_DiagnosisResumeProfiling> createState() =>
      _DiagnosisResumeProfilingState();
}

class _DiagnosisResumeProfilingState
    extends ConsumerState<_DiagnosisResumeProfiling> {
  String? _saveError;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    setState(() => _saveError = null);
    final outcome = await _computeAndSaveDiagnosisProfile(
      ref,
      sessionId: widget.sessionId,
      challengeIds: widget.challengeIds,
    );
    if (!mounted) return;
    switch (outcome) {
      case _ProfileSaved():
        ref.read(goRouterProvider).go(AppRoutes.diagnosisResult);
      case _ProfileIncomplete():
        setState(() => _saveError = context.l10n.diagnosisSaveFailedMessage);
      case _ProfileRetakeTooSoon(:final availableOn):
        setState(
          () => _saveError = availableOn == null
              ? context.l10n.diagnosisSaveFailedMessage
              : context.l10n.diagnosisRetakeTooSoonMessage(availableOn.toIso()),
        );
      case _ProfileSaveFailed():
        setState(() => _saveError = context.l10n.diagnosisSaveFailedMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final saveError = _saveError;
    return Scaffold(
      body: SafeArea(
        child: PageFrame.column(
          child: saveError == null
              ? const Center(child: CircularProgressIndicator())
              : FluiCard(
                  color: FluiColors.yellowTint,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(saveError),
                      const SizedBox(height: FluiSpacing.sm),
                      FluiButton.outline(
                        label: l10n.diagnosisRetryAction,
                        onPressed: () => unawaited(_run()),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// What [_computeAndSaveDiagnosisProfile] found — shared by the loop's own
/// summary step and by resuming an already-fully-answered session (design
/// D38), so the exact same save/failure handling never has 2 copies.
sealed class _ProfileOutcome {
  const new();
}

final class _ProfileSaved extends _ProfileOutcome {
  const new();
}

final class _ProfileIncomplete extends _ProfileOutcome {
  const new();
}

final class _ProfileRetakeTooSoon extends _ProfileOutcome {
  const new(this.availableOn);

  final LocalDate? availableOn;
}

final class _ProfileSaveFailed extends _ProfileOutcome {
  const new();
}

/// Computes the profile from [sessionId]'s persisted attempts and saves it
/// (design part-3 §5 D20, D38) — never fabricated, never advancing past an
/// incomplete/failed save.
Future<_ProfileOutcome> _computeAndSaveDiagnosisProfile(
  WidgetRef ref, {
  required String sessionId,
  required List<String> challengeIds,
}) async {
  final rowsResult = await ref
      .read(speakingAttemptRepositoryProvider)
      .latestDiagnosisAttempts();
  final rows = rowsResult.valueOrNull ?? const <SpeakingAttempt>[];
  final diagnosisAttempts = <DiagnosisAttempt>[
    for (final row in rows)
      if (row.challengeId case final challengeId?)
        if (challengeIds.indexOf(challengeId) case final index when index >= 0)
          DiagnosisAttempt(
            attemptId: row.id,
            slot: index + 1,
            observations: row.observations,
          ),
  ];

  final profiled = const DiagnosisProfiler().profile(diagnosisAttempts);
  if (profiled is! DiagnosisProfileComplete) return const _ProfileIncomplete();

  final saved = await ref
      .read(skillProfileRepositoryProvider)
      .save(sessionId: sessionId, profile: profiled.profile);

  switch (saved) {
    case Ok(:final value):
      final userId = ref.read(currentUserIdProvider);
      if (userId != null) {
        ref.read(latestSkillProfileProvider(userId).notifier).publish(value);
      }
      return const _ProfileSaved();
    case Err(:final failure)
        when failure is SkillProfileFailure &&
            failure.code == SkillProfileErrorCode.retakeTooSoon:
      final last = await ref.read(
        latestSkillProfileProvider(ref.read(currentUserIdProvider) ?? '')
            .future,
      );
      final available = last == null
          ? null
          : const RetakePolicy().nextAvailableOn(
              LocalDate.fromDateTime(last.diagnosedAt),
            );
      return _ProfileRetakeTooSoon(available);
    case Err():
      return const _ProfileSaveFailed();
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
