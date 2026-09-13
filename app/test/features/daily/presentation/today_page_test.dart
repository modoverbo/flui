import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:flui/features/daily/presentation/today_page.dart';
import 'package:flui/features/vocabulary/data/fake/seed_content.dart';
import 'package:flui/features/vocabulary/domain/word_progress.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';
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

  Future<void> pumpPage(WidgetTester tester) async {
    reduceMotion(tester);
    await pumpRoutedPage(
      tester,
      location: AppRoutes.today,
      page: const TodayPage(),
      otherRoutes: const [AppRoutes.session, AppRoutes.timeBudget],
      overrides: fakes.overrides,
      surfaceSize: const Size(400, 900),
    );
    await tester.pumpAndSettle();
  }

  Future<void> plan({
    int minutes = 10,
    List<String> newWords = const [],
    List<String> reviews = const [],
  }) => fakes.sessions.saveSession(
    DailySession(
      localDate: day(13),
      minutes: minutes,
      plannedWordIds: newWords,
      reviewWordIds: reviews,
    ),
  );

  testWidgets('a planned day: greeting, session, stats and the word', (
    tester,
  ) async {
    await plan(newWords: [perspicaz.id], reviews: ['missing']);
    await pumpPage(tester);

    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.text('Tu sesión de hoy'), findsOneWidget);
    expect(find.text('10 minutos'), findsOneWidget);
    // No "tuya" yet, so the hero shows the work instead of a bare zero.
    expect(find.text('palabras tuyas'), findsNothing);
    expect(find.text('en práctica'), findsOneWidget);
    expect(find.text('días activos'), findsOneWidget);
    expect(find.text('Camino a tu primera palabra tuya.'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('Tu palabra de hoy'), findsOneWidget);
    expect(find.text('perspicaz'), findsOneWidget);
    expect(find.text('Nueva'), findsOneWidget);
    expect(find.text('Repasos de hoy: 1'), findsOneWidget);
    expect(find.text('Cambiar tiempo'), findsOneWidget);

    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();
    expect(find.text('route:${AppRoutes.session}'), findsOneWidget);
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
    expect(find.text('Tu palabra de hoy'), findsNothing);
    expect(find.text('1 de 7 días esta semana'), findsOneWidget);
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

    expect(find.text('palabras tuyas'), findsOneWidget);
    expect(find.text('en práctica'), findsOneWidget);
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

    expect(find.text('Repaso extra'), findsOneWidget);
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
    expect(find.text('Tu sesión de hoy'), findsNothing);
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
}
