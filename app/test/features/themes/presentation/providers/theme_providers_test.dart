import 'package:flui/core/config/feature_flags.dart';
import 'package:flui/features/onboarding/domain/onboarding_answers.dart';
import 'package:flui/features/onboarding/domain/onboarding_store.dart';
import 'package:flui/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:flui/features/reading/domain/reading.dart';
import 'package:flui/features/themes/data/fake_theme_repository.dart';
import 'package:flui/features/themes/domain/theme.dart';
import 'package:flui/features/themes/domain/theme_recommender.dart';
import 'package:flui/features/themes/presentation/providers/theme_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/learning_builders.dart';
import '../../../../helpers/test_container.dart';

void main() {
  // A user who struggles at work: with the answers honored, the work theme
  // (already first by sort order) stays first and the emotional-family theme
  // never outranks it. Reordered by family so "default/catalog order" (sort
  // order) is a real, checkable difference from "answers-ranked order".
  final familia = buildTheme(slug: 'familia', family: ThemeFamily.emocion);
  final trabajo = buildTheme(slug: 'reuniones', sortOrder: 2);
  final all = [familia, trabajo];

  late InMemoryOnboardingStore store;

  setUp(() {
    store = InMemoryOnboardingStore(
      answers: const OnboardingAnswers(contexts: {Scene.trabajo}),
    );
  });

  group('recommendedThemesProvider', () {
    test('speakingGym off: honors the onboarding answers, as today', () async {
      final container = createTestContainer(
        overrides: [
          themeRepositoryProvider.overrideWithValue(
            FakeThemeRepository(themes: all),
          ),
          onboardingStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);

      final recommended = await container.read(
        recommendedThemesProvider.future,
      );

      expect(recommended.map((t) => t.slug).first, 'reuniones');
    });

    test('speakingGym on: drops the retired onboarding input and falls back '
        "to ThemeRecommender's own catalog-order default, never reading the "
        'onboarding store', () async {
      final container = createTestContainer(
        overrides: [
          themeRepositoryProvider.overrideWithValue(
            FakeThemeRepository(themes: all),
          ),
          speakingGymEnabledProvider.overrideWithValue(true),
          // No onboardingStoreProvider override: proves the provider never
          // reads it while the flag is on (it would throw otherwise).
        ],
      );
      addTearDown(container.dispose);

      final recommended = await container.read(
        recommendedThemesProvider.future,
      );

      expect(
        recommended.map((t) => t.slug).toList(),
        ThemeRecommender.rank(
          themes: all,
          answers: OnboardingAnswers.empty,
        ).map((t) => t.slug).toList(),
      );
      expect(recommended.map((t) => t.slug).first, 'familia');
    });
  });
}
