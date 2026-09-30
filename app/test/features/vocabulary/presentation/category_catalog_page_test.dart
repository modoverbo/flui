import 'dart:ui' show Rect;

import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/features/auth/domain/app_user.dart';
import 'package:flui/features/subscription/domain/access_status.dart';
import 'package:flui/features/themes/data/fake/seed_themes.dart';
import 'package:flui/features/themes/domain/theme.dart' as theme_model;
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/skill_profile.dart';
import 'package:flui/features/vocabulary/data/fake_content_repository.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/features/vocabulary/presentation/category_catalog_page.dart';
import 'package:flui/features/vocabulary/presentation/providers/vocabulary_providers.dart';
import 'package:flui/shared/widgets/flui_card.dart';

import 'package:flutter/material.dart'
    show
        BoxDecoration,
        CustomScrollView,
        DecoratedBox,
        Scrollable,
        ScrollableState,
        Size,
        Text,
        Transform,
        ValueKey;
import 'package:flutter_test/flutter_test.dart';

import '../../../../integration_test/support/app_harness.dart';
import '../../../helpers/learning_fakes.dart';
import '../../../helpers/pump_router.dart';

/// Diagnosis is mandatory once access is granted (U14a) — every real-path
/// `AppHarness` test below exercises something else entirely and needs the
/// signed-in user's diagnosis already completed so `appRedirect` never
/// detours it to `/diagnosis` first.
Future<void> _completeDiagnosis(AppHarness harness) => harness.skillProfiles
    .save(
      sessionId: 'seed-diagnosis',
      profile: const SkillProfile(
        topArea: SkillArea.thinking,
        secondArea: SkillArea.language,
        strengths: <BehaviorCode>[],
        evidence: <DiagnosisEvidence>[],
      ),
    )
    .then((_) {});

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
      arrange: (harness) async {
        await harness.planToday();
        await _completeDiagnosis(harness);
      },
    );

    expect(find.text('Todos'), findsOneWidget);
    expect(find.text(word.lemma), findsOneWidget);
    expect(
      find.text('Palabras para ${_familyLabel(theme.family)}'),
      findsOneWidget,
    );
  });

  testWidgets('word cards show metadata and concise factual previews', (
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
      arrange: (harness) async {
        await harness.planToday();
        await _completeDiagnosis(harness);
      },
    );

    expect(find.text(_partOfSpeechLabel(word.partOfSpeech)), findsOneWidget);
    expect(find.text(_registerLabel(word.register)), findsOneWidget);
    expect(find.text('Significado'), findsOneWidget);
    expect(find.text(word.explanation), findsOneWidget);
    final meaning = tester.widget<Text>(find.text(word.explanation));
    expect(meaning.maxLines, 2);
    final teaser = word.usageTip?.isNotEmpty == true
        ? word.usageTip!
        : word.exampleSentence;
    expect(find.text(teaser), findsOneWidget);
    expect(tester.widget<Text>(find.text(teaser)).maxLines, 1);
  });

  testWidgets('header chip stays clear of the first preview card', (
    tester,
  ) async {
    final theme = seedThemes.first;
    final template = seedWordsWithThemes.firstWhere(
      (word) => word.themeIds.contains(theme.id),
    );
    final fakes = LearningFakes(
      themes: seedThemes,
      words: [template.copyWith(id: 'header-word', slug: 'header-word')],
    );
    addTearDown(fakes.dispose);
    await pumpRoutedPage(
      tester,
      location: '/category',
      page: CategoryCatalogPage(familySlug: theme.family.name),
      overrides: fakes.overrides,
      surfaceSize: const Size(432, 860),
    );
    await tester.pumpAndSettle();

    final chip = tester.getRect(find.text('Escribir para que te lean'));
    final card = tester.getRect(
      find.descendant(
        of: find.byKey(const ValueKey('category-word-header-word')),
        matching: find.byType(FluiCard),
      ),
    );
    expect(chip.overlaps(card), isFalse, reason: 'chip=$chip card=$card');
  });

  testWidgets('overlapping previews keep each visible text line uncovered', (
    tester,
  ) async {
    final theme = seedThemes.first;
    final template = seedWordsWithThemes.firstWhere(
      (word) => word.themeIds.contains(theme.id),
    );
    final fakes = LearningFakes(
      themes: seedThemes,
      words: [
        for (var index = 0; index < 8; index++)
          template.copyWith(
            id: 'preview-word-$index',
            slug: 'preview-word-$index',
            lemma: 'previa-$index',
            explanation:
                'Significado breve $index. '
                '${List.filled(18, 'detalle').join(' ')}',
            exampleSentence:
                'Ejemplo breve $index. '
                '${List.filled(16, 'contexto').join(' ')}',
            usageTip: null,
            themeIds: [theme.id],
          ),
      ],
    );
    addTearDown(fakes.dispose);
    await pumpRoutedPage(
      tester,
      location: '/category',
      page: CategoryCatalogPage(familySlug: theme.family.name),
      overrides: fakes.overrides,
      surfaceSize: const Size(432, 860),
    );
    await tester.pumpAndSettle();

    Rect surface(String id) => tester.getRect(
      find.descendant(
        of: find.byKey(ValueKey('category-word-$id')),
        matching: find.byType(FluiCard),
      ),
    );
    Rect text(String id, String value) => tester.getRect(
      find.descendant(
        of: find.byKey(ValueKey('category-word-$id')),
        matching: find.text(value),
      ),
    );

    for (final (offset, previous, following) in [
      (400.0, 0, 1),
      (800.0, 1, 2),
    ]) {
      _jumpCategoryScroll(tester, offset);
      await tester.pumpAndSettle();
      final previousId = 'preview-word-$previous';
      final nextSurface = surface('preview-word-$following');
      expect(surface(previousId).overlaps(nextSurface), isTrue);
      final visibleText = [
        'previa-$previous',
        'Adjetivo',
        'Registro neutro',
        'Significado',
        'Significado breve $previous. ${List.filled(18, 'detalle').join(' ')}',
        'Ejemplo',
        'Ejemplo breve $previous. ${List.filled(16, 'contexto').join(' ')}',
      ];
      for (final value in visibleText) {
        final visibleRect = text(previousId, value);
        expect(
          nextSurface.overlaps(visibleRect),
          isFalse,
          reason: '$value is covered before preview $following',
        );
      }
    }
  });

  testWidgets('preview cards use color and shadow without a large blank foot', (
    tester,
  ) async {
    final theme = seedThemes.first;
    final word = seedWordsWithThemes.firstWhere(
      (word) => word.themeIds.contains(theme.id),
    );
    final fakes = LearningFakes(
      themes: seedThemes,
      words: [word.copyWith(id: 'surface-word', slug: 'surface-word')],
    );
    addTearDown(fakes.dispose);
    await pumpRoutedPage(
      tester,
      location: '/category',
      page: CategoryCatalogPage(familySlug: theme.family.name),
      overrides: fakes.overrides,
      surfaceSize: const Size(432, 860),
    );
    await tester.pumpAndSettle();

    final shadowFinder = find.byKey(
      const ValueKey('category-card-shadow-surface-word'),
    );
    expect(shadowFinder, findsOneWidget);
    final shadow = tester.widget<DecoratedBox>(shadowFinder);
    final shadowDecoration = shadow.decoration as BoxDecoration;
    expect(shadowDecoration.boxShadow, isNotEmpty);

    final teaserFinder = find.byKey(
      const ValueKey('category-card-teaser-surface-word'),
    );
    expect(teaserFinder, findsOneWidget);
    final teaser = tester.widget<DecoratedBox>(teaserFinder);
    final teaserDecoration = teaser.decoration as BoxDecoration;
    expect(teaserDecoration.color, isNot(FluiColors.surface));

    final cardBounds = tester.getRect(
      find.descendant(
        of: find.byKey(const ValueKey('category-word-surface-word')),
        matching: find.byType(FluiCard),
      ),
    );
    final teaserBounds = tester.getRect(
      find.byKey(const ValueKey('category-card-teaser-surface-word')),
    );
    expect(cardBounds.bottom - teaserBounds.bottom, lessThanOrEqualTo(56));
  });

  testWidgets('catalog builds word cards lazily for long families', (
    tester,
  ) async {
    final theme = seedThemes.first;
    final template = seedWordsWithThemes.firstWhere(
      (word) => word.themeIds.contains(theme.id),
    );
    final fakes = LearningFakes(
      themes: seedThemes,
      words: [
        for (var index = 0; index < 164; index++)
          template.copyWith(
            id: 'long-word-$index',
            slug: 'long-word-$index',
            lemma: 'palabra-$index',
            themeIds: [theme.id],
          ),
      ],
    );
    addTearDown(fakes.dispose);
    await pumpRoutedPage(
      tester,
      location: '/category',
      page: CategoryCatalogPage(familySlug: theme.family.name),
      overrides: fakes.overrides,
      surfaceSize: const Size(432, 860),
    );
    await tester.pumpAndSettle();

    expect(find.text('palabra-163'), findsNothing);
  });

  testWidgets('scrolling changes the visible cards depth transform', (
    tester,
  ) async {
    final theme = seedThemes.first;
    final template = seedWordsWithThemes.firstWhere(
      (word) => word.themeIds.contains(theme.id),
    );
    final fakes = LearningFakes(
      themes: seedThemes,
      words: [
        for (var index = 0; index < 20; index++)
          template.copyWith(
            id: 'motion-word-$index',
            slug: 'motion-word-$index',
            lemma: 'movimiento-$index',
            themeIds: [theme.id],
          ),
      ],
    );
    addTearDown(fakes.dispose);
    await pumpRoutedPage(
      tester,
      location: '/category',
      page: CategoryCatalogPage(familySlug: theme.family.name),
      overrides: fakes.overrides,
      surfaceSize: const Size(432, 860),
    );
    await tester.pumpAndSettle();
    _jumpCategoryScroll(tester, 600);
    await tester.pumpAndSettle();
    const key = ValueKey('category-word-motion-word-0');
    final transform = tester.widget<Transform>(find.byKey(key));
    final before = transform.transform.storage;

    await tester.drag(find.byKey(key), const Offset(0, -260));
    await tester.pumpAndSettle();

    final after = tester.widget<Transform>(find.byKey(key)).transform.storage;
    expect(after, isNot(equals(before)));
  });

  testWidgets('idle cards have measurable depth and overlap after layout', (
    tester,
  ) async {
    final theme = seedThemes.first;
    final template = seedWordsWithThemes.firstWhere(
      (word) => word.themeIds.contains(theme.id),
    );
    final fakes = LearningFakes(
      themes: seedThemes,
      words: [
        for (var index = 0; index < 20; index++)
          template.copyWith(
            id: 'idle-word-$index',
            slug: 'idle-word-$index',
            lemma: 'idle-$index',
            explanation: 'A concise meaning.',
            exampleSentence: 'A short example.',
            usageTip: null,
            themeIds: [theme.id],
          ),
      ],
    );
    addTearDown(fakes.dispose);
    await pumpRoutedPage(
      tester,
      location: '/category',
      page: CategoryCatalogPage(familySlug: theme.family.name),
      overrides: fakes.overrides,
      surfaceSize: const Size(432, 860),
    );
    await tester.pumpAndSettle();

    const firstTransformKey = ValueKey('category-word-idle-word-0');
    final firstTransform = tester.widget<Transform>(
      find.byKey(firstTransformKey),
    );
    expect(
      firstTransform.transform.storage,
      isNot(const [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
    );

    _jumpCategoryScroll(tester, 400);
    await tester.pumpAndSettle();

    Rect cardRect(String lemma) => tester.getRect(
      find.descendant(
        of: find.byKey(ValueKey('category-word-$lemma')),
        matching: find.byType(FluiCard),
      ),
    );

    final firstRect = cardRect('idle-word-0');
    final secondRect = cardRect('idle-word-1');
    expect(
      firstRect.overlaps(secondRect),
      isTrue,
      reason: 'first=$firstRect second=$secondRect',
    );
  });

  testWidgets('a newly lazy-mounted settled card receives its depth', (
    tester,
  ) async {
    final theme = seedThemes.first;
    final template = seedWordsWithThemes.firstWhere(
      (word) => word.themeIds.contains(theme.id),
    );
    final fakes = LearningFakes(
      themes: seedThemes,
      words: [
        for (var index = 0; index < 20; index++)
          template.copyWith(
            id: 'settled-word-$index',
            slug: 'settled-word-$index',
            lemma: 'settled-$index',
            themeIds: [theme.id],
          ),
      ],
    );
    addTearDown(fakes.dispose);
    await pumpRoutedPage(
      tester,
      location: '/category',
      page: CategoryCatalogPage(familySlug: theme.family.name),
      overrides: fakes.overrides,
      surfaceSize: const Size(432, 860),
    );
    await tester.pumpAndSettle();
    _jumpCategoryScroll(tester, null);
    await tester.pumpAndSettle();

    const key = ValueKey<String>('category-word-settled-word-19');
    expect(find.byKey(key), findsOneWidget);
    final transform = tester.widget<Transform>(find.byKey(key));
    expect(
      transform.transform.storage,
      isNot(const [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
    );
  });

  testWidgets('reduced motion keeps category word cards spatially stable', (
    tester,
  ) async {
    final theme = seedThemes.first;
    final template = seedWordsWithThemes.firstWhere(
      (word) => word.themeIds.contains(theme.id),
    );
    final fakes = LearningFakes(
      themes: seedThemes,
      words: [template.copyWith(id: 'reduced-word', slug: 'reduced-word')],
    );
    addTearDown(fakes.dispose);
    await pumpRoutedPage(
      tester,
      location: '/category',
      page: CategoryCatalogPage(familySlug: theme.family.name),
      overrides: fakes.overrides,
      surfaceSize: const Size(432, 860),
    );
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    await tester.pumpAndSettle();
    _jumpCategoryScroll(tester, null);
    await tester.pumpAndSettle();

    final transform = tester.widget<Transform>(
      find.byKey(const ValueKey<String>('category-word-reduced-word')),
    );
    expect(transform.transform.storage, const [
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
    ]);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets(
    'word cards wrap without overflow at narrow widths and 1.3x text',
    (tester) async {
      final theme = seedThemes.first;
      final template = seedWordsWithThemes.firstWhere(
        (word) => word.themeIds.contains(theme.id),
      );
      final fakes = LearningFakes(
        themes: seedThemes,
        words: [
          template.copyWith(
            id: 'responsive-word',
            slug: 'responsive-word',
            lemma: 'responsive-word',
          ),
        ],
      );
      addTearDown(fakes.dispose);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      for (final width in [320.0, 360.0, 432.0]) {
        await pumpRoutedPage(
          tester,
          location: '/category',
          page: CategoryCatalogPage(familySlug: theme.family.name),
          overrides: fakes.overrides,
          surfaceSize: Size(width, 860),
        );
        await tester.pumpAndSettle();
        _jumpCategoryScroll(tester, null);
        await tester.pumpAndSettle();
        expect(find.text('responsive-word'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

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
      arrange: (harness) async {
        await harness.planToday();
        await _completeDiagnosis(harness);
      },
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
        await _completeDiagnosis(harness);
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

String _partOfSpeechLabel(PartOfSpeech partOfSpeech) => switch (partOfSpeech) {
  PartOfSpeech.adjetivo => 'Adjetivo',
  PartOfSpeech.adverbio => 'Adverbio',
  PartOfSpeech.conector => 'Conector',
  PartOfSpeech.sustantivo => 'Sustantivo',
  PartOfSpeech.verbo => 'Verbo',
};

String _registerLabel(WordRegister register) => switch (register) {
  WordRegister.neutral => 'Registro neutro',
  WordRegister.culto => 'Registro culto',
  WordRegister.coloquial => 'Registro coloquial',
};

void _jumpCategoryScroll(WidgetTester tester, double? offset) {
  final scrollable = find.descendant(
    of: find.byType(CustomScrollView),
    matching: find.byType(Scrollable),
  );
  final position = tester.state<ScrollableState>(scrollable).position;
  position.jumpTo(offset ?? position.maxScrollExtent);
}
