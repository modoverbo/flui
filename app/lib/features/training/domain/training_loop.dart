import 'package:flui/features/training/domain/attempt_kind.dart';
import 'package:meta/meta.dart';

/// The step sequence a [TrainingLoop] runs (design D13). `full` backs
/// daily/lab sessions; `wordUse` backs vocabulary spoken-use; `diagnosis`
/// is measure-only (decision #430, spec conflict C1): it never shows
/// feedback/comparison and never records a repeat or transfer attempt.
/// `quick` (decision #450.3, D33, design §19.13) is single-shot: focus ->
/// feedback -> summary, never repeat/comparison/transfer either — but,
/// unlike diagnosis, it DOES show feedback for its one attempt.
@immutable
sealed class LoopScript {
  const new();

  const factory full() = FullLoopScript;

  const factory wordUse() = WordUseLoopScript;

  const factory quick() = QuickLoopScript;

  const factory diagnosis({required int totalSlots, int startSlot}) =
      DiagnosisLoopScript;
}

@immutable
final class FullLoopScript extends LoopScript {
  const new();

  @override
  bool operator ==(Object other) => other is FullLoopScript;

  @override
  int get hashCode => (FullLoopScript).hashCode;
}

@immutable
final class WordUseLoopScript extends LoopScript {
  const new();

  @override
  bool operator ==(Object other) => other is WordUseLoopScript;

  @override
  int get hashCode => (WordUseLoopScript).hashCode;
}

@immutable
final class QuickLoopScript extends LoopScript {
  const new();

  @override
  bool operator ==(Object other) => other is QuickLoopScript;

  @override
  int get hashCode => (QuickLoopScript).hashCode;
}

/// Unlike the other 3 (fieldless, trivially `const`-canonicalized), this
/// one carries fields a caller may only know at runtime (`totalSlots` from
/// a fetched catalog) — so it needs real value equality: a widget that
/// rebuilds its `LoopRequest` every build (e.g. `DiagnosisPage`, U14a)
/// would otherwise spawn a brand-new, non-`const` instance each time,
/// breaking `LoopRequest.==` and silently resetting its loop's
/// `TrainingLoopController` to a fresh one on every rebuild.
@immutable
final class DiagnosisLoopScript extends LoopScript {
  const new({required this.totalSlots, this.startSlot = 1});

  final int totalSlots;
  final int startSlot;

  @override
  bool operator ==(Object other) =>
      other is DiagnosisLoopScript &&
      other.totalSlots == totalSlots &&
      other.startSlot == startSlot;

  @override
  int get hashCode => Object.hash(DiagnosisLoopScript, totalSlots, startSlot);
}

/// A [TrainingLoop]'s current step. `recording`/`analyzing`/
/// `accessRequired`/`analysisFailed` carry which speak step
/// ([TrainingLoopState.attemptStep]) they answer; diagnosis states
/// additionally carry which [TrainingLoopState.slot].
enum LoopPhase {
  focus,
  recording,
  analyzing,
  feedback,
  comparison,
  summary,
  accessRequired,
  analysisFailed,
  permissionDenied,
}

@immutable
final class TrainingLoopState {
  const new({
    required this.phase,
    this.attemptStep,
    this.slot,
    this.failureCode,
  });

  final LoopPhase phase;
  final AttemptKind? attemptStep;
  final int? slot;
  final String? failureCode;

  @override
  bool operator ==(Object other) =>
      other is TrainingLoopState &&
      other.phase == phase &&
      other.attemptStep == attemptStep &&
      other.slot == slot &&
      other.failureCode == failureCode;

  @override
  int get hashCode => Object.hash(phase, attemptStep, slot, failureCode);

  @override
  String toString() =>
      'TrainingLoopState($phase, step: $attemptStep, slot: $slot)';
}

/// Whether [state] is [WordUseLoopScript]'s own terminal state under
/// [script] — no further speak step exists to continue into (orchestrator
/// review finding). `wordUse`'s two-step script (`first` -> `repeat`) has
/// no `transfer` step, unlike `full`/`diagnosis`'s longer sequences, so it
/// never reaches `LoopPhase.summary`; `comparison` (reached once the
/// repeat attempt's own analysis succeeds) is as far as it ever advances.
///
/// A plain top-level function (not only [TrainingLoop.isWordUseFinished])
/// so every caller that only has `script`/`state` apart — never a full
/// [TrainingLoop] instance — can check the SAME condition instead of
/// re-deriving it: `LoopMicTarget` (has a `LoopRequest`, not a
/// `TrainingLoop`) and `TrainingLoopView`'s own phase body (deciding
/// whether to show "Continuar") both use this directly.
bool isWordUseLoopFinished(LoopScript script, TrainingLoopState state) =>
    script is WordUseLoopScript &&
    state.phase == LoopPhase.comparison &&
    state.attemptStep == AttemptKind.repeat;

/// Drives one training session through its [script]'s steps.
///
/// Pure state machine: it never records or analyzes audio itself — the
/// caller (`TrainingLoopController`, U13a) owns capture/analysis and only
/// reports outcomes here.
final class TrainingLoop {
  new(this.script) : state = _initial(script);

  final LoopScript script;
  TrainingLoopState state;

  static TrainingLoopState _initial(LoopScript script) => switch (script) {
    FullLoopScript() ||
    WordUseLoopScript() ||
    QuickLoopScript() => const TrainingLoopState(
      phase: LoopPhase.focus,
      attemptStep: AttemptKind.first,
    ),
    DiagnosisLoopScript(:final startSlot) => TrainingLoopState(
      phase: LoopPhase.focus,
      attemptStep: AttemptKind.first,
      slot: startSlot,
    ),
  };

