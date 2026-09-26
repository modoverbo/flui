import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/observation.dart';
import 'package:flui/features/training/domain/observation_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapper = ObservationMapper();

  group('ObservationMapper.fromAnalysis', () {
    test('maps a valid raw observation to an AI Observation', () {
      final observations = mapper.fromAnalysis(const [
        RawObservation(
          skill: 'thinking',
          code: 'main_point_late',
          polarity: 'opportunity',
          evidence: 'Empezaste con el contexto antes de tu punto.',
        ),
      ]);

      expect(observations, [
        const Observation(
          code: BehaviorCode.mainPointLate,
          source: ObservationSource.ai,
          evidence: 'Empezaste con el contexto antes de tu punto.',
        ),
      ]);
    });

    test('drops an unknown wire code', () {
      final observations = mapper.fromAnalysis(const [
        RawObservation(
          skill: 'thinking',
          code: 'not_a_real_code',
          polarity: 'opportunity',
        ),
      ]);

      expect(observations, isEmpty);
    });

    test("drops when the reported skill does not match the code's area", () {
      final observations = mapper.fromAnalysis(const [
        RawObservation(
          // main_point_late belongs to "thinking", not "language".
          skill: 'language',
          code: 'main_point_late',
          polarity: 'opportunity',
        ),
      ]);

      expect(observations, isEmpty);
    });

    test('drops when the reported polarity does not match the code', () {
      final observations = mapper.fromAnalysis(const [
        RawObservation(
          skill: 'thinking',
          code: 'main_point_late',
          // main_point_late is an opportunity, not a strength.
          polarity: 'strength',
        ),
      ]);

      expect(observations, isEmpty);
    });

    test('treats empty evidence as absent, never an empty string', () {
      final observations = mapper.fromAnalysis(const [
        RawObservation(
          skill: 'thinking',
          code: 'clear_main_point',
          polarity: 'strength',
          evidence: '',
        ),
      ]);

      expect(observations.single.evidence, isNull);
    });

    test('keeps valid entries while dropping invalid ones in the same '
        'batch', () {
      final observations = mapper.fromAnalysis(const [
        RawObservation(
          skill: 'language',
          code: 'vague_word',
          polarity: 'opportunity',
        ),
        RawObservation(
          skill: 'thinking',
          code: 'unknown',
          polarity: 'opportunity',
        ),
      ]);

      expect(observations, [
        const Observation(
          code: BehaviorCode.vagueWord,
          source: ObservationSource.ai,
        ),
      ]);
    });
  });
}
