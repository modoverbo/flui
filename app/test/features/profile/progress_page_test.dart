import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/config/feature_flags.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/theme/contrast.dart';
import 'package:flui/core/theme/flui_color_rules.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/features/diagnosis/data/fake_skill_profile_repository.dart';
import 'package:flui/features/diagnosis/presentation/providers/diagnosis_providers.dart';
import 'package:flui/features/profile/presentation/progress_page.dart';
import 'package:flui/features/subscription/data/fake_subscription_repository.dart';
import 'package:flui/features/subscription/domain/access_status.dart';
import 'package:flui/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:flui/features/training/data/fake_challenge_repository.dart';
import 'package:flui/features/training/data/fake_speaking_attempt_repository.dart';
import 'package:flui/features/training/domain/attempt_kind.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/challenge.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/speaking_attempt.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:flui/features/training/domain/voice_metrics.dart';
import 'package:flui/features/training/presentation/providers/training_providers.dart';
import 'package:flui/features/vocabulary/domain/exercises/exercise_attempt.dart';
import 'package:flui/features/vocabulary/domain/grade.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';
import 'package:flutter_riverpod/misc.dart';
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

    expect(find.text('TU SEMANA'), findsOneWidget);
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

    expect(find.text('PALABRAS TUYAS'), findsOneWidget);
    expect(find.text('EN PRÁCTICA'), findsOneWidget);
    expect(find.text('PRECISIÓN'), findsOneWidget);
    expect(find.text('DÍAS ACTIVOS'), findsOneWidget);
    expect(find.text('100 %'), findsOneWidget);
    expect(find.text('Primera palabra'), findsOneWidget);
    expect(find.text('Completado'), findsNWidgets(3));
    // The catalog now holds more words than the repertoire target, so the
    // achievement asks for the full 10 instead of shrinking to the catalog.
    expect(find.text('10 palabras en tu repertorio'), findsOneWidget);
    expect(find.text('2 de 10'), findsOneWidget);
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

  testWidgets('renders across a wide viewport', (tester) async {
    reduceMotion(tester);
    await tester.pumpFlui(
      const ProgressPage(),
      overrides: [
        ...fakes.overrides,
        subscriptionRepositoryProvider.overrideWithValue(subscriptions),
      ],
      surfaceSize: const Size(1280, 900),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tu progreso'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the light editorial surface with readable text', (
    tester,
  ) async {
    await answeredOn(16);
    await pumpPage(tester);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
    expect(scaffold.backgroundColor, FluiColors.paper);
    expect(
      contrastRatio(FluiColors.ink, FluiColors.paper),
      greaterThanOrEqualTo(FluiColorRules.aaText),
    );
    expect(
      contrastRatio(FluiColors.gray, FluiColors.paper),
      greaterThanOrEqualTo(FluiColorRules.aaText),
    );
    expect(
      tester
          .widget<Material>(
            find
                .ancestor(
                  of: find.text('1 día seguido'),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color,
      FluiColors.aqua,
    );
  });

  testWidgets('honours reduced motion for the week dots', (tester) async {
    for (final d in [13, 16]) {
      await answeredOn(d);
    }
    await tester.pumpFlui(
      const ProgressPage(),
      overrides: [
        ...fakes.overrides,
        subscriptionRepositoryProvider.overrideWithValue(subscriptions),
      ],
      surfaceSize: const Size(400, 2400),
    );
    await tester.pump();

    final dots = tester.widgetList<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    for (final dot in dots) {
      expect(dot.duration, Duration.zero);
    }
    expect(tester.takeException(), isNull);
  });

  group('Diagnosis paused-retake entry (U14c)', () {
    const metrics = VoiceMetrics(
      longPauses: 0,
      usefulPauses: 0,
      fillerCount: 0,
    );

    Challenge diagnosisChallenge({required String id, required int slot}) =>
        Challenge(
          id: id,
          slug: id,
          purpose: ChallengePurpose.diagnosis,
          skill: Skill.thinking,
          difficulty: 1,
          prompt: 'Prompt $id',
          focus: 'Focus $id',
          focusBehaviors: const <BehaviorCode>[],
          transferPrompts: const <String>[],
          targetDuration: const Duration(seconds: 30),
          sortOrder: 1,
          diagnosisSlot: slot,
        );

    Future<List<Override>> diagnosisOverrides({
      required List<SpeakingAttempt> seededAttempts,
    }) async {
      final speakingAttempts = FakeSpeakingAttemptRepository(
        currentUserId: () => fakes.auth.currentUser?.id,
      );
      for (final attempt in seededAttempts) {
        await speakingAttempts.insert(attempt);
      }
      return [
        speakingGymEnabledProvider.overrideWithValue(true),
        challengeRepositoryProvider.overrideWithValue(
          FakeChallengeRepository(
            challenges: [
              diagnosisChallenge(id: 'c1', slot: 1),
              diagnosisChallenge(id: 'c2', slot: 2),
              diagnosisChallenge(id: 'c3', slot: 3),
            ],
          ),
        ),
        speakingAttemptRepositoryProvider.overrideWithValue(speakingAttempts),
        skillProfileRepositoryProvider.overrideWithValue(
          FakeSkillProfileRepository(
            currentUserId: () => fakes.auth.currentUser?.id,
          ),
        ),
      ];
    }

    testWidgets('flag on, no open diagnosis session: the entry stays hidden', (
      tester,
    ) async {
      await tester.pumpFlui(
        const ProgressPage(),
        overrides: [
          ...fakes.overrides,
          subscriptionRepositoryProvider.overrideWithValue(subscriptions),
          ...await diagnosisOverrides(seededAttempts: const []),
        ],
        surfaceSize: const Size(400, 2400),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10nEs.progressDiagnosisResumeAction), findsNothing);
    });

    testWidgets(
      'flag on, an open (paused) retake session exists: the entry shows',
      (tester) async {
        await tester.pumpFlui(
          const ProgressPage(),
          overrides: [
            ...fakes.overrides,
            subscriptionRepositoryProvider.overrideWithValue(subscriptions),
            ...await diagnosisOverrides(
              seededAttempts: [
                SpeakingAttempt(
                  id: 'a1',
                  sessionId: 'retake-session',
                  context: TrainingContext.diagnosis,
                  kind: AttemptKind.first,
                  localDate: LocalDate(2026, 9, 14),
                  transcript: 'Respuesta de la reevaluación.',
                  duration: const Duration(seconds: 20),
                  metrics: metrics,
                  audio: const AudioRetention.none(),
                  challengeId: 'c1',
                ),
              ],
            ),
          ],
          surfaceSize: const Size(400, 2400),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10nEs.progressDiagnosisResumeTitle), findsOneWidget);
        expect(find.text(l10nEs.progressDiagnosisResumeAction), findsOneWidget);
      },
    );
  });
}
