import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:flui/features/daily/presentation/time_budget_page.dart';
import 'package:flui/shared/widgets/flui_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../helpers/learning_builders.dart';
import '../../../helpers/learning_fakes.dart';
import '../../../helpers/pump_router.dart';
import '../../../helpers/reduce_motion.dart';

void main() {
  late LearningFakes fakes;

  setUp(() => fakes = LearningFakes());
  tearDown(() => fakes.dispose());

  Future<void> pumpPage(WidgetTester tester) async {
    reduceMotion(tester);
    await pumpRoutedPage(
      tester,
      location: AppRoutes.timeBudget,
      page: const TimeBudgetPage(),
      otherRoutes: const [AppRoutes.today],
      overrides: fakes.overrides,
      surfaceSize: const Size(400, 900),
    );
    await tester.pumpAndSettle();
  }

  bool isSelected(WidgetTester tester, String minutes) => tester
      .getSemantics(find.bySemanticsLabel(RegExp('^$minutes minutos')))
      .flagsCollection
      .isSelected
      .toBoolOrNull()!;

  testWidgets('offers four budgets with a short line each', (tester) async {
    await pumpPage(tester);

    expect(find.text('¿Cuánto tiempo tienes hoy?'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('¿Cuánto tiempo tienes hoy?'),
        matching: find.byType(FluiCard),
      ),
      findsOneWidget,
    );
    for (final (minutes, line) in [
      ('5 min', 'Solo repasos'),
      ('10 min', '1 palabra nueva + repaso'),
      ('20 min', '2 palabras nuevas + repaso'),
      ('30 min', 'Hasta 3 palabras nuevas + repaso'),
    ]) {
      expect(find.text(minutes), findsOneWidget);
      expect(find.text(line), findsOneWidget);
    }
    expect(find.text('Empezar'), findsOneWidget);
  });

  testWidgets("preselects yesterday's choice", (tester) async {
    await fakes.sessions.saveSession(
      DailySession(localDate: day(12), minutes: 20),
    );
    await pumpPage(tester);

    expect(isSelected(tester, '20'), isTrue);
    expect(isSelected(tester, '10'), isFalse);
  });

  testWidgets('saves the chosen budget and goes to Hoy', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('30 min'));
    await tester.pump();
    expect(isSelected(tester, '30'), isTrue);
    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();

    final saved = (await fakes.sessions.fetchSessions()).valueOrNull!.single;
    expect(saved.minutes, 30);
    expect(saved.plannedWordIds, hasLength(3));
    expect(find.text('route:${AppRoutes.today}'), findsOneWidget);
  });

  testWidgets('shows a kind message when saving fails', (tester) async {
    await pumpPage(tester);
    fakes.content.nextFailure = const NetworkFailure();

    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();

    expect(
      find.text('Sin conexión. Revisa tu internet y vuelve a intentarlo.'),
      findsOneWidget,
    );
    expect(find.text('route:${AppRoutes.today}'), findsNothing);
  });

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('the second question of the day', () {
    testWidgets('asks for a theme with three cards, a door and a dice', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(find.text('¿Sobre qué tema?'), findsOneWidget);
      // Patall (2008): choice helps most at two to four options.
      for (final name in ['Reuniones', 'Presentaciones', 'Entrevistas']) {
        expect(find.text(name), findsOneWidget);
      }
      expect(find.text('Explorar'), findsOneWidget);
      expect(find.text('Sorpréndeme'), findsOneWidget);
    });

    testWidgets('says what a theme does and does not change', (tester) async {
      await pumpPage(tester);

      expect(
        find.text(
          'El tema elige tu palabra nueva. Tus repasos siguen su propio '
          'calendario.',
        ),
        findsOneWidget,
      );
    });

    testWidgets("preselects yesterday's theme", (tester) async {
      await fakes.sessions.saveSession(
        DailySession(
          localDate: day(12),
          minutes: 10,
          themeId: seedTheme('entrevistas').id,
        ),
      );
      await pumpPage(tester);

      expect(isThemeSelected(tester, 'Entrevistas'), isTrue);
      expect(isThemeSelected(tester, 'Reuniones'), isFalse);
    });

    testWidgets('saves the theme and picks its word', (tester) async {
      await pumpPage(tester);

      await tapText(tester, 'Entrevistas');
      await tapText(tester, 'Empezar');

      final saved = (await fakes.sessions.fetchSessions()).valueOrNull!.single;
      expect(saved.themeId, seedTheme('entrevistas').id);
      // 10 minutes buys one new word, and it comes from that theme.
      expect(saved.plannedWordIds, [seedWord('sopesar').id]);
    });

    testWidgets('changing the theme replans exactly like changing minutes', (
      tester,
    ) async {
      await pumpPage(tester);
      await tapText(tester, 'Entrevistas');
      await tapText(tester, 'Reuniones');
      await tapText(tester, 'Empezar');

      final saved = (await fakes.sessions.fetchSessions()).valueOrNull!.single;
      expect(saved.themeId, seedTheme('reuniones').id);
      expect(saved.plannedWordIds, [seedWord('perspicaz').id]);
    });

    testWidgets('"Explorar" lists every theme, grouped by family', (
      tester,
    ) async {
      await pumpPage(tester);

      await tapText(tester, 'Explorar');

      expect(find.text('Todos los temas'), findsOneWidget);
      // FluiLabel sets an eyebrow in caps; the ARB copy stays sentence case.
      expect(find.text('EN EL TRABAJO'), findsOneWidget);
      expect(find.text('LO QUE CUESTA DECIR'), findsOneWidget);
      // A theme with no content behind it is never offered.
      expect(find.text('Conectores'), findsNothing);

      await tapText(tester, 'Desacuerdos');
      expect(find.text('Todos los temas'), findsNothing);
      expect(isThemeSelected(tester, 'Desacuerdos'), isTrue);
    });

    testWidgets('"Sorpréndeme" moves off the theme already showing', (
      tester,
    ) async {
      await pumpPage(tester);
      expect(isThemeSelected(tester, 'Reuniones'), isTrue);

      await tapText(tester, 'Sorpréndeme');

      expect(isThemeSelected(tester, 'Reuniones'), isFalse);
    });

    testWidgets('asks for no theme when none is offered yet', (tester) async {
      fakes = LearningFakes(themes: const []);
      await pumpPage(tester);

      expect(
        find.text('Todavía no hay temas para elegir. Seguimos escribiendo.'),
        findsOneWidget,
      );
      await tapText(tester, 'Empezar');

      final saved = (await fakes.sessions.fetchSessions()).valueOrNull!.single;
      expect(saved.themeId, isNull);
      expect(saved.plannedWordIds, [seedWord('perspicaz').id]);
    });
  });

  testWidgets('fits at 130 % text size on a phone', (tester) async {
    scaleText(tester, 1.3);
    await pumpPage(tester);

    expect(tester.takeException(), isNull);
  });
}

/// A theme card announces itself as "{name}: {tagline}".
bool isThemeSelected(WidgetTester tester, String name) => tester
    .getSemantics(find.bySemanticsLabel(RegExp('^$name:')))
    .flagsCollection
    .isSelected
    .toBoolOrNull()!;
