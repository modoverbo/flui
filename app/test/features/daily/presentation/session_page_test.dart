import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:flui/features/daily/presentation/controllers/session_controller.dart';
import 'package:flui/features/daily/presentation/session_page.dart';
import 'package:flui/features/exercises/domain/exercise_attempt.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
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
      otherRoutes: const [AppRoutes.today],
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

    expect(find.text('TU PALABRA DE HOY'), findsOneWidget);
    expect(find.text('perspicaz'), findsOneWidget);
    expect(find.text('1 DE 7'), findsOneWidget);
    expect(find.text('REEMPLAZA'), findsWidgets);
    expect(find.text('CUÁNDO NO USARLA'), findsOneWidget);
    expect(find.text('NO LA CONFUNDAS CON'), findsOneWidget);
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
    expect(find.text('TU PALABRA DE HOY'), findsOneWidget);

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

    expect(find.text('REPASO'), findsOneWidget);
    await tapVisible(tester, 'planteó');
    await tapVisible(tester, 'Confirmar');
    await tapVisible(tester, 'Continuar');

    expect(find.text('Ya es tuya.'), findsOneWidget);
    expect(find.text('«plantear» ya es parte de cómo hablas.'), findsOneWidget);
    expect(find.text('Tu repertorio sigue firme.'), findsOneWidget);
    await tapVisible(tester, 'Volver a Hoy');
    expect(find.text('route:${AppRoutes.today}'), findsOneWidget);
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

  // The following prove that grading, hint escalation, attempt recording,
  // resume-after-reload and the frustration guard still work going through
  // the new `_SessionCardStack`/`CardStack`/`TrainingCard` composition, not
  // just the old direct step-swap path. "Grading" itself is already proven
  // above by 'a review that makes the word yours celebrates it', which now
  // runs through the same composition.

  testWidgets(
    'a wrong answer escalates to a hint and the attempt is recorded',
    (tester) async {
      await planNewWord();
      await pumpSession(tester);
      await tapVisible(tester, 'Ver en contexto');
      await tapVisible(tester, 'Continuar');

      final exercise = perspicaz.exercises.first;
      final wrong = exercise.distractors.first.text;
      final correct = exercise.correctOption.text;

      await tapVisible(tester, wrong);
      await tapVisible(tester, 'Confirmar');
      expect(find.text('Casi.'), findsOneWidget);

      await tapVisible(tester, 'Intentar de nuevo');
      await tapVisible(tester, correct);
      await tapVisible(tester, 'Confirmar');
      expect(find.text('¡Eso es!'), findsOneWidget);
      await tapVisible(tester, 'Continuar');

      final result = await fakes.attempts.fetchAttempts();
      final recorded = switch (result) {
        Ok(:final value) => value,
        Err() => const <ExerciseAttempt>[],
      };
      final attempt = recorded.singleWhere(
        (a) => a.wordId == perspicaz.id && a.exerciseId == exercise.id,
      );
      expect(attempt.attempts, 2);
      expect(attempt.revealed, isFalse);
    },
  );

  testWidgets('reloading the stack resumes past the completed steps', (
    tester,
  ) async {
    await planNewWord();
    await pumpSession(tester);
    await tapVisible(tester, 'Ver en contexto');

    // A fresh page, same persisted data: it must resume where the last
    // save left off, not restart the stack from Descubre.
    await pumpSession(tester);

    expect(find.text('Mira cómo suena'), findsOneWidget);
    expect(find.text('TU PALABRA DE HOY'), findsNothing);
  });

  testWidgets('three forced reveals switch the stack into reading mode', (
    tester,
  ) async {
    final words = [
      for (final lemma in ['plantear', 'matizar', 'sopesar', 'pertinente'])
        seedWord(lemma),
    ];
    for (final word in words) {
      await fakes.progress.saveProgress(
        buildProgress(
          wordId: word.id,
          nextDueOn: day(13),
          formRecallDone: true,
          productionDone: true,
        ),
      );
    }
    await fakes.sessions.saveSession(
      DailySession(
        localDate: day(13),
        minutes: 10,
        reviewWordIds: [for (final word in words) word.id],
      ),
    );
    await pumpSession(tester, size: const Size(400, 1400));

    Future<void> revealViaUi(Word word) async {
      final exercise = word.exercises.first;
      await tapVisible(tester, exercise.distractors[0].text);
      await tapVisible(tester, 'Confirmar');
      await tapVisible(tester, 'Intentar de nuevo');
      await tapVisible(tester, exercise.distractors[1].text);
      await tapVisible(tester, 'Confirmar');
      await tapVisible(tester, 'Intentar de nuevo');
      await tapVisible(tester, exercise.correctOption.text);
      await tapVisible(tester, 'Confirmar');
      await tapVisible(tester, 'Continuar');
    }

    for (final word in words.take(3)) {
      await revealViaUi(word);
    }

    expect(find.text('Hoy estás sembrando; mañana cosechas.'), findsOneWidget);
  });

  testWidgets('Descubre (read-only) advances on a swipe, with real motion on', (
    tester,
  ) async {
    // Deliberately does not reduce motion: swipe-to-advance only matters
    // as a real gesture when the spring-driven stack transition is
    // actually running (`docs/redesign/03-card-stack-spec.md` §2/§6).
    await planNewWord();
    await pumpRoutedPage(
      tester,
      location: AppRoutes.session,
      page: const SessionPage(),
      otherRoutes: const [AppRoutes.today],
      overrides: fakes.overrides,
      surfaceSize: const Size(400, 860),
    );
    await tester.pumpAndSettle();
    expect(find.text('TU PALABRA DE HOY'), findsOneWidget);

    await tester.fling(
      find.text('perspicaz').last,
      const Offset(-400, 0),
      1200,
    );
    await tester.pumpAndSettle();

    expect(find.text('Mira cómo suena'), findsOneWidget);
  });
}
