import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:flui/features/daily/presentation/category_artwork.dart';
import 'package:flui/features/daily/presentation/today_page.dart';
import 'package:flui/features/vocabulary/data/fake/seed_content.dart';
import 'package:flui/features/vocabulary/domain/word_progress.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../helpers/learning_builders.dart';
import '../../../helpers/learning_fakes.dart';
import '../../../helpers/pump_router.dart';
import '../../../helpers/reduce_motion.dart';

void main() {
  late LearningFakes fakes;
  final perspicaz = seedWord('perspicaz');

  setUp(() => fakes = LearningFakes());
  tearDown(() => fakes.dispose());

  Future<void> pumpPage(
    WidgetTester tester, {
    bool reduced = true,
    Size surfaceSize = const Size(400, 1400),
    double textScale = 1,
  }) async {
    if (reduced) {
      reduceMotion(tester);
    } else {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures();
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }
    if (textScale != 1) scaleText(tester, textScale);
    await pumpRoutedPage(
      tester,
      location: AppRoutes.today,
      page: const TodayPage(),
      otherRoutes: [
        AppRoutes.session,
        AppRoutes.timeBudget,
        AppRoutes.speakingChallenge,
        AppRoutes.categoryCatalog('trabajo'),
      ],
      overrides: fakes.overrides,
      surfaceSize: surfaceSize,
    );
    await tester.pumpAndSettle();
  }

  Future<void> plan({
    int minutes = 10,
    List<String> newWords = const [],
    List<String> reviews = const [],
    String? themeId,
  }) => fakes.sessions.saveSession(
    DailySession(
      localDate: day(13),
      minutes: minutes,
      plannedWordIds: newWords,
      reviewWordIds: reviews,
      themeId: themeId,
    ),
  );

  testWidgets('a planned day: greeting, session, stats and the word', (
    tester,
  ) async {
    await plan(newWords: [perspicaz.id], reviews: ['missing']);
    await pumpPage(tester);

    expect(find.text('Hola, Ana'), findsOneWidget);
    // The one action of the day is docked, with the budget under it.
    expect(find.text('10 minutos'), findsOneWidget);
    // Nothing to count on day one, so no stat renders at all.
    expect(find.text('PALABRAS TUYAS'), findsNothing);
    expect(find.text('EN PRÁCTICA'), findsNothing);
    expect(find.text('PRECISIÓN'), findsNothing);
    expect(find.text('0'), findsNothing);
    expect(find.text('—'), findsNothing);
    expect(find.text('Camino a tu primera palabra tuya.'), findsOneWidget);
    // The primary action: today's word, on the front card of the stack.
    expect(find.text('TU PALABRA DE HOY'), findsOneWidget);
    expect(find.text('perspicaz'), findsOneWidget);
    expect(find.text('TU RACHA'), findsOneWidget);
    expect(find.text('Cambiar tiempo'), findsOneWidget);

    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();
    expect(find.text('route:${AppRoutes.session}'), findsOneWidget);
  });

  testWidgets('Hoy shows five directly accessible category destinations', (
    tester,
  ) async {
    await pumpPage(tester);

    for (final label in ['En el trabajo']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byType(CategoryArtwork), findsWidgets);
    for (final label in [
      'Con la gente',
      'Delante de gente',
      'Decirlo exacto',
      'Lo que cuesta decir',
    ]) {
      await tester.tap(find.byTooltip('Categoría siguiente'));
      await tester.pumpAndSettle();
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Entrena tu voz'), findsOneWidget);
    expect(find.text('Explorar temas'), findsNothing);
    expect(find.byTooltip('Categoría anterior'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
    expect(
      tester
          .widget<AnimatedContainer>(
            find.byKey(const ValueKey('category-card-emocion')),
          )
          .duration,
      Duration.zero,
    );
  });

  testWidgets('the front category exposes three distinct colored back layers', (
    tester,
  ) async {
    await pumpPage(tester);

    final backColors = <Color>{};
    for (var layer = 0; layer < 3; layer++) {
      final back = find.byKey(ValueKey('category-card-back-0-$layer'));
      expect(back, findsOneWidget);
      final decoration = tester.widget<DecoratedBox>(back).decoration;
      expect(decoration, isA<BoxDecoration>());
      backColors.add((decoration as BoxDecoration).color!);
    }

    expect(backColors, hasLength(3));
  });

  testWidgets('arrow navigation promotes the next card with depth motion', (
    tester,
  ) async {
    await pumpPage(tester, reduced: false);

    final next = find.byTooltip('Categoría siguiente');
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final during = tester
        .widget<Transform>(
          find.byKey(const ValueKey('category-card-transform-1')),
        )
        .transform;

    expect(during.getTranslation().y, greaterThan(12));
    expect(during.getTranslation().x, lessThan(-40));
    expect(during.entry(0, 0).abs(), lessThan(0.9));
    expect(find.text('En el trabajo'), findsOneWidget);
  });

  for (final width in [320.0, 360.0, 432.0]) {
    testWidgets('the layered deck fits ${width.toInt()}px at 1.3x text', (
      tester,
    ) async {
      await pumpPage(tester, surfaceSize: Size(width, 1400), textScale: 1.3);

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('category-card-back-0-2')),
        findsOneWidget,
      );
    });
  }

  testWidgets('reduced motion advances to the next category immediately', (
    tester,
  ) async {
    await pumpPage(tester);
    final next = find.byTooltip('Categoría siguiente');
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pump();

    expect(find.text('Con la gente'), findsOneWidget);
  });

  testWidgets('activating a category opens its catalog directly', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('En el trabajo'));
    await tester.tap(find.text('En el trabajo'));
    await tester.pumpAndSettle();

    expect(
      find.text('route:${AppRoutes.categoryCatalog('trabajo')}'),
      findsOneWidget,
    );
  });

  testWidgets('swiping the deck brings the next family to the front', (
    tester,
  ) async {
    await pumpPage(tester, reduced: false);
    final deck = find.byKey(const ValueKey('category-deck'));
    await tester.timedDrag(
      deck,
      const Offset(-120, 0),
      const Duration(milliseconds: 120),
    );
    await tester.pump(const Duration(milliseconds: 40));
    final incoming = tester
        .widget<Transform>(
          find.byKey(const ValueKey('category-card-transform-1')),
        )
        .transform;
    expect(incoming.getTranslation().y, greaterThan(12));
    expect(incoming.getTranslation().x, lessThan(-40));
    expect(incoming.entry(0, 0).abs(), lessThan(0.9));
    await tester.pumpAndSettle();

    expect(find.text('Con la gente'), findsOneWidget);
  });

  testWidgets('Hoy opens the oral workout without replacing vocabulary', (
    tester,
  ) async {
    await plan(newWords: [perspicaz.id]);
    await pumpPage(tester);

    expect(find.text('Entrena tu voz'), findsOneWidget);
    expect(find.text('Pausa de poder · 45 s'), findsOneWidget);
    expect(find.text('TU PALABRA DE HOY'), findsOneWidget);

    await tester.tap(find.text('Entrena tu voz'));
    await tester.pumpAndSettle();
    expect(find.text('route:${AppRoutes.speakingChallenge}'), findsOneWidget);
  });

  testWidgets('a started session offers to continue', (tester) async {
    await plan(newWords: [perspicaz.id]);
    await fakes.progress.saveProgress(
      WordProgress.introduced(wordId: perspicaz.id, today: day(13)),
    );
    await pumpPage(tester);

    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Cambiar tiempo'), findsNothing);
  });

  testWidgets('a completed day says so without guilt', (tester) async {
    await plan(newWords: [perspicaz.id]);
    await fakes.sessions.completeSession(
      localDate: day(13),
      completedAt: DateTime(2026, 9, 13, 9),
    );
    await pumpPage(tester);

    expect(find.text('Hoy ya sumaste. Vuelve mañana.'), findsOneWidget);
    expect(find.text('Empezar'), findsNothing);
    expect(find.text('TU PALABRA DE HOY'), findsNothing);
    expect(find.text('1 de 7 días esta semana'), findsOneWidget);
    // Done is not dressed up as a card with a number: no stack at all.
    expect(find.text('Entrena tu voz'), findsOneWidget);
  });

  testWidgets('an owned word becomes the hero number', (tester) async {
    await plan(newWords: [perspicaz.id]);
    await fakes.progress.saveProgress(
      buildProgress(
        wordId: perspicaz.id,
        state: WordState.tuya,
        introducedOn: day(1),
      ),
    );
    await pumpPage(tester);

    expect(find.text('PALABRAS TUYAS'), findsOneWidget);
    expect(find.text('Camino a tu primera palabra tuya.'), findsNothing);
  });

  testWidgets('an exhausted catalog says so and offers a free run', (
    tester,
  ) async {
    for (final word in seedWords) {
      await fakes.progress.saveProgress(
        buildProgress(
          wordId: word.id,
          introducedOn: day(1),
          nextDueOn: day(20),
        ),
      );
    }
    await plan(minutes: 20);
    await pumpPage(tester);

    // Not "Con 10 minutos te presento una palabra nueva": a bigger budget
    // cannot conjure words that do not exist.
    expect(
      find.text('Con 10 minutos te presento una palabra nueva.'),
      findsNothing,
    );
    expect(
      find.text(
        'Ya recorriste todas mis palabras. Estoy escribiendo las que siguen.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('repasos te esperan'), findsOneWidget);

    await tester.tap(find.text('Repaso libre'));
    await tester.pumpAndSettle();
    expect(find.text('route:${AppRoutes.session}'), findsOneWidget);
  });

  testWidgets('due reviews offer a repaso extra on Hoy', (tester) async {
    await fakes.progress.saveProgress(
      buildProgress(
        wordId: perspicaz.id,
        introducedOn: day(1),
        nextDueOn: day(13),
      ),
    );
    await plan(reviews: [perspicaz.id]);
    await pumpPage(tester);

    expect(find.text('REPASO EXTRA'), findsOneWidget);
    await tester.ensureVisible(find.text('REPASO EXTRA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('REPASO EXTRA'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('route:${AppRoutes.session}'), findsOneWidget);
  });

  testWidgets('an empty 5-minute plan suggests 10 minutes', (tester) async {
    await plan(minutes: 5);
    await pumpPage(tester);

    expect(
      find.text('Con 10 minutos te presento una palabra nueva.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cambiar a 10 minutos'));
    await tester.pumpAndSettle();
    expect(find.text('route:${AppRoutes.timeBudget}'), findsOneWidget);
  });

  testWidgets('heavy review days show "Hoy toca afianzar"', (tester) async {
    await plan(reviews: List.generate(12, (i) => 'r$i'));
    await pumpPage(tester);

    expect(find.text('Hoy toca afianzar'), findsOneWidget);
  });

  testWidgets('offers a retry when data cannot load', (tester) async {
    fakes.sessions.nextFailure = const NetworkFailure();
    await pumpPage(tester);

    expect(find.text('No pudimos cargar tu sesión.'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(
      find.text('Elige cuánto tiempo tienes y armamos tu sesión.'),
      findsOneWidget,
    );
  });

  testWidgets('fits at 130 % text size on a phone', (tester) async {
    scaleText(tester, 1.3);
    await plan(newWords: [perspicaz.id], reviews: ['x']);
    await pumpPage(tester);

    expect(tester.takeException(), isNull);
  });

  group('the theme of the day', () {
    testWidgets('is shown, with one tap to change it', (tester) async {
      await plan(
        newWords: [perspicaz.id],
        themeId: seedTheme('elogio-reconocimiento').id,
      );
      await pumpPage(tester);

      expect(find.text('TEMA DE HOY'), findsOneWidget);
      expect(find.text('Reconocer a otros'), findsOneWidget);

      await tester.tap(find.text('Cambiar tema'));
      await tester.pumpAndSettle();
      expect(find.text('route:${AppRoutes.timeBudget}'), findsOneWidget);
    });

    testWidgets('a day without a theme shows no theme row', (tester) async {
      await plan(newWords: [perspicaz.id]);
      await pumpPage(tester);

      expect(find.text('TEMA DE HOY'), findsNothing);
      expect(find.text('Cambiar tema'), findsNothing);
    });

    testWidgets('says nothing when the word came from the theme', (
      tester,
    ) async {
      await plan(
        newWords: [perspicaz.id],
        themeId: seedTheme('elogio-reconocimiento').id,
      );
      await pumpPage(tester);

      expect(find.textContaining('no me quedan palabras nuevas'), findsNothing);
    });

    testWidgets('names the neighbour that lent the word', (tester) async {
      // «perspicaz» is not tagged "Entrevistas". ThemeOutcome names the first
      // of the *word's* themes that is a neighbour of the day's theme, and
      // «perspicaz» lists "Reconocer a otros" first.
      await plan(
        newWords: [perspicaz.id],
        themeId: seedTheme('entrevistas').id,
      );
      await pumpPage(tester);

      expect(
        find.text(
          'Hoy no me quedan palabras nuevas de Entrevistas. Te traigo una de '
          'Reconocer a otros: se usa igual.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('admits when the word comes from the catalog at large', (
      tester,
    ) async {
      // «perspicaz» carries none of the themes "Decir que no" reaches.
      await plan(
        newWords: [perspicaz.id],
        themeId: seedTheme('decir-que-no').id,
      );
      await pumpPage(tester);

      expect(
        find.textContaining('Hoy no me quedan palabras nuevas de Decir que no'),
        findsOneWidget,
      );
    });

    testWidgets('an exhausted theme with words in practica is not empty', (
      tester,
    ) async {
      await fakes.progress.saveProgress(
        buildProgress(
          wordId: perspicaz.id,
          introducedOn: day(1),
          nextDueOn: day(30),
        ),
      );
      await plan(themeId: seedTheme('elogio-reconocimiento').id);
      await pumpPage(tester);

      expect(
        find.text(
          'Hoy no me quedan palabras nuevas de Reconocer a otros. Afianzamos '
          'las que ya tienes de ese tema.',
        ),
        findsOneWidget,
      );
      // Not the honest-but-wrong "come back tomorrow" of an empty day.
      expect(
        find.text('Con 10 minutos te presento una palabra nueva.'),
        findsNothing,
      );
    });
  });

  testWidgets('the streak is one dark editorial block, not a grid cell', (
    tester,
  ) async {
    await plan(newWords: [perspicaz.id]);
    await pumpPage(tester);

    // Exactly one dark block on the screen, full content width — an
    // editorial anchor, not a cell among identical ones.
    final inkBlock = find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).color == FluiColors.ink,
    );
    expect(inkBlock, findsOneWidget);
    final header = tester.getSize(find.byType(PageHeader));
    final block = tester.getSize(inkBlock);
    expect(block.width, closeTo(header.width, 1));
    expect(find.text('TU RACHA'), findsOneWidget);
  });
}
