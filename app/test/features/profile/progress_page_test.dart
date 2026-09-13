import 'package:flui/core/clock/clock.dart';
import 'package:flui/features/exercises/domain/exercise_attempt.dart';
import 'package:flui/features/profile/presentation/progress_page.dart';
import 'package:flui/features/subscription/data/fake_subscription_repository.dart';
import 'package:flui/features/subscription/domain/access_status.dart';
import 'package:flui/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:flui/features/vocabulary/domain/grade.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/learning_builders.dart';
import '../../helpers/learning_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/reduce_motion.dart';

void main() {
  late LearningFakes fakes;
  late FakeSubscriptionRepository subscriptions;

  setUp(() {
    // Wednesday 2026-09-16.
    fakes = LearningFakes(now: DateTime(2026, 9, 16, 9));
    subscriptions =
        FakeSubscriptionRepository(
          clock: FixedClock(DateTime(2026, 9, 13)),
          currentUserId: () => fakes.auth.currentUser?.id,
        )..grantAccess(
          AccessStatus(
            hasAccess: true,
            entitlementStatus: EntitlementStatus.trialing,
            trialEndsAt: DateTime(2026, 9, 20),
          ),
        );
  });

  tearDown(() => fakes.dispose());

  Future<void> answeredOn(int dayOfMonth) => fakes.attempts.recordAttempt(
    ExerciseAttempt(
      exerciseId: 'e',
      wordId: 'w',
      attempts: 1,
      revealed: false,
      grade: Grade.good,
      localDate: day(dayOfMonth),
    ),
  );

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpFlui(
      const ProgressPage(),
      overrides: [
        ...fakes.overrides,
        subscriptionRepositoryProvider.overrideWithValue(subscriptions),
      ],
      surfaceSize: const Size(400, 2400),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the name, trial end and sign out', (tester) async {
    await pumpPage(tester);

    expect(find.text('Tu progreso'), findsOneWidget);
    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(
      find.text('Prueba gratis hasta el 20 de septiembre'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pump();
    expect(fakes.auth.currentUser, isNull);
  });

  testWidgets('week dots, days this week and the streak', (tester) async {
    for (final d in [13, 14, 16]) {
      await answeredOn(d);
    }
    await pumpPage(tester);

    expect(find.text('2 de 7 días esta semana'), findsOneWidget);
    expect(find.bySemanticsLabel('lunes: activo'), findsOneWidget);
    expect(find.bySemanticsLabel('martes: sin actividad'), findsOneWidget);
    expect(find.bySemanticsLabel('miércoles: activo'), findsOneWidget);
    expect(find.bySemanticsLabel('domingo: sin actividad'), findsOneWidget);
    expect(find.text('1 día seguido'), findsOneWidget);
  });

  testWidgets('the free repair is offered and fills the day', (tester) async {
    for (final d in [13, 14, 16]) {
      await answeredOn(d);
    }
    await pumpPage(tester);

    expect(
      find.text(
        'Recupera el 15 de septiembre sin costo: tu racha sería de 4 días.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Recuperar día'));
    await tester.pumpAndSettle();

    expect((await fakes.repairs.fetchRepairs()).valueOrNull, [day(15)]);
    expect(find.text('4 días seguidos'), findsOneWidget);
    expect(find.text('3 de 7 días esta semana'), findsOneWidget);
    expect(find.text('Esta semana ya recuperaste un día.'), findsOneWidget);
  });

  testWidgets('stats and achievements', (tester) async {
    await fakes.progress.saveProgress(
      buildProgress(wordId: 'a', state: WordState.tuya, productionDone: true),
    );
    await fakes.progress.saveProgress(buildProgress(wordId: 'b'));
    await answeredOn(16);
    await pumpPage(tester);

    expect(find.text('palabras tuyas'), findsOneWidget);
    expect(find.text('en práctica'), findsOneWidget);
    expect(find.text('100 %'), findsOneWidget);
    expect(find.text('Primera palabra'), findsOneWidget);
    expect(find.text('Completado'), findsNWidgets(3));
    // The catalog has 8 words, so the repertoire target is 8 and not a
    // permanently unreachable 10.
    expect(find.text('8 palabras en tu repertorio'), findsOneWidget);
    expect(find.text('2 de 8'), findsOneWidget);
    expect(find.text('1 de 5'), findsOneWidget);
  });

  testWidgets('fits at 130 % text size on a phone', (tester) async {
    scaleText(tester, 1.3);
    await answeredOn(16);
    await tester.pumpFlui(
      const ProgressPage(),
      overrides: [
        ...fakes.overrides,
        subscriptionRepositoryProvider.overrideWithValue(subscriptions),
      ],
      surfaceSize: const Size(400, 860),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
