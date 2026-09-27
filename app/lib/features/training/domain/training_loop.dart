import 'package:flui/features/training/domain/attempt_kind.dart';
import 'package:meta/meta.dart';

/// The step sequence a [TrainingLoop] runs (design D13). `full` backs
/// daily/lab sessions; `wordUse` backs vocabulary spoken-use; `diagnosis`
/// is measure-only (decision #430, spec conflict C1): it never shows
/// feedback/comparison and never records a repeat or transfer attempt.
/// `quick` practice is added by a later unit (U23e).
sealed class LoopScript {
  const new();

  const factory full() = FullLoopScript;

  const factory wordUse() = WordUseLoopScript;

  const factory diagnosis({required int totalSlots, int startSlot}) =
      DiagnosisLoopScript;
}

final class FullLoopScript extends LoopScript {
  const new();
}

final class WordUseLoopScript extends LoopScript {
  const new();
}

final class DiagnosisLoopScript extends LoopScript {
  const new({required this.totalSlots, this.startSlot = 1});

  final int totalSlots;
  final int startSlot;
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
    FullLoopScript() || WordUseLoopScript() => const TrainingLoopState(
      phase: LoopPhase.focus,
      attemptStep: AttemptKind.first,
    ),
    DiagnosisLoopScript(:final startSlot) => TrainingLoopState(
      phase: LoopPhase.focus,
      attemptStep: AttemptKind.first,
      slot: startSlot,
    ),
  };

  /// The user starts speaking the current step's prompt.
  void startRecording() => _setPhase(LoopPhase.recording);

  /// The recorded audio is being analyzed.
  void startAnalyzing() => _setPhase(LoopPhase.analyzing);

  /// The just-analyzed attempt succeeded; advances per [script].
  void analysisSucceeded() {
    state = switch (script) {
      FullLoopScript() => _advanceFull(),
      WordUseLoopScript() => _advanceWordUse(),
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
  /// never needs this.
  void continueToNextStep() {
    if (state.phase != LoopPhase.feedback &&
        state.phase != LoopPhase.comparison) {
      throw StateError(
        'continueToNextStep is only valid from feedback/comparison, '
        'was ${state.phase}',
      );
    }
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
