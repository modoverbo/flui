import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:flui/features/daily/presentation/controllers/session_controller.dart';
import 'package:flui/features/daily/presentation/session_page.dart';
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

  setUp(() => fakes = LearningFakes());
  tearDown(() => fakes.dispose());

  Future<void> pumpSession(
    WidgetTester tester, {
    SessionMode mode = SessionMode.daily,
    Size size = const Size(400, 860),
  }) async {
    reduceMotion(tester);
    await pumpRoutedPage(
      tester,
      location: AppRoutes.session,
      page: SessionPage(mode: mode),
      otherRoutes: const [AppRoutes.today, AppRoutes.practice],
      overrides: fakes.overrides,
      surfaceSize: size,
    );
    await tester.pumpAndSettle();
  }

  Future<void> planNewWord() => fakes.sessions.saveSession(
    DailySession(
      localDate: day(13),
      minutes: 10,
      plannedWordIds: [perspicaz.id],
    ),
  );

  Future<void> tapVisible(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('Descubre shows the word of the day and the progress', (
    tester,
  ) async {
    await planNewWord();
    await pumpSession(tester);

    expect(find.text('Tu palabra de hoy'), findsOneWidget);
    expect(find.text('perspicaz'), findsOneWidget);
    expect(find.text('1 de 6'), findsOneWidget);
    expect(find.text('Reemplaza'), findsOneWidget);
    expect(find.text('Cuándo no usarla'), findsOneWidget);
    expect(find.text('No la confundas con'), findsOneWidget);
    expect(find.bySemanticsLabel('Sílabas: pers-pi-caz'), findsOneWidget);
    expect(find.text('Ver en contexto'), findsOneWidget);
  });

  testWidgets('closing asks first and keeps the progress', (tester) async {
    await planNewWord();
    await pumpSession(tester);

    await tester.tap(find.byTooltip('Salir de la sesión'));
    await tester.pumpAndSettle();
    expect(find.text('¿Salir por ahora?'), findsOneWidget);

    await tester.tap(find.text('Seguir aquí'));
    await tester.pumpAndSettle();
    expect(find.text('Tu palabra de hoy'), findsOneWidget);

    await tester.tap(find.byTooltip('Salir de la sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();
    expect(find.text('route:${AppRoutes.today}'), findsOneWidget);
  });

  testWidgets('a failed save shows a kind notice and retries', (tester) async {
    await planNewWord();
    await pumpSession(tester);
    fakes.progress.nextFailure = const NetworkFailure();

    await tapVisible(tester, 'Ver en contexto');

    expect(
      find.text('Sin conexión. Revisa tu internet y vuelve a intentarlo.'),
      findsOneWidget,
    );
    await tapVisible(tester, 'Reintentar');
    expect(find.text('Mira cómo suena'), findsOneWidget);
  });

  testWidgets('a review that makes the word yours celebrates it', (
    tester,
  ) async {
    await fakes.progress.saveProgress(
      buildProgress(
        wordId: plantear.id,
        nextDueOn: day(13),
        successDays: {day(2), day(6)},
        formRecallDone: true,
        productionDone: true,
        ladderStep: 2,
      ),
    );
    await pumpSession(
      tester,
      mode: SessionMode.review,
      size: const Size(400, 1400),
    );

    expect(find.text('Repaso'), findsOneWidget);
    await tapVisible(tester, 'planteó');
    await tapVisible(tester, 'Confirmar');
    await tapVisible(tester, 'Continuar');

    expect(find.text('Ya es tuya.'), findsOneWidget);
    expect(find.text('«plantear» ya es parte de cómo hablas.'), findsOneWidget);
    expect(find.text('Tu repertorio sigue firme.'), findsOneWidget);
    await tapVisible(tester, 'Volver a Hoy');
    expect(find.text('route:${AppRoutes.practice}'), findsOneWidget);
  });

  testWidgets('steps fit at 130 % text size on a phone', (tester) async {
    scaleText(tester, 1.3);
    await planNewWord();
    await pumpSession(tester);
    expect(tester.takeException(), isNull);

    await tapVisible(tester, 'Ver en contexto');
    expect(tester.takeException(), isNull);
    await tapVisible(tester, 'Continuar');
    expect(find.text('Encuentra la palabra que encaja'), findsOneWidget);
    await tapVisible(tester, 'suspicaz');
    await tapVisible(tester, 'Confirmar');
    expect(find.text('Casi.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
