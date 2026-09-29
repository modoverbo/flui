import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_theme_colors.dart';
import 'package:flui/features/reading/presentation/widgets/readings_carousel.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';
import 'package:flui/features/vocabulary/presentation/providers/my_words.dart';
import 'package:flui/features/vocabulary/presentation/providers/vocabulary_providers.dart';
import 'package:flui/features/vocabulary/presentation/word_detail_page.dart';
import 'package:flui/features/vocabulary/presentation/words_page.dart';
import 'package:flui/shared/widgets/choice_chips.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../helpers/learning_builders.dart';
import '../../../helpers/learning_fakes.dart';
import '../../../helpers/pump_router.dart';
import '../../../helpers/reduce_motion.dart';

void main() {
  late LearningFakes fakes;
  final perspicaz = seedWord('perspicaz');
  final plantear = seedWord('plantear');
  final matizar = seedWord('matizar');

  setUp(() async {
    fakes = LearningFakes();
    await fakes.progress.saveProgress(
      buildProgress(
        wordId: perspicaz.id,
        state: WordState.tuya,
        introducedOn: day(1),
        nextDueOn: day(30),
      ),
    );
    await fakes.progress.saveProgress(
      buildProgress(
        wordId: plantear.id,
        introducedOn: day(5),
        nextDueOn: day(13),
      ),
    );
    await fakes.progress.saveProgress(
      buildProgress(
        wordId: matizar.id,
        state: WordState.nueva,
        introducedOn: day(12),
        nextDueOn: day(14),
      ),
    );
  });

  tearDown(() => fakes.dispose());

  Future<void> pump(
    WidgetTester tester, {
    required String location,
    required Widget page,
    List<String> otherRoutes = const [],
  }) async {
    reduceMotion(tester);
    await pumpRoutedPage(
      tester,
      location: location,
      page: page,
      otherRoutes: otherRoutes,
      overrides: fakes.overrides,
      surfaceSize: const Size(400, 1400),
    );
    await tester.pumpAndSettle();
  }

  group('Palabras', () {
    testWidgets('lists the repertoire with state chips and filters it', (
      tester,
    ) async {
      await pump(
        tester,
        location: AppRoutes.words,
        page: const WordsPage(),
        otherRoutes: [AppRoutes.wordDetail(plantear.id)],
      );

      for (final lemma in ['perspicaz', 'plantear', 'matizar']) {
        expect(find.text(lemma), findsOneWidget);
      }
      expect(find.text('elocuente'), findsNothing);
      // The filter chip keeps sentence case; the state chip is set in caps.
      expect(find.text('Tuya'), findsOneWidget);
      expect(find.text('TUYA'), findsOneWidget);
      // Filters are editorial chips, never Material's native ChoiceChip.
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.widgetWithText(FluiChoiceChip, 'Tuya'), findsOneWidget);

      await tester.tap(find.widgetWithText(FluiChoiceChip, 'Tuya'));
      await tester.pumpAndSettle();
      expect(find.text('perspicaz'), findsOneWidget);
      expect(find.text('plantear'), findsNothing);

      await tester.tap(find.widgetWithText(FluiChoiceChip, 'Practica'));
      await tester.pumpAndSettle();
      expect(find.text('plantear'), findsOneWidget);
      expect(find.text('perspicaz'), findsNothing);

      await tester.tap(find.text('plantear'));
      await tester.pumpAndSettle();
      expect(
        find.text('route:${AppRoutes.wordDetail(plantear.id)}'),
        findsOneWidget,
      );
    });

    testWidgets('each repertoire card carries its theme accent', (
      tester,
    ) async {
      await pump(tester, location: AppRoutes.words, page: const WordsPage());

      // «plantear» uses the published «reuniones» theme. The surface stays
      // paper-white while a compact marker carries that theme's accent.
      final card = tester.widget<Material>(
        find
            .ancestor(
              of: find.text('plantear'),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(card.color, FluiColors.surface);
      expect(
        find.descendant(
          of: find
              .ancestor(
                of: find.text('plantear'),
                matching: find.byType(Material),
              )
              .first,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).color ==
                    FluiThemeColors.resolve('reuniones').surface,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('filters by theme, and only by themes it has words in', (
      tester,
    ) async {
      await pump(tester, location: AppRoutes.words, page: const WordsPage());

      expect(find.text('Todos los temas'), findsOneWidget);
      // «perspicaz», «plantear» and «matizar» all carry "Reuniones".
      expect(find.widgetWithText(FluiChoiceChip, 'Reuniones'), findsOneWidget);
      // No word of the repertoire belongs to these, so no dead chip.
      expect(find.widgetWithText(FluiChoiceChip, 'Entrevistas'), findsNothing);
      expect(find.widgetWithText(FluiChoiceChip, 'Negociación'), findsNothing);

      await tester.tap(
        find.widgetWithText(FluiChoiceChip, 'Reconocer a otros'),
      );
      await tester.pumpAndSettle();
      expect(find.text('perspicaz'), findsOneWidget);
      expect(find.text('plantear'), findsNothing);
      expect(find.text('matizar'), findsNothing);
    });

    testWidgets('the two filters combine, and say so when nothing is left', (
      tester,
    ) async {
      await pump(tester, location: AppRoutes.words, page: const WordsPage());

      await tester.tap(
        find.widgetWithText(FluiChoiceChip, 'Reconocer a otros'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FluiChoiceChip, 'Practica'));
      await tester.pumpAndSettle();

      expect(
        find.text('No hay palabras de este tema todavía.'),
        findsOneWidget,
      );
    });

    testWidgets('empty before the first word', (tester) async {
      fakes = LearningFakes();
      await pump(tester, location: AppRoutes.words, page: const WordsPage());

      expect(find.text('Tu repertorio empieza hoy.'), findsOneWidget);
      expect(find.text('Todos los temas'), findsNothing);
    });

    testWidgets(
      'renders without overflow at 1.3x text scale on a 360px phone',
      (tester) async {
        scaleText(tester, 1.3);
        reduceMotion(tester);
        await pumpRoutedPage(
          tester,
          location: AppRoutes.words,
          page: const WordsPage(),
          overrides: fakes.overrides,
          surfaceSize: const Size(360, 900),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('renders the repertoire across a wide viewport', (
      tester,
    ) async {
      reduceMotion(tester);
      await pumpRoutedPage(
        tester,
        location: AppRoutes.words,
        page: const WordsPage(),
        overrides: fakes.overrides,
        surfaceSize: const Size(1280, 900),
      );
      await tester.pumpAndSettle();

      expect(find.text('perspicaz'), findsOneWidget);
      expect(find.text('plantear'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('word detail', () {
    testWidgets('a due word offers "Practicar ahora"', (tester) async {
      await pump(
        tester,
        location: AppRoutes.wordDetail(plantear.id),
        page: WordDetailPage(wordId: plantear.id),
        otherRoutes: const [AppRoutes.session],
      );

      expect(find.text('plantear'), findsOneWidget);
      // The hero: the word itself, tinted by its own resolved theme colour.
      expect(find.byKey(const Key('wordHero')), findsOneWidget);
      final hero = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byKey(const Key('wordHero')),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = hero.decoration as BoxDecoration;
      expect(decoration.color, FluiThemeColors.resolve('reuniones').tint);
      expect(find.text('ASÍ SE USA'), findsOneWidget);
      expect(find.text('REEMPLAZA'), findsWidgets);
      expect(find.text('CUÁNDO NO USARLA'), findsOneWidget);
      expect(find.text('PRACTICA'), findsOneWidget);

      await tester.ensureVisible(find.text('Practicar ahora'));
      await tester.tap(find.text('Practicar ahora'));
      await tester.pumpAndSettle();
      expect(find.text('route:${AppRoutes.session}'), findsOneWidget);
    });

    testWidgets('a word not due shows the next review date', (tester) async {
      await pump(
        tester,
        location: AppRoutes.wordDetail(perspicaz.id),
        page: WordDetailPage(wordId: perspicaz.id),
      );

      expect(find.text('Practicar ahora'), findsNothing);
      expect(find.text('Próximo repaso: 30 de septiembre'), findsOneWidget);
    });

    testWidgets('a published word without progress still shows its detail', (
      tester,
    ) async {
      final publishedWord = seedWord('elocuente');
      await pump(
        tester,
        location: AppRoutes.wordDetail(publishedWord.id),
        page: WordDetailPage(wordId: publishedWord.id),
      );

      expect(find.text('elocuente'), findsOneWidget);
      expect(find.text('No encontramos esta palabra.'), findsNothing);
      expect(find.text('EL CAMINO DE ESTA PALABRA'), findsNothing);
      expect(find.text('Practicar ahora'), findsNothing);
    });

    testWidgets('progress errors do not hide published word content', (
      tester,
    ) async {
      final publishedWord = seedWord('elocuente');
      reduceMotion(tester);
      await pumpRoutedPage(
        tester,
        location: AppRoutes.wordDetail(publishedWord.id),
        page: WordDetailPage(wordId: publishedWord.id),
        overrides: [
          ...fakes.overrides,
          wordEntryProvider(publishedWord.id).overrideWith(
            (ref) async => throw StateError('progress unavailable'),
          ),
        ],
        surfaceSize: const Size(400, 1400),
      );
      await tester.pumpAndSettle();

      expect(find.text('elocuente'), findsOneWidget);
      expect(find.text('No encontramos esta palabra.'), findsNothing);
      expect(find.text('Practicar ahora'), findsNothing);
    });

    testWidgets('an unknown word says so', (tester) async {
      await pump(
        tester,
        location: AppRoutes.wordDetail('nope'),
        page: const WordDetailPage(wordId: 'nope'),
      );

      expect(find.text('No encontramos esta palabra.'), findsOneWidget);
    });

    testWidgets('catalog load errors offer retry instead of not-found', (
      tester,
    ) async {
      final publishedWord = seedWord('elocuente');
      var catalogAttempts = 0;
      reduceMotion(tester);
      await pumpRoutedPage(
        tester,
        location: AppRoutes.wordDetail(publishedWord.id),
        page: WordDetailPage(wordId: publishedWord.id),
        overrides: [
          ...fakes.overrides,
          catalogProvider.overrideWith((ref) async {
            catalogAttempts++;
            if (catalogAttempts == 1) throw StateError('catalog unavailable');
            return [publishedWord];
          }),
        ],
        surfaceSize: const Size(400, 1400),
      );
      await tester.pumpAndSettle();

      expect(find.text('No encontramos esta palabra.'), findsNothing);
      expect(find.text('Reintentar'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(catalogAttempts, 2);
      expect(find.text('elocuente'), findsOneWidget);
    });

    testWidgets('the detail shows the mastery meter and the scenes', (
      tester,
    ) async {
      await pump(
        tester,
        location: AppRoutes.wordDetail(plantear.id),
        page: WordDetailPage(wordId: plantear.id),
      );

      // "Practica" is coarse: the five rungs show the work behind it.
      expect(find.text('EL CAMINO DE ESTA PALABRA'), findsOneWidget);
      expect(find.text('Descubierta'), findsOneWidget);
      expect(find.text('Recordada sin ayuda'), findsOneWidget);
      expect(find.text('Ya es tuya'), findsOneWidget);
      expect(find.text('2 DE 5'), findsOneWidget);
      // "En contexto" is a section here now, not a tab of its own.
      expect(find.text('EN CONTEXTO'), findsOneWidget);
      expect(find.byType(ReadingsCarousel), findsOneWidget);
    });

    testWidgets(
      'renders without overflow at 1.3x text scale on a 360px phone',
      (tester) async {
        scaleText(tester, 1.3);
        reduceMotion(tester);
        await pumpRoutedPage(
          tester,
          location: AppRoutes.wordDetail(plantear.id),
          page: WordDetailPage(wordId: plantear.id),
          overrides: fakes.overrides,
          surfaceSize: const Size(360, 900),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Palabras — speakingGym ON (U17)', () {
    late LearningFakes gymFakes;

    Future<void> seedGym() async {
      gymFakes = LearningFakes(speakingGym: true);
      await gymFakes.progress.saveProgress(
        buildProgress(
          wordId: perspicaz.id,
          state: WordState.tuya,
          introducedOn: day(1),
          nextDueOn: day(30),
        ),
      );
      await gymFakes.progress.saveProgress(
        buildProgress(
          wordId: plantear.id,
          introducedOn: day(5),
          nextDueOn: day(13),
        ),
      );
      await gymFakes.progress.saveProgress(
        buildProgress(
          wordId: matizar.id,
          state: WordState.nueva,
          introducedOn: day(12),
          nextDueOn: day(14),
        ),
      );
    }

    tearDown(() => gymFakes.dispose());

    Future<void> pumpGym(
      WidgetTester tester, {
      required String location,
      required Widget page,
    }) async {
      reduceMotion(tester);
      await pumpRoutedPage(
        tester,
        location: location,
        page: page,
        otherRoutes: [AppRoutes.wordSpeak(plantear.id)],
        overrides: gymFakes.overrides,
        surfaceSize: const Size(400, 1400),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      "today's due word surfaces at the top, no in-screen record button",
      (tester) async {
        await seedGym();
        await pumpGym(
          tester,
          location: AppRoutes.words,
          page: const WordsPage(),
        );

        expect(find.text('TUS PALABRAS DE HOY'), findsOneWidget);
        // «plantear» is due today (day 13); «matizar»/«perspicaz» are not.
        expect(
          find.descendant(
            of: find.byKey(const Key('todayWords')),
            matching: find.text('plantear'),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Grabar'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('no due word today -> no today-words section, no crash', (
      tester,
    ) async {
      gymFakes = LearningFakes(speakingGym: true);
      await pumpGym(tester, location: AppRoutes.words, page: const WordsPage());

      expect(find.text('TUS PALABRAS DE HOY'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'the word detail shows its cloze exercise alongside catalog info, '
      'with a mic hint instead of a record button',
      (tester) async {
        await seedGym();
        await pumpGym(
          tester,
          location: AppRoutes.wordDetail(plantear.id),
          page: WordDetailPage(wordId: plantear.id),
        );

        expect(find.text('PRACTICA ESTA PALABRA'), findsOneWidget);
        expect(find.text(plantear.exercises.first.explanation), findsOneWidget);
        expect(
          find.text('Toca el micrófono para responder en voz alta.'),
          findsOneWidget,
        );
        expect(find.textContaining('Grabar'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