  /// Whether the CURRENT phase is [WordUseLoopScript]'s own terminal
  /// state — no further speak step exists to continue into (orchestrator
  /// review finding). See the top-level [isWordUseLoopFinished] this
  /// delegates to for the full rationale; a getter here so callers that
  /// already hold a [TrainingLoop] (`TrainingLoopController`) don't need
  /// to pass `script`/`state` apart.
  bool get isWordUseFinished => isWordUseLoopFinished(script, state);

  /// The user starts speaking the current step's prompt.
  void startRecording() => _setPhase(LoopPhase.recording);

  /// The recorded audio is being analyzed.
  void startAnalyzing() => _setPhase(LoopPhase.analyzing);

  /// The just-analyzed attempt succeeded; advances per [script].
  void analysisSucceeded() {
    state = switch (script) {
      FullLoopScript() => _advanceFull(),
      WordUseLoopScript() => _advanceWordUse(),
      QuickLoopScript() => _advanceQuick(),
      DiagnosisLoopScript(:final totalSlots) => _advanceDiagnosis(totalSlots),
    };
  }

  void analysisFailed(String code) => state = TrainingLoopState(
    phase: LoopPhase.analysisFailed,
    attemptStep: state.attemptStep,
    slot: state.slot,
    failureCode: code,
  );

  void accessRequired() => _setPhase(LoopPhase.accessRequired);

  void permissionDenied() => _setPhase(LoopPhase.permissionDenied);

  /// Returns to the focus step after a failure/permission-denial, without
  /// fabricating a feedback/comparison for a step that never analyzed.
  void retry() => _setPhase(LoopPhase.focus);

  /// Moves from a passive [LoopPhase.feedback]/[LoopPhase.comparison] into
  /// the next speak step. Diagnosis never reaches those phases, so it
  /// never needs this. [QuickLoopScript] only ever reaches `feedback` for
  /// its one attempt — this always closes it straight to [LoopPhase.summary]
  /// instead of a repeat step (decision #450.3: quick practice never
  /// enters repeat/comparison/transfer).
  void continueToNextStep() {
    if (state.phase != LoopPhase.feedback &&
        state.phase != LoopPhase.comparison) {
      throw StateError(
        'continueToNextStep is only valid from feedback/comparison, '
        'was ${state.phase}',
      );
    }
    if (script is QuickLoopScript) {
      state = const TrainingLoopState(phase: LoopPhase.summary);
      return;
    }
    // Orchestrator review finding: `wordUse`'s own terminal `comparison`
    // state has no valid next step — the generic `repeat -> transfer`
    // advance below would otherwise push it into an attempt step
    // `analysisSucceeded`/`_advanceWordUse` can never resolve. A no-op:
    // the finished state is already stable and correct, there is nothing
    // to continue INTO (the mic itself offers "Practicar otra vez"
    // instead — a NEW loop, not a continuation of this one).
    if (isWordUseFinished) return;
    final nextStep = switch (state.attemptStep) {
      AttemptKind.first => AttemptKind.repeat,
      AttemptKind.repeat => AttemptKind.transfer,
      AttemptKind.transfer ||
      null => throw StateError('no next step after ${state.attemptStep}'),
    };
    state = TrainingLoopState(phase: LoopPhase.focus, attemptStep: nextStep);
  }

  void _setPhase(LoopPhase phase) => state = TrainingLoopState(
    phase: phase,
    attemptStep: state.attemptStep,
    slot: state.slot,
  );

  TrainingLoopState _advanceFull() => switch (state.attemptStep) {
    AttemptKind.first => const TrainingLoopState(
      phase: LoopPhase.feedback,
      attemptStep: AttemptKind.first,
    ),
    AttemptKind.repeat => const TrainingLoopState(
      phase: LoopPhase.comparison,
      attemptStep: AttemptKind.repeat,
    ),
    AttemptKind.transfer => const TrainingLoopState(phase: LoopPhase.summary),
    null => throw StateError('no attempt step to advance from'),
  };

  TrainingLoopState _advanceWordUse() => switch (state.attemptStep) {
    AttemptKind.first => const TrainingLoopState(
      phase: LoopPhase.feedback,
      attemptStep: AttemptKind.first,
    ),
    AttemptKind.repeat => const TrainingLoopState(
      phase: LoopPhase.comparison,
      attemptStep: AttemptKind.repeat,
    ),
    AttemptKind.transfer ||
    null => throw StateError('wordUse has no transfer step'),
  };

  /// The one and only speak step of a [QuickLoopScript]: `first` ->
  /// `feedback`. There is no valid state to advance FROM other than
  /// `first` — quick practice never records a repeat or transfer attempt
  /// (decision #450.3), so [analysisSucceeded] is never called again for
  /// this session after this.
  TrainingLoopState _advanceQuick() => switch (state.attemptStep) {
    AttemptKind.first => const TrainingLoopState(
      phase: LoopPhase.feedback,
      attemptStep: AttemptKind.first,
    ),
    AttemptKind.repeat ||
    AttemptKind.transfer ||
    null => throw StateError('quick has no repeat/transfer step'),
  };

  TrainingLoopState _advanceDiagnosis(int totalSlots) {
    final currentSlot = state.slot ?? 1;
    if (currentSlot < totalSlots) {
      return TrainingLoopState(
        phase: LoopPhase.focus,
        attemptStep: AttemptKind.first,
        slot: currentSlot + 1,
      );
    }
    return const TrainingLoopState(phase: LoopPhase.summary);
  }
}
