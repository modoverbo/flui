import 'package:flui/features/themes/data/fake_theme_repository.dart';
import 'package:flui/features/themes/domain/theme.dart';
import 'package:flui/features/themes/domain/theme_recommender.dart';
import 'package:flui/features/themes/presentation/providers/theme_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/learning_builders.dart';
import '../../../../helpers/test_container.dart';

void main() {
  // Reordered by family so "default/catalog order" (sort order) is a real,
  // checkable difference from any answers-ranked order the retired
  // onboarding questions used to produce.
  final familia = buildTheme(slug: 'familia', family: ThemeFamily.emocion);
  final trabajo = buildTheme(slug: 'reuniones', sortOrder: 2);
  final all = [familia, trabajo];

  group('recommendedThemesProvider', () {
    test(
      'recommends in catalog order (no onboarding answers to honor)',
      () async {
        final container = createTestContainer(
          overrides: [
            themeRepositoryProvider.overrideWithValue(
              FakeThemeRepository(themes: all),
            ),
          ],
        );
        addTearDown(container.dispose);

        final recommended = await container.read(
          recommendedThemesProvider.future,
        );

        expect(
          recommended.map((t) => t.slug).toList(),
          ThemeRecommender.rank(themes: all).map((t) => t.slug).toList(),
        );
        expect(recommended.map((t) => t.slug).first, 'familia');
      },
    );
  });
}
