import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/feedback_composer.dart';
import 'package:flui/features/training/domain/observation.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flutter_test/flutter_test.dart';

const ObservationSource _ai = ObservationSource.ai;

Observation _obs(BehaviorCode code, {ObservationSource source = _ai}) =>
    Observation(code: code, source: source);

void main() {
  const composer = FeedbackComposer();

  group('primary opportunity selection', () {
    test("prefers an opportunity in the challenge's own skill area", () {
      final feedback = composer.compose(
        observations: [
          _obs(BehaviorCode.vagueWord),
          _obs(BehaviorCode.noClosing),
        ],
        challengeArea: SkillArea.thinking,
      );

      expect(feedback.primary?.code, BehaviorCode.noClosing);
    });

    test('falls back to any opportunity when none is in-area', () {
      final feedback = composer.compose(
        observations: [_obs(BehaviorCode.vagueWord)],
        challengeArea: SkillArea.thinking,
      );

      expect(feedback.primary?.code, BehaviorCode.vagueWord);
    });

    test('is null when there is no opportunity at all', () {
      final feedback = composer.compose(
        observations: [_obs(BehaviorCode.clearMainPoint)],
        challengeArea: SkillArea.thinking,
      );

      expect(feedback.primary, isNull);
    });
  });

  group('strength', () {
    test('is optional and carried alongside the primary opportunity', () {
      final feedback = composer.compose(
        observations: [
          _obs(BehaviorCode.noClosing),
          _obs(BehaviorCode.preciseWord),
        ],
        challengeArea: SkillArea.thinking,
      );

      expect(feedback.strength?.code, BehaviorCode.preciseWord);
    });

    test('is null when no strength was observed', () {
      final feedback = composer.compose(
        observations: [_obs(BehaviorCode.noClosing)],
        challengeArea: SkillArea.thinking,
      );

      expect(feedback.strength, isNull);
    });
  });

  group('retry cue', () {
    test('uses the AI-provided cue when present', () {
      final feedback = composer.compose(
        observations: [_obs(BehaviorCode.noClosing)],
        challengeArea: SkillArea.thinking,
        aiRetryCue: 'Cierra con una frase de máximo diez palabras.',
      );

      expect(
        feedback.retryCue,
        'Cierra con una frase de máximo diez palabras.',
      );
    });

    test('falls back to a per-code template when no AI cue is given', () {
      final feedback = composer.compose(
        observations: [_obs(BehaviorCode.noClosing)],
        challengeArea: SkillArea.thinking,
      );

      expect(feedback.retryCue, isNotEmpty);
    });

    test('falls back to a default cue with no primary and no AI cue', () {
      final feedback = composer.compose(
        observations: const [],
        challengeArea: SkillArea.thinking,
      );

      expect(feedback.retryCue, isNotEmpty);
    });
  });

  group('no-number contract (spec training-engine: attempted regression '
      'toward a numeric score is rejected)', () {
    test('composed feedback never renders a digit or percent sign', () {
      final fixtures = [
        composer.compose(
          observations: [
            _obs(BehaviorCode.paceFast, source: ObservationSource.measured),
          ],
          challengeArea: SkillArea.voice,
        ),
        composer.compose(
          observations: [
            _obs(BehaviorCode.noClosing),
            _obs(BehaviorCode.orderedIdeas),
          ],
          challengeArea: SkillArea.thinking,
          aiRetryCue: 'Cierra con una frase breve.',
        ),
        composer.compose(
          observations: const [],
          challengeArea: SkillArea.language,
        ),
      ];

      final forbidden = RegExp('[0-9%]|score|puntaje', caseSensitive: false);
      for (final feedback in fixtures) {
        expect(
          forbidden.hasMatch(feedback.summary),
          isFalse,
          reason:
              'Feedback.summary must never surface a number or score: '
              '"${feedback.summary}"',
        );
      }
    });
  });
}
