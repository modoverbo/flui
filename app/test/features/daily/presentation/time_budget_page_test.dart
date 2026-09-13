import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:flui/features/daily/presentation/time_budget_page.dart';
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

  testWidgets('fits at 130 % text size on a phone', (tester) async {
    scaleText(tester, 1.3);
    await pumpPage(tester);

    expect(tester.takeException(), isNull);
  });
}
