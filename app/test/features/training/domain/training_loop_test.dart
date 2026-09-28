import 'package:flui/features/training/domain/attempt_kind.dart';
import 'package:flui/features/training/domain/training_loop.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('full loop (daily/lab)', () {
    test('runs focus -> feedback -> focus(repeat) -> comparison -> '
        'focus(transfer) -> summary', () {
      final loop = TrainingLoop(const LoopScript.full());
      expect(loop.state.phase, LoopPhase.focus);
      expect(loop.state.attemptStep, AttemptKind.first);

      loop
        ..startRecording()
        ..startAnalyzing()
        ..analysisSucceeded();
      expect(loop.state.phase, LoopPhase.feedback);
      expect(loop.state.attemptStep, AttemptKind.first);

      loop.continueToNextStep();
      expect(loop.state.phase, LoopPhase.focus);
      expect(loop.state.attemptStep, AttemptKind.repeat);

      loop
        ..startRecording()
        ..startAnalyzing()
        ..analysisSucceeded();
      expect(loop.state.phase, LoopPhase.comparison);
      expect(loop.state.attemptStep, AttemptKind.repeat);

      loop.continueToNextStep();
      expect(loop.state.phase, LoopPhase.focus);
      expect(loop.state.attemptStep, AttemptKind.transfer);

      loop
        ..startRecording()
        ..startAnalyzing()
        ..analysisSucceeded();
      expect(loop.state.phase, LoopPhase.summary);
    });

    test('an access-required failure preserves the current step for retry', () {
      final loop = TrainingLoop(const LoopScript.full())
        ..startRecording()
        ..startAnalyzing()
        ..accessRequired();

      expect(loop.state.phase, LoopPhase.accessRequired);
      expect(loop.state.attemptStep, AttemptKind.first);

      loop.retry();
      expect(loop.state.phase, LoopPhase.focus);
      expect(loop.state.attemptStep, AttemptKind.first);
    });

    test(
      'an analysis failure records its code and never fabricates feedback',
      () {
        final loop = TrainingLoop(const LoopScript.full())
          ..startRecording()
          ..startAnalyzing()
          ..analysisFailed('upstream_error');

        expect(loop.state.phase, LoopPhase.analysisFailed);
        expect(loop.state.failureCode, 'upstream_error');
      },
    );

    test('permission denial is a distinct terminal-ish phase', () {
      final loop = TrainingLoop(const LoopScript.full())
        ..startRecording()
        ..permissionDenied();

      expect(loop.state.phase, LoopPhase.permissionDenied);
    });
  });

  group('wordUse loop', () {
    test(
      'runs focus -> feedback -> focus(repeat) -> comparison, no transfer',
      () {
        final loop = TrainingLoop(const LoopScript.wordUse())
          ..startRecording()
          ..startAnalyzing()
          ..analysisSucceeded();
        expect(loop.state.phase, LoopPhase.feedback);

        loop
          ..continueToNextStep()
          ..startRecording()
          ..startAnalyzing()
          ..analysisSucceeded();

        expect(loop.state.phase, LoopPhase.comparison);
        expect(loop.state.attemptStep, AttemptKind.repeat);
      },
    );
  });

  group('quick loop is single-shot (decision #450.3, D33, §19.13)', () {
    test(
      'runs focus -> feedback -> summary, never repeat/comparison/transfer',
      () {
        final loop = TrainingLoop(const LoopScript.quick())
          ..startRecording()
          ..startAnalyzing()
          ..analysisSucceeded();
        expect(loop.state.phase, LoopPhase.feedback);
        expect(loop.state.attemptStep, AttemptKind.first);

        loop.continueToNextStep();
        expect(loop.state.phase, LoopPhase.summary);
        expect(loop.state.attemptStep, isNull);
      },
    );

    test('an access-required failure preserves the focus step for retry', () {
      final loop = TrainingLoop(const LoopScript.quick())
        ..startRecording()
        ..startAnalyzing()
        ..accessRequired();

      expect(loop.state.phase, LoopPhase.accessRequired);
      expect(loop.state.attemptStep, AttemptKind.first);

      loop.retry();
      expect(loop.state.phase, LoopPhase.focus);
      expect(loop.state.attemptStep, AttemptKind.first);
    });
  });

  group('diagnosis loop is measure-only (decision #430, spec conflict C1)', () {
    test('never enters feedback, comparison, or a repeat/transfer step', () {
      final loop = TrainingLoop(const LoopScript.diagnosis(totalSlots: 3));
      final visitedPhases = <LoopPhase>{loop.state.phase};
      final visitedSteps = <AttemptKind?>{loop.state.attemptStep};

      for (var slot = 1; slot <= 3; slot++) {
        expect(loop.state.slot, slot);
        expect(loop.state.attemptStep, AttemptKind.first);

        loop
          ..startRecording()
          ..startAnalyzing()
          ..analysisSucceeded();

        visitedPhases.add(loop.state.phase);
        visitedSteps.add(loop.state.attemptStep);
      }

      expect(loop.state.phase, LoopPhase.summary);
      expect(visitedPhases, isNot(contains(LoopPhase.feedback)));
      expect(visitedPhases, isNot(contains(LoopPhase.comparison)));
      expect(visitedSteps, isNot(contains(AttemptKind.repeat)));
      expect(visitedSteps, isNot(contains(AttemptKind.transfer)));
    });

    test('starts at the given resume slot instead of slot 1', () {
      final loop = TrainingLoop(
        const LoopScript.diagnosis(totalSlots: 3, startSlot: 2),
      );

      expect(loop.state.slot, 2);
      expect(loop.state.attemptStep, AttemptKind.first);
    });

    test('an access-required failure mid-diagnosis never reaches feedback', () {
      final loop = TrainingLoop(const LoopScript.diagnosis(totalSlots: 3))
        ..startRecording()
        ..startAnalyzing()
        ..accessRequired();

      expect(loop.state.phase, LoopPhase.accessRequired);
      expect(loop.state.slot, 1);
    });
  });
}
