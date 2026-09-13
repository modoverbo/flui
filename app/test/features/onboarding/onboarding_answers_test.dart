import 'package:flui/features/onboarding/domain/onboarding_answers.dart';
import 'package:flui/features/reading/domain/reading.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OnboardingAnswers', () {
    test('starts empty and incomplete', () {
      expect(OnboardingAnswers.empty.isEmpty, isTrue);
      expect(OnboardingAnswers.empty.isComplete, isFalse);
      expect(OnboardingAnswers.empty.contexts, isEmpty);
      expect(OnboardingAnswers.empty.tone, isNull);
    });

    test('toggles a context on and off without touching the tone', () {
      final withWork = OnboardingAnswers.empty
          .withTone(SpeakingTone.warm)
          .withContext(Scene.trabajo, selected: true);

      expect(withWork.contexts, {Scene.trabajo});
      expect(withWork.tone, SpeakingTone.warm);

      final without = withWork.withContext(Scene.trabajo, selected: false);
      expect(without.contexts, isEmpty);
      expect(without.tone, SpeakingTone.warm);
    });

    test('is complete only when both questions are answered', () {
      final contextsOnly = OnboardingAnswers.empty.withContext(
        Scene.social,
        selected: true,
      );
      expect(contextsOnly.isComplete, isFalse);
      expect(contextsOnly.withTone(SpeakingTone.precise).isComplete, isTrue);
    });

    test('reads contexts back in catalog order, never selection order', () {
      final answers = OnboardingAnswers.empty
          .withContext(Scene.familia, selected: true)
          .withContext(Scene.trabajo, selected: true)
          .withContext(Scene.entrevista, selected: true);

      expect(answers.orderedContexts, [
        Scene.trabajo,
        Scene.entrevista,
        Scene.familia,
      ]);
    });

    test('round-trips through JSON', () {
      final answers = OnboardingAnswers.empty
          .withContext(Scene.trabajo, selected: true)
          .withContext(Scene.social, selected: true)
          .withTone(SpeakingTone.confident);

      expect(OnboardingAnswers.fromJson(answers.toJson()), answers);
    });

    test('survives values it does not know', () {
      final answers = OnboardingAnswers.fromJson(const {
        'contexts': ['trabajo', 'zoo'],
        'tone': 'telepathic',
      });

      expect(answers.contexts, {Scene.trabajo});
      expect(answers.tone, isNull);
    });

    test('survives a malformed payload', () {
      expect(
        OnboardingAnswers.fromJson(const {'contexts': 7, 'tone': 3}),
        OnboardingAnswers.empty,
      );
      expect(OnboardingAnswers.fromJson(const {}), OnboardingAnswers.empty);
    });

    test('equality ignores insertion order', () {
      final a = OnboardingAnswers.empty
          .withContext(Scene.trabajo, selected: true)
          .withContext(Scene.social, selected: true);
      final b = OnboardingAnswers.empty
          .withContext(Scene.social, selected: true)
          .withContext(Scene.trabajo, selected: true);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('joinContexts', () {
    test('writes a Spanish list', () {
      expect(joinContexts(const []), '');
      expect(joinContexts(const ['el trabajo']), 'el trabajo');
      expect(
        joinContexts(const ['el trabajo', 'las entrevistas']),
        'el trabajo y las entrevistas',
      );
      expect(
        joinContexts(const ['el trabajo', 'lo social', 'la familia']),
        'el trabajo, lo social y la familia',
      );
    });
  });
}
