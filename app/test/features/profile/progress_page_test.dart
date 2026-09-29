import 'dart:typed_data';

import 'package:flui/core/audio/audio_providers.dart';
import 'package:flui/core/audio/data/fake_speech_player.dart';
import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/config/feature_flags.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/theme/contrast.dart';
import 'package:flui/core/theme/flui_color_rules.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/features/diagnosis/data/fake_skill_profile_repository.dart';
import 'package:flui/features/diagnosis/domain/skill_profile_repository.dart';
import 'package:flui/features/diagnosis/presentation/providers/diagnosis_providers.dart';
import 'package:flui/features/profile/data/fake_account_deletion_repository.dart';
import 'package:flui/features/profile/presentation/progress_page.dart';
import 'package:flui/features/profile/presentation/providers/profile_providers.dart';
import 'package:flui/features/subscription/data/fake_subscription_repository.dart';
import 'package:flui/features/subscription/domain/access_status.dart';
import 'package:flui/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:flui/features/training/data/fake_attempt_audio_store.dart';
import 'package:flui/features/training/data/fake_audio_consent_repository.dart';
import 'package:flui/features/training/data/fake_challenge_repository.dart';
import 'package:flui/features/training/data/fake_speaking_attempt_repository.dart';
import 'package:flui/features/training/domain/attempt_kind.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/challenge.dart';
import 'package:flui/features/training/domain/observation.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/skill_profile.dart';
import 'package:flui/features/training/domain/speaking_attempt.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:flui/features/training/domain/voice_metrics.dart';
import 'package:flui/features/training/presentation/providers/training_providers.dart';
import 'package:flui/features/vocabulary/domain/exercises/exercise_attempt.dart';
import 'package:flui/features/vocabulary/domain/grade.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';
import 'package:flui/shared/widgets/flui_button.dart';
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

  group('PROGRESO evidence, playback, audio settings, retake (U18b)', () {
    const metrics = VoiceMetrics(
      longPauses: 0,
      usefulPauses: 0,
      fillerCount: 0,
    );
    const userId = 'user-1';

    late LearningFakes gymFakes;
    late FakeSubscriptionRepository gymSubscriptions;
    late FakeAttemptAudioStore audioStore;
    late FakeAudioConsentRepository audioConsentRepo;
    late FakeSpeechPlayer fakePlayer;

    setUp(() {
      gymFakes = LearningFakes(
        now: DateTime(2026, 9, 20, 9),
        speakingGym: true,
      );
      gymSubscriptions =
          FakeSubscriptionRepository(
            clock: gymFakes.clock,
            currentUserId: () => gymFakes.auth.currentUser?.id,
          )..grantAccess(
            AccessStatus(
              hasAccess: true,
              entitlementStatus: EntitlementStatus.trialing,
              trialEndsAt: DateTime(2026, 9, 27),
            ),
          );
      audioStore = FakeAttemptAudioStore(
        currentUserId: () => gymFakes.auth.currentUser?.id,
        // Mirrors bootstrap.dart's fake wiring: keeps the attempt repo's
        // own copy of `audio` in sync with this store (U18b).
        onAudioChanged: gymFakes.speakingAttempts.updateAudio,
      );
      audioConsentRepo = FakeAudioConsentRepository(
        currentUserId: () => gymFakes.auth.currentUser?.id,
      );
      fakePlayer = FakeSpeechPlayer();
    });

    tearDown(() => gymFakes.dispose());

    List<Override> gymOverrides() => [
      ...gymFakes.overrides,
      subscriptionRepositoryProvider.overrideWithValue(gymSubscriptions),
      attemptAudioStoreProvider.overrideWithValue(audioStore),
      audioConsentRepositoryProvider.overrideWithValue(audioConsentRepo),
      speechPlayerFactoryProvider.overrideWithValue(() => fakePlayer),
    ];

    Future<void> pumpGymPage(WidgetTester tester) async {
      await tester.pumpFlui(
        const ProgressPage(),
        overrides: gymOverrides(),
        surfaceSize: const Size(400, 4200),
      );
      await tester.pumpAndSettle();
    }

    SkillProfile diagnosisProfile() => const SkillProfile(
      topArea: SkillArea.thinking,
      secondArea: SkillArea.language,
      strengths: [BehaviorCode.preciseWord],
      evidence: [],
    );

    Future<void> seedBaseline({DateTime? diagnosedAt}) async {
      gymFakes.skillProfiles.seedProfile(
        SkillProfileRecord(
          id: 'baseline',
          kind: SkillProfileKind.baseline,
          diagnosedAt: diagnosedAt ?? DateTime(2026, 8, 2),
          profile: diagnosisProfile(),
        ),
      );
      await gymFakes.speakingAttempts.insert(
        SpeakingAttempt(
          id: 'baseline-1',
          sessionId: 'baseline',
          context: TrainingContext.diagnosis,
          kind: AttemptKind.first,
          localDate: LocalDate(2026, 8, 1),
          transcript: 'Respuesta de la evaluación inicial.',
          duration: const Duration(seconds: 20),
          metrics: metrics,
          audio: const AudioRetention.stored(
            path: '$userId/baseline-1.wav',
            mime: 'audio/wav',
          ),
          observations: const [
            Observation(
              code: BehaviorCode.mainPointLate,
              source: ObservationSource.ai,
            ),
            Observation(
              code: BehaviorCode.mainPointLate,
              source: ObservationSource.ai,
              evidence: 'Tardó en llegar a la idea principal.',
            ),
          ],
        ),
      );
      await audioStore.upload(
        attemptId: 'baseline-1',
        bytes: Uint8List.fromList([1, 2, 3]),
        mimeType: 'audio/wav',
      );
    }

    Future<void> seedMilestone() async {
      await gymFakes.speakingAttempts.insert(
        SpeakingAttempt(
          id: 'milestone-1',
          sessionId: 'daily-1',
          context: TrainingContext.daily,
          kind: AttemptKind.first,
          localDate: LocalDate(2026, 9, 14),
          transcript: 'Hablé sobre mi semana en el trabajo.',
          duration: const Duration(seconds: 25),
          metrics: metrics,
          audio: const AudioRetention.stored(
            path: '$userId/milestone-1.wav',
            mime: 'audio/wav',
          ),
          milestoneWeek: LocalDate(2026, 9, 14),
          observations: const [
            Observation(
              code: BehaviorCode.clearMainPoint,
              source: ObservationSource.ai,
            ),
          ],
        ),
      );
      await audioStore.upload(
        attemptId: 'milestone-1',
        bytes: Uint8List.fromList([4, 5, 6]),
        mimeType: 'audio/wav',
      );
    }

    testWidgets('shows labeled per-skill trends, no numbers anywhere in the '
        'evidence section', (tester) async {
      await seedBaseline();
      await seedMilestone();

      await pumpGymPage(tester);

      expect(
        find.text(l10nEs.progressEvidenceTitle.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(l10nEs.progressBeforeNowLabelIndicative),
        findsOneWidget,
      );
      // Thinking had 2 mainPointLate opportunities in the baseline window
      // and none in the (empty) recent window: net resolution -> improving.
      expect(find.text(l10nEs.progressTrendImproving), findsOneWidget);
      final evidenceSection = find.ancestor(
        of: find.text(l10nEs.progressEvidenceTitle.toUpperCase()),
        matching: find.byType(Column),
      );
      final texts = tester
          .widgetList<Text>(
            find.descendant(
              of: evidenceSection.first,
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data ?? '')
          .join(' ');
      expect(RegExp(r'\d').hasMatch(texts), isFalse);
    });

    testWidgets('"Escuchar antes"/"Escuchar ahora" play the right audio '
        'through the fake player', (tester) async {
      await seedBaseline();
      await seedMilestone();

      await pumpGymPage(tester);

      expect(find.text(l10nEs.progressPlaybackBeforeAction), findsOneWidget);
      expect(find.text(l10nEs.progressPlaybackNowAction), findsOneWidget);

      await tester.tap(find.text(l10nEs.progressPlaybackBeforeAction));
      await tester.pump();
      await tester.pump();
      expect(find.text(l10nEs.progressPlaybackStop), findsOneWidget);

      fakePlayer.completeNow();
      await tester.pump();
    });

    testWidgets('delete one removes that audio; the playback entry degrades '
        'gracefully', (tester) async {
      await seedBaseline();
      await seedMilestone();

      await pumpGymPage(tester);
      expect(find.text(l10nEs.progressPlaybackBeforeAction), findsOneWidget);

      await tester.tap(find.text(l10nEs.audioSettingsDeleteOneAction).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10nEs.audioSettingsConfirmAction));
      await tester.pumpAndSettle();

      expect(audioStore.statusOf('baseline-1'), const AudioRetention.deleted());
      expect(find.text(l10nEs.progressPlaybackUnavailable), findsOneWidget);
      expect(find.text(l10nEs.progressPlaybackBeforeAction), findsNothing);
    });

    testWidgets('delete all removes every stored attempt for the current '
        'user, same graceful degradation', (tester) async {
      await seedBaseline();
      await seedMilestone();

      await pumpGymPage(tester);

      await tester.tap(find.text(l10nEs.audioSettingsDeleteAllAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10nEs.audioSettingsConfirmAction));
      await tester.pumpAndSettle();

      expect(audioStore.statusOf('baseline-1'), const AudioRetention.deleted());
      expect(
        audioStore.statusOf('milestone-1'),
        const AudioRetention.deleted(),
      );
      expect(find.text(l10nEs.progressPlaybackUnavailable), findsOneWidget);
    });

    testWidgets('the consent toggle writes the opposite value', (tester) async {
      await seedBaseline();

      await pumpGymPage(tester);
      expect(
        find.text(l10nEs.audioSettingsConsentEnableAction),
        findsOneWidget,
      );

      await tester.tap(find.text(l10nEs.audioSettingsConsentEnableAction));
      await tester.pumpAndSettle();

      expect((await audioConsentRepo.read()).valueOrNull, isTrue);
      expect(
        find.text(l10nEs.audioSettingsConsentDisableAction),
        findsOneWidget,
      );

      await tester.tap(find.text(l10nEs.audioSettingsConsentDisableAction));
      await tester.pumpAndSettle();

      expect((await audioConsentRepo.read()).valueOrNull, isFalse);
      // Revoking consent only stops FUTURE retention; it never deletes
      // audio already stored.
      expect(
        audioStore.statusOf('baseline-1'),
        const AudioRetention.stored(
          path: '$userId/baseline-1.wav',
          mime: 'audio/wav',
        ),
      );
    });

    testWidgets('retake is disabled with the available date when too soon', (
      tester,
    ) async {
      await seedBaseline(diagnosedAt: DateTime(2026, 9, 10));

      await pumpGymPage(tester);

      expect(find.text(l10nEs.progressRetakeTitle), findsOneWidget);
      expect(
        find.text(l10nEs.diagnosisRetakeTooSoonMessage('10 de octubre')),
        findsOneWidget,
      );
      final button = tester.widget<FluiButton>(
        find
            .ancestor(
              of: find.text(l10nEs.progressRetakeAction),
              matching: find.byType(FluiButton),
            )
            .first,
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('retake is enabled once 30 days have passed', (tester) async {
      await seedBaseline(diagnosedAt: DateTime(2026, 8, 20));

      await pumpGymPage(tester);

      final button = tester.widget<FluiButton>(
        find
            .ancestor(
              of: find.text(l10nEs.progressRetakeAction),
              matching: find.byType(FluiButton),
            )
            .first,
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('flag off: the page is unchanged (no evidence section, no '
        'new queries)', (tester) async {
      await tester.pumpFlui(
        const ProgressPage(),
        overrides: [
          ...fakes.overrides,
          subscriptionRepositoryProvider.overrideWithValue(subscriptions),
        ],
        surfaceSize: const Size(400, 2400),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(l10nEs.progressEvidenceTitle.toUpperCase()),
        findsNothing,
      );
      expect(find.text(l10nEs.audioSettingsTitle), findsNothing);
      expect(find.text(l10nEs.progressRetakeTitle), findsNothing);
      // "Eliminar mi cuenta" calls `account-delete`, which is not deployed
      // to production yet (U22e production-safety rule): the entry must be
      // unreachable while the flag is off, in every backend.
      expect(find.text(l10nEs.accountDeletionTitle), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Account deletion (U22e)', () {
    late LearningFakes gymFakes;
    late FakeSubscriptionRepository gymSubscriptions;
    late FakeAccountDeletionRepository accountDeletion;

    setUp(() {
      gymFakes = LearningFakes(
        now: DateTime(2026, 9, 20, 9),
        speakingGym: true,
      );
      gymSubscriptions =
          FakeSubscriptionRepository(
            clock: gymFakes.clock,
            currentUserId: () => gymFakes.auth.currentUser?.id,
          )..grantAccess(
            AccessStatus(
              hasAccess: true,
              entitlementStatus: EntitlementStatus.trialing,
              trialEndsAt: DateTime(2026, 9, 27),
            ),
          );
      accountDeletion = FakeAccountDeletionRepository();
    });

    tearDown(() => gymFakes.dispose());

    Future<void> pumpGymPage(WidgetTester tester) async {
      await tester.pumpFlui(
        const ProgressPage(),
        overrides: [
          ...gymFakes.overrides,
          subscriptionRepositoryProvider.overrideWithValue(gymSubscriptions),
          accountDeletionRepositoryProvider.overrideWithValue(accountDeletion),
        ],
        surfaceSize: const Size(400, 4200),
      );
      await tester.pumpAndSettle();
    }

    Future<void> openBothConfirmations(WidgetTester tester) async {
      await tester.tap(find.text(l10nEs.accountDeletionAction));
      await tester.pumpAndSettle();
      expect(find.text(l10nEs.accountDeletionConfirmTitle), findsOneWidget);
      await tester.tap(find.text(l10nEs.accountDeletionContinueAction));
      await tester.pumpAndSettle();
      expect(
        find.text(l10nEs.accountDeletionFinalConfirmTitle),
        findsOneWidget,
      );
    }

    testWidgets('cancelling the first dialog calls nothing', (tester) async {
      await pumpGymPage(tester);

      await tester.tap(find.text(l10nEs.accountDeletionAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10nEs.audioSettingsCancelAction));
      await tester.pumpAndSettle();

      expect(accountDeletion.callCount, 0);
      expect(gymFakes.auth.currentUser, isNotNull);
    });

    testWidgets('confirming both dialogs deletes exactly once and signs out', (
      tester,
    ) async {
      await pumpGymPage(tester);

      await openBothConfirmations(tester);
      await tester.tap(find.text(l10nEs.accountDeletionFinalConfirmAction));
      await tester.pumpAndSettle();

      expect(accountDeletion.callCount, 1);
      expect(gymFakes.auth.currentUser, isNull);
    });

    testWidgets(
      'a billing failure keeps the user signed in with a "try again later" '
      'message, and stays retryable',
      (tester) async {
        accountDeletion.nextFailure = const AccountDeletionFailure(
          AccountDeletionErrorCode.billingUnavailable,
        );
        await pumpGymPage(tester);

        await openBothConfirmations(tester);
        await tester.tap(find.text(l10nEs.accountDeletionFinalConfirmAction));
        await tester.pump();
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(
          find.text(l10nEs.accountDeletionErrorBillingUnavailable),
          findsOneWidget,
        );
        expect(gymFakes.auth.currentUser, isNotNull);
        expect(accountDeletion.callCount, 1);

        // Retryable: the Fake cleared `nextFailure` after one use, so a
        // second confirmation succeeds.
        await tester.pumpAndSettle();
        await openBothConfirmations(tester);
        await tester.tap(find.text(l10nEs.accountDeletionFinalConfirmAction));
        await tester.pumpAndSettle();

        expect(accountDeletion.callCount, 2);
        expect(gymFakes.auth.currentUser, isNull);
      },
    );

    testWidgets(
      'a membership-not-found failure shows the contact-support message',
      (tester) async {
        accountDeletion.nextFailure = const AccountDeletionFailure(
          AccountDeletionErrorCode.membershipNotFound,
        );
        await pumpGymPage(tester);

        await openBothConfirmations(tester);
        await tester.tap(find.text(l10nEs.accountDeletionFinalConfirmAction));
        await tester.pump();
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(
          find.text(l10nEs.accountDeletionErrorContactSupport),
          findsOneWidget,
        );
        expect(gymFakes.auth.currentUser, isNotNull);
      },
    );

    testWidgets('a storage/deletion failure shows the "try again" message', (
      tester,
    ) async {
      accountDeletion.nextFailure = const AccountDeletionFailure(
        AccountDeletionErrorCode.deletionFailed,
      );
      await pumpGymPage(tester);

      await openBothConfirmations(tester);
      await tester.tap(find.text(l10nEs.accountDeletionFinalConfirmAction));
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text(l10nEs.accountDeletionErrorTryAgain), findsOneWidget);
      expect(gymFakes.auth.currentUser, isNotNull);
    });

    testWidgets(
      'double-tapping the final confirm button still sends a single request',
      (tester) async {
        accountDeletion = FakeAccountDeletionRepository(
          latency: const Duration(milliseconds: 50),
        );
        await pumpGymPage(tester);

        await openBothConfirmations(tester);
        await tester.tap(find.text(l10nEs.accountDeletionFinalConfirmAction));
        // No pump in between: both taps race the same frame, before the
        // dialog (and its own Future) has resolved even once.
        await tester.tap(
          find.text(l10nEs.accountDeletionFinalConfirmAction),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();

        expect(accountDeletion.callCount, 1);
        expect(gymFakes.auth.currentUser, isNull);
      },
    );
  });
}
