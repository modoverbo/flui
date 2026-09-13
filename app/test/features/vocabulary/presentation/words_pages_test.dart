import 'package:flui/app/router/app_routes.dart';
import 'package:flui/features/exercises/presentation/practice_page.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';
import 'package:flui/features/vocabulary/presentation/word_detail_page.dart';
import 'package:flui/features/vocabulary/presentation/words_page.dart';
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
      // Chips: filter labels plus one state chip per word.
      expect(find.text('Tuya'), findsNWidgets(2));

      await tester.tap(find.widgetWithText(ChoiceChip, 'Tuya'));
      await tester.pumpAndSettle();
      expect(find.text('perspicaz'), findsOneWidget);
      expect(find.text('plantear'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Practica'));
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

    testWidgets('empty before the first word', (tester) async {
      fakes = LearningFakes();
      await pump(tester, location: AppRoutes.words, page: const WordsPage());

      expect(find.text('Tu repertorio empieza hoy.'), findsOneWidget);
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
      expect(find.text('Reemplaza'), findsOneWidget);
      expect(find.text('Cuándo no usarla'), findsOneWidget);
      expect(find.text('Practica'), findsOneWidget);

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

    testWidgets('an unknown word says so', (tester) async {
      await pump(
        tester,
        location: AppRoutes.wordDetail('nope'),
        page: const WordDetailPage(wordId: 'nope'),
      );

      expect(find.text('No encontramos esta palabra.'), findsOneWidget);
    });
  });

  group('Practica', () {
    testWidgets('due reviews start a review-only session', (tester) async {
      await pump(
        tester,
        location: AppRoutes.practice,
        page: const PracticePage(),
        otherRoutes: const [AppRoutes.session],
      );

      expect(find.text('1 palabra para afianzar hoy'), findsOneWidget);
      await tester.tap(find.text('Empezar repaso'));
      await tester.pumpAndSettle();
      expect(find.text('route:${AppRoutes.session}'), findsOneWidget);
    });

    testWidgets('all caught up shows the next date', (tester) async {
      await fakes.progress.saveProgress(
        buildProgress(
          wordId: plantear.id,
          introducedOn: day(5),
          nextDueOn: day(15),
        ),
      );
      await pump(
        tester,
        location: AppRoutes.practice,
        page: const PracticePage(),
      );

      expect(find.text('Todo al día. Vuelve mañana.'), findsOneWidget);
      expect(find.text('Tu próximo repaso: 14 de septiembre'), findsOneWidget);
    });
  });
}
