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
    test('keeps the catalog order', () {
      final ranked = ThemeRecommender.rank(themes: all);

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
      expect(ThemeRecommender.recommend(themes: all), hasLength(3));
    });

    test('only themes that are live today are recommended', () {
      final soon = buildTheme(
        slug: 'pronto',
        status: ThemeStatus.soon,
        sortOrder: 0,
      );

      final ranked = ThemeRecommender.rank(themes: [soon, ...all]);

      expect(ranked.map((t) => t.slug), isNot(contains('pronto')));
    });

    test('ties break by catalog order, so the list never shuffles', () {
      final first = ThemeRecommender.rank(themes: all);
      final second = ThemeRecommender.rank(themes: all.reversed.toList());

      expect(
        first.map((t) => t.slug).toList(),
        second.map((t) => t.slug).toList(),
      );
    });

    test('a user keeps at most three themes of their own', () {
      expect(ThemeRecommender.maxUserThemes, 3);
    });

    test('recommend never returns more than the catalog holds', () {
      expect(ThemeRecommender.recommend(themes: [trabajo]), hasLength(1));
    });
  });
}
