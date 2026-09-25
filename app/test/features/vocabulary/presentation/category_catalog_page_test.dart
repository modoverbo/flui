import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/features/auth/domain/app_user.dart';
import 'package:flui/features/subscription/domain/access_status.dart';
import 'package:flui/features/themes/data/fake/seed_themes.dart';
import 'package:flui/features/themes/domain/theme.dart' as theme_model;
import 'package:flui/features/vocabulary/data/fake_content_repository.dart';
import 'package:flui/features/vocabulary/presentation/category_catalog_page.dart';
import 'package:flui/features/vocabulary/presentation/providers/vocabulary_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../integration_test/support/app_harness.dart';
import '../../../helpers/learning_fakes.dart';
import '../../../helpers/pump_router.dart';

void main() {
  const ana = AppUser(id: 'user', email: 'ana@example.com', displayName: 'Ana');
  const access = AccessStatus(
    hasAccess: true,
    entitlementStatus: EntitlementStatus.trialing,
  );

  testWidgets('category defaults to Todos and shows published family words', (
    tester,
  ) async {
    final theme = seedThemes.first;
    final word = seedWordsWithThemes.firstWhere(
      (word) => word.themeIds.contains(theme.id),
    );
    final harness = AppHarness(signedInAs: ana, access: access);
    await harness.pumpApp(
      tester,
      initialLocation: AppRoutes.categoryCatalog(theme.family.name),
      arrange: (harness) => harness.planToday(),
    );

    expect(find.text('Todos'), findsOneWidget);
    expect(find.text(word.lemma), findsOneWidget);
    expect(
      find.text('Palabras para ${_familyLabel(theme.family)}'),
      findsOneWidget,
    );
  });

  testWidgets('a family-local theme filter narrows the word list', (
    tester,
  ) async {
    final theme = seedThemes.first;
    final word = seedWordsWithThemes.firstWhere(
      (word) => word.themeIds.contains(theme.id),
    );
    final harness = AppHarness(signedInAs: ana, access: access);
    await harness.pumpApp(
      tester,
      initialLocation: AppRoutes.categoryCatalog(theme.family.name),
      arrange: (harness) => harness.planToday(),
    );

    await tester.tap(find.text(theme.name));
    await tester.pumpAndSettle();

    expect(find.text(word.lemma), findsOneWidget);
    expect(find.text('Todos'), findsOneWidget);
  });

  testWidgets('catalog loading failure offers retry', (tester) async {
    final theme = seedThemes.first;
    final harness = AppHarness(signedInAs: ana, access: access);
    await harness.pumpApp(
      tester,
      initialLocation: AppRoutes.categoryCatalog(theme.family.name),
      arrange: (harness) async {
        await harness.planToday();
        (harness.container.read(
          contentRepositoryProvider,
        ) as FakeContentRepository).nextFailure = const NetworkFailure();
      },
    );

    expect(find.text('No pudimos cargar esta categoría.'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Todos'), findsOneWidget);
  });

  testWidgets('an empty family has an editorial empty state', (tester) async {
    final fakes = LearningFakes(words: []);
    addTearDown(fakes.dispose);
    await pumpRoutedPage(
      tester,
      location: '/category',
      page: const CategoryCatalogPage(familySlug: 'trabajo'),
      overrides: fakes.overrides,
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Todavía no hay palabras publicadas en esta categoría.'),
      findsOneWidget,
    );
  });

  testWidgets('a valid theme filter can render its filtered-empty state', (
    tester,
  ) async {
    const emptyThemeId = 'theme-without-published-words';
    const emptyTheme = theme_model.Theme(
      id: emptyThemeId,
      slug: 'sin-palabras',
      family: theme_model.ThemeFamily.trabajo,
      name: 'Tema sin palabras',
      tagline: 'Un tema sin contenido publicado.',
      jtbd: 'Filtrar una categoría.',
      contentType: theme_model.ThemeContentType.wordDriven,
      status: theme_model.ThemeStatus.live,
      sortOrder: 99,
    );
    final fakes = LearningFakes(themes: [...seedThemes, emptyTheme]);
    addTearDown(fakes.dispose);
    await pumpRoutedPage(
      tester,
      location: '/category',
      page: const CategoryCatalogPage(
        familySlug: 'trabajo',
        initialThemeId: emptyThemeId,
      ),
      overrides: fakes.overrides,
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No hay palabras publicadas para este tema.'),
      findsOneWidget,
    );
  });

  testWidgets('a word attached to multiple family themes appears once', (
    tester,
  ) async {
    final word = seedWordsWithThemes.firstWhere(
      (word) => word.themeIds.isNotEmpty,
    );
    final firstTheme = seedThemes.firstWhere(
      (theme) => theme.id == word.themeIds.first,
    );
    const extraThemeId = 'extra-same-family-theme';
    final extraTheme = firstTheme.copyWith(
      id: extraThemeId,
      slug: 'extra-mismo-grupo',
      name: 'Tema adicional',
    );
    final taggedWord = word.copyWith(
      themeIds: [...word.themeIds, extraThemeId],
    );
    final fakes = LearningFakes(
      words: [taggedWord],
      themes: [...seedThemes, extraTheme],
    );
    addTearDown(fakes.dispose);
    await pumpRoutedPage(
      tester,
      location: '/category',
      page: CategoryCatalogPage(familySlug: firstTheme.family.name),
      overrides: fakes.overrides,
    );
    await tester.pumpAndSettle();

    expect(find.text(word.lemma), findsOneWidget);
  });

  testWidgets('an invalid family is handled with a back action', (
    tester,
  ) async {
    final fakes = LearningFakes();
    addTearDown(fakes.dispose);
    await pumpRoutedPage(
      tester,
      location: '/category',
      page: const CategoryCatalogPage(familySlug: 'unknown'),
      otherRoutes: [AppRoutes.today],
      overrides: fakes.overrides,
    );

    expect(find.text('No encontramos esta categoría.'), findsOneWidget);
    expect(find.text('Volver'), findsOneWidget);
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();
    expect(find.text('route:${AppRoutes.today}'), findsOneWidget);
  });
}

String _familyLabel(theme_model.ThemeFamily family) => switch (family) {
  theme_model.ThemeFamily.trabajo => 'En el trabajo',
  theme_model.ThemeFamily.social => 'Con la gente',
  theme_model.ThemeFamily.publico => 'Delante de gente',
  theme_model.ThemeFamily.precision => 'Decirlo exacto',
  theme_model.ThemeFamily.emocion => 'Lo que cuesta decir',
};
