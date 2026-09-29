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

    test('continueToNextStep on the finished loop (comparison/repeat) is a '
        'no-op: never enters focus/transfer, isWordUseFinished stays true '
        '(orchestrator review finding: the "Continuar" button reached this '
        'same generic advance, unguarded, from TrainingLoopController)', () {
      final loop = TrainingLoop(const LoopScript.wordUse())
        ..startRecording()
        ..startAnalyzing()
        ..analysisSucceeded() // -> feedback(first)
        ..continueToNextStep() // -> focus(repeat)
        ..startRecording()
        ..startAnalyzing()
        ..analysisSucceeded(); // -> comparison(repeat), finished
      expect(loop.state.phase, LoopPhase.comparison);
      expect(loop.state.attemptStep, AttemptKind.repeat);
      expect(loop.isWordUseFinished, isTrue);

      loop.continueToNextStep();

      expect(loop.state.phase, LoopPhase.comparison);
      expect(loop.state.attemptStep, AttemptKind.repeat);
      expect(loop.state.attemptStep, isNot(AttemptKind.transfer));
      expect(loop.isWordUseFinished, isTrue);
    });
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

  group('LoopScript value equality (U14a regression)', () {
    // A consumer that rebuilds its `LoopRequest` every widget build (e.g.
    // `DiagnosisPage`, whose `totalSlots` comes from a runtime challenge
    // count and therefore can never be a `const` script) needs two
    // separately-constructed scripts with the same fields to compare
    // equal — otherwise `LoopRequest.==` never matches across rebuilds and
    // every rebuild spawns a brand-new `TrainingLoopController`, silently
    // resetting the loop to slot 1 forever.
    test(
      'two non-const DiagnosisLoopScript with the same fields are equal',
      () {
        // Deliberately non-const: proves the value-equality fix itself,
        // not const canonicalization (which would pass either way).
        // ignore: prefer_const_constructors
        final a = LoopScript.diagnosis(totalSlots: 3);
        // Same reason as `a` above.
        // ignore: prefer_const_constructors
        final b = LoopScript.diagnosis(totalSlots: 3);

        expect(a, b);
        expect(a.hashCode, b.hashCode);
      },
    );

    test('a different totalSlots/startSlot is not equal', () {
      // Deliberately non-const — see the first test in this group.
      // ignore: prefer_const_constructors
      final a = LoopScript.diagnosis(totalSlots: 3);
      // Same reason as `a` above.
      // ignore: prefer_const_constructors
      final b = LoopScript.diagnosis(totalSlots: 3, startSlot: 2);

      expect(a == b, isFalse);
    });

    test('the fieldless scripts are equal by type alone', () {
      // Deliberately non-const — see the first test in this group.
      // ignore: prefer_const_constructors
      expect(LoopScript.full(), LoopScript.full());
      // Same reason as above.
      // ignore: prefer_const_constructors
      expect(LoopScript.wordUse(), LoopScript.wordUse());
      // Same reason as above.
      // ignore: prefer_const_constructors
      expect(LoopScript.quick(), LoopScript.quick());
      expect(const LoopScript.full() == const LoopScript.wordUse(), isFalse);
    });
  });
}
