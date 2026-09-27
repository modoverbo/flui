import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/diagnosis_profiler.dart';
import 'package:flui/features/training/domain/observation.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/skill_profile.dart';
import 'package:flutter_test/flutter_test.dart';

const ObservationSource _ai = ObservationSource.ai;
const ObservationSource _measured = ObservationSource.measured;

Observation _obs(BehaviorCode code, {ObservationSource source = _ai}) =>
    Observation(code: code, source: source);

DiagnosisAttempt _attempt(int slot, List<Observation> observations) =>
    DiagnosisAttempt(
      attemptId: 'attempt-$slot',
      slot: slot,
      observations: observations,
    );

void main() {
  const profiler = DiagnosisProfiler();

  group('incomplete profile', () {
    test('missing slots are reported when fewer than 3 attempts exist', () {
      final result = profiler.profile([
        _attempt(1, [_obs(BehaviorCode.noClosing)]),
      ]);

      expect(result, isA<DiagnosisProfileIncomplete>());
      expect((result as DiagnosisProfileIncomplete).missingSlots, [2, 3]);
    });

    test('a duplicate slot does not count as a different missing slot', () {
      final result = profiler.profile([
        _attempt(1, const []),
        _attempt(1, const []),
      ]);

      expect((result as DiagnosisProfileIncomplete).missingSlots, [2, 3]);
    });
  });

  group('complete profile ranking', () {
    test('the area with strictly more attempts showing an opportunity ranks '
        'first', () {
      final result = profiler.profile([
        _attempt(1, [
          _obs(BehaviorCode.noClosing),
          _obs(BehaviorCode.vagueWord),
        ]),
        _attempt(2, [_obs(BehaviorCode.noClosing)]),
        _attempt(3, const []),
      ]);

      final profile = (result as DiagnosisProfileComplete).profile;
      expect(profile.topArea, SkillArea.thinking);
      expect(profile.topBehavior, BehaviorCode.noClosing);
    });

    test('ties break by priority thinking > language > fluency > voice', () {
      final result = profiler.profile([
        _attempt(1, [
          _obs(BehaviorCode.paceFast, source: _measured),
          _obs(BehaviorCode.longPauses, source: _measured),
          _obs(BehaviorCode.vagueWord),
          _obs(BehaviorCode.noClosing),
        ]),
        _attempt(2, const []),
        _attempt(3, const []),
      ]);

      final profile = (result as DiagnosisProfileComplete).profile;
      expect(profile.topArea, SkillArea.thinking);
      expect(profile.secondArea, SkillArea.language);
    });

    test('strengths come only from areas other than top/second', () {
      final result = profiler.profile([
        _attempt(1, [
          _obs(BehaviorCode.noClosing),
          _obs(BehaviorCode.noClosing),
          _obs(BehaviorCode.vagueWord),
          _obs(BehaviorCode.steadyVolume, source: _measured),
        ]),
        _attempt(2, [_obs(BehaviorCode.noClosing)]),
        _attempt(3, const []),
      ]);

      final profile = (result as DiagnosisProfileComplete).profile;
      expect(profile.topArea, SkillArea.thinking);
      expect(profile.secondArea, SkillArea.language);
      expect(profile.strengths, [BehaviorCode.steadyVolume]);
    });

    test(
      'evidence links only the top/second behaviors back to their attempts',
      () {
        final result = profiler.profile([
          _attempt(1, [_obs(BehaviorCode.noClosing)]),
          _attempt(2, [
            _obs(BehaviorCode.noClosing),
            _obs(BehaviorCode.vagueWord),
          ]),
          _attempt(3, [_obs(BehaviorCode.steadyVolume, source: _measured)]),
        ]);

        final profile = (result as DiagnosisProfileComplete).profile;
        expect(profile.evidence, [
          const DiagnosisEvidence(
            attemptId: 'attempt-1',
            code: BehaviorCode.noClosing,
          ),
          const DiagnosisEvidence(
            attemptId: 'attempt-2',
            code: BehaviorCode.noClosing,
          ),
          const DiagnosisEvidence(
            attemptId: 'attempt-2',
            code: BehaviorCode.vagueWord,
          ),
        ]);
      },
    );
  });
}
