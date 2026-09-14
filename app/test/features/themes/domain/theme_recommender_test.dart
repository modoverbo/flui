import 'package:flui/features/onboarding/domain/onboarding_answers.dart';
import 'package:flui/features/reading/domain/reading.dart';
import 'package:flui/features/themes/domain/theme.dart';
import 'package:flui/features/themes/domain/theme_recommender.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/learning_builders.dart';

void main() {
  final trabajo = buildTheme(slug: 'reuniones');
  final publico = buildTheme(
    slug: 'presentaciones',
    family: ThemeFamily.publico,
    sortOrder: 2,
  );
  final emocion = buildTheme(
    slug: 'desacuerdos',
    family: ThemeFamily.emocion,
    sortOrder: 3,
  );
  final precision = buildTheme(
    slug: 'matices',
    family: ThemeFamily.precision,
    sortOrder: 4,
  );
  final social = buildTheme(
    slug: 'reconocer',
    family: ThemeFamily.social,
    sortOrder: 5,
  );
  final all = [trabajo, publico, emocion, precision, social];

  group('ThemeRecommender', () {
    test('with no answers it keeps the catalog order', () {
      final ranked = ThemeRecommender.rank(
        themes: all,
        answers: OnboardingAnswers.empty,
      );

      expect(ranked.map((t) => t.slug), [
        'reuniones',
        'presentaciones',
        'desacuerdos',
        'matices',
        'reconocer',
      ]);
    });

    test('offers exactly three recommendations', () {
      expect(ThemeRecommender.recommendedCount, 3);
      expect(
        ThemeRecommender.recommend(
          themes: all,
          answers: OnboardingAnswers.empty,
        ),
        hasLength(3),
      );
    });

    test('a user who struggles at work gets work themes first', () {
      const answers = OnboardingAnswers(contexts: {Scene.trabajo});

      final ranked = ThemeRecommender.rank(themes: all, answers: answers);

      expect(ranked.first.slug, 'reuniones');
    });

    test('a user who struggles at home gets the emotional family first', () {
      const answers = OnboardingAnswers(contexts: {Scene.familia});

      final ranked = ThemeRecommender.rank(themes: all, answers: answers);

      expect(ranked.first.slug, 'desacuerdos');
    });

    test('interviews pull the public-speaking family up', () {
      const answers = OnboardingAnswers(contexts: {Scene.entrevista});

      final ranked = ThemeRecommender.rank(themes: all, answers: answers);

      expect(ranked.first.slug, 'presentaciones');
    });

    test('wanting to sound precise pulls the precision family up', () {
      const answers = OnboardingAnswers(tone: SpeakingTone.precise);

      final ranked = ThemeRecommender.rank(themes: all, answers: answers);

      expect(ranked.first.slug, 'matices');
    });

    test('wanting to sound warm pulls the social side up', () {
      const answers = OnboardingAnswers(
        contexts: {Scene.social},
        tone: SpeakingTone.warm,
      );

      final ranked = ThemeRecommender.rank(themes: all, answers: answers);

      expect(ranked.take(2).map((t) => t.slug), containsAll(['reconocer']));
    });

    test('only themes that are live today are recommended', () {
      final soon = buildTheme(
        slug: 'pronto',
        status: ThemeStatus.soon,
        sortOrder: 0,
      );

      final ranked = ThemeRecommender.rank(
        themes: [soon, ...all],
        answers: const OnboardingAnswers(contexts: {Scene.trabajo}),
      );

      expect(ranked.map((t) => t.slug), isNot(contains('pronto')));
    });

    test('ties break by catalog order, so the list never shuffles', () {
      const answers = OnboardingAnswers(contexts: {Scene.trabajo});

      final first = ThemeRecommender.rank(themes: all, answers: answers);
      final second = ThemeRecommender.rank(
        themes: all.reversed.toList(),
        answers: answers,
      );

      expect(
        first.map((t) => t.slug).toList(),
        second.map((t) => t.slug).toList(),
      );
    });

    test('a user keeps at most three themes of their own', () {
      expect(ThemeRecommender.maxUserThemes, 3);
    });

    test('recommend never returns more than the catalog holds', () {
      expect(
        ThemeRecommender.recommend(
          themes: [trabajo],
          answers: OnboardingAnswers.empty,
        ),
        hasLength(1),
      );
    });
  });
}
