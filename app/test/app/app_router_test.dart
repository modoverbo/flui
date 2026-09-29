import 'dart:async';
import 'dart:typed_data';

import 'package:flui/app/router/app_router.dart';
import 'package:flui/app/router/app_routes.dart';
import 'package:flui/app/shell/flui_bottom_bar.dart';
import 'package:flui/core/audio/audio_providers.dart';
import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/audio/speech_recorder.dart';
import 'package:flui/core/config/feature_flags.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/l10n/gen/app_localizations.dart';
import 'package:flui/core/mic/mic_controller.dart';
import 'package:flui/core/mic/mic_providers.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/core/mic/presentation/mic_blocked_sheet.dart';
import 'package:flui/core/mic/presentation/mic_button.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/features/auth/domain/app_user.dart';
import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:flui/features/daily/presentation/providers/daily_providers.dart';
import 'package:flui/features/diagnosis/domain/skill_profile_repository.dart';
import 'package:flui/features/subscription/domain/access_status.dart';
import 'package:flui/features/themes/data/fake/seed_themes.dart';
import 'package:flui/features/training/data/fake_speaking_attempt_repository.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/skill_profile.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:flui/features/training/domain/training_mode.dart';
import 'package:flui/features/training/presentation/controllers/loop_mic_target.dart';
import 'package:flui/features/training/presentation/providers/training_providers.dart';
import 'package:flui/features/vocabulary/domain/word_progress.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_card.dart';
import 'package:flui/shared/widgets/flui_logo.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../integration_test/support/app_harness.dart';

/// A controllable fake, ported from `mic_button_test.dart`'s — the real
/// path only needs a permission-granted recorder that finishes instantly.
final class _FakeSpeechRecorder implements SpeechRecorder {
  new();

  /// Observable proof a real recording actually started — U15a's review
  /// fix hinges on HOY's mic NEVER calling this on its first press.
  int startCalls = 0;

  @override
  Stream<double> get amplitude => const Stream.empty();

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> start() async => startCalls++;

  @override
  Future<Uint8List> stop() async => Uint8List.fromList(const [1, 2, 3]);

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}

/// A minimal fake with a distinctive, controllable prompt — used to prove
/// the mic's idle label actually reflects whichever branch is active,
/// without depending on the real training loop's exact copy strings.
/// [pendingDelivery], when set, makes [deliver] hang until completed — the
/// deterministic way to prove an in-flight delivery is never cancelled by
/// navigation at the real, full-app level (U23d).
final class _FakeMicTarget implements MicTarget {
  new({
    required this.prompt,
    this.pendingDelivery,
    this.deliveryResult = const MicAccepted(),
  });

  @override
  final MicPrompt prompt;

  @override
  final Duration maxDuration = const Duration(seconds: 30);

  @override
  MicAvailability get availability => const MicReady();

  @override
  Stream<void> get changes => const Stream.empty();

  final Completer<MicDelivery>? pendingDelivery;
  final MicDelivery deliveryResult;

  @override
  Future<MicDelivery> deliver(RecordedAudio audio) async {
    final pending = pendingDelivery;
    if (pending != null) return await pending.future;
    return deliveryResult;
  }
}

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('es'));

/// U14a: diagnosis is now mandatory whenever `speakingGym` is on and access
/// is granted. Every real-path test below exercises something else entirely
/// (ENTRENAR, the mic, quick practice) and needs the signed-in user's
/// diagnosis already completed so `appRedirect` never detours it to
/// `/diagnosis` first — mirrors `FakeSubscriptionRepository.grantAccess`'s
/// own synchronous-seed shape.
final _seededProfile = SkillProfileRecord(
  id: 'seed-diagnosis',
  kind: SkillProfileKind.baseline,
  diagnosedAt: DateTime(2026, 9),
  profile: const SkillProfile(
    topArea: SkillArea.thinking,
    secondArea: SkillArea.language,
    strengths: <BehaviorCode>[],
    evidence: <DiagnosisEvidence>[],
  ),
);

Future<void> _planAndCompleteDiagnosis(AppHarness harness) async {
  await harness.planToday();
  harness.skillProfiles.seedProfile(_seededProfile);
}

void main() {
  const ana = AppUser(
    id: 'ignored',
    email: 'ana@correo.com',
    displayName: 'Ana',
  );
  const trialing = AccessStatus(
    hasAccess: true,
    entitlementStatus: EntitlementStatus.trialing,
  );

  String location(AppHarness harness) => harness.container
      .read(goRouterProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .toString();

  testWidgets('signed out users land on welcome', (tester) async {
    final harness = AppHarness();
    await harness.pumpApp(tester);

    expect(location(harness), AppRoutes.welcome);
    expect(find.text('Empezar'), findsOneWidget);
  });

  testWidgets('signed in users without access land on the paywall', (
    tester,
  ) async {
    final harness = AppHarness(signedInAs: ana);
    await harness.pumpApp(tester);

    expect(location(harness), AppRoutes.paywall);
  });

  testWidgets('subscribers with a plan land on Hoy and can switch tabs', (
    tester,
  ) async {
    final harness = AppHarness(signedInAs: ana, access: trialing);
    await harness.pumpApp(tester, arrange: (h) => h.planToday());

    expect(location(harness), AppRoutes.today);
    await tester.tap(find.text('Palabras'));
    await tester.pumpAndSettle();

    expect(location(harness), AppRoutes.words);
    expect(find.text('Tu repertorio empieza hoy.'), findsOneWidget);
  });

  testWidgets('mobile shell keeps four editorial destinations on paper', (
    tester,
  ) async {
    final harness = AppHarness(signedInAs: ana, access: trialing);
    await harness.pumpApp(tester, arrange: (h) => h.planToday());

    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.destinations, hasLength(4));
    expect(navigation.backgroundColor, FluiColors.surface);
    expect(navigation.indicatorColor, FluiColors.greenTint);
    expect(navigation.selectedIndex, 0);
    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Palabras'), findsOneWidget);
    expect(find.text('Habla'), findsOneWidget);
    expect(find.text('Progreso'), findsOneWidget);
    final progressDestination = tester.widget<NavigationDestination>(
      find.ancestor(
        of: find.text('Progreso'),
        matching: find.byType(NavigationDestination),
      ),
    );
    expect(progressDestination.tooltip, 'Tu progreso');
  });

  testWidgets('the time budget is asked once per local day', (tester) async {
    final harness = AppHarness(signedInAs: ana, access: trialing);
    await harness.pumpApp(tester);

    expect(location(harness), AppRoutes.timeBudget);
    harness.container.read(goRouterProvider).go(AppRoutes.words);
    await tester.pumpAndSettle();
    expect(location(harness), AppRoutes.timeBudget);

    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();
    expect(location(harness), AppRoutes.today);

    harness.container.read(goRouterProvider).go(AppRoutes.words);
    await tester.pumpAndSettle();
    expect(location(harness), AppRoutes.words);

    // A new local day asks again.
    harness.clock.advance(const Duration(days: 1));
    harness.container.invalidate(dailyGateProvider);
    await tester.pumpAndSettle();
    harness.container.read(goRouterProvider).go(AppRoutes.today);
    await tester.pumpAndSettle();
    expect(location(harness), AppRoutes.timeBudget);
  });

  testWidgets('deep links wait for the plan, then continue', (tester) async {
    final harness = AppHarness(signedInAs: ana, access: trialing);
    await harness.pumpApp(
      tester,
      initialLocation: AppRoutes.words,
      arrange: (h) => h.planToday(),
    );

    expect(location(harness), AppRoutes.words);
    expect(find.text('Tu repertorio empieza hoy.'), findsOneWidget);
  });

  testWidgets('wide screens show the navigation rail', (tester) async {
    final harness = AppHarness(signedInAs: ana, access: trialing);
    await harness.pumpApp(
      tester,
      size: const Size(1280, 800),
      arrange: (h) => h.planToday(),
    );

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    final navigation = tester.widget<NavigationRail>(
      find.byType(NavigationRail),
    );
    expect(navigation.destinations, hasLength(4));
    expect(navigation.backgroundColor, FluiColors.paper);
    expect(navigation.indicatorColor, FluiColors.greenTint);
    expect(navigation.selectedIndex, 0);
  });

  testWidgets('a reloaded /checkout/return waits for access, then continues', (
    tester,
  ) async {
    final harness = AppHarness(signedInAs: ana);
    await harness.pumpApp(
      tester,
      initialLocation: AppRoutes.checkoutReturn,
      arrange: (harness) => harness.subscriptions.completeCheckout(),
    );

    expect(location(harness), AppRoutes.timeBudget);
    expect(find.text('¿Cuánto tiempo tienes hoy?'), findsOneWidget);
  });

  testWidgets('/checkout/return without a webhook ends in a retry', (
    tester,
  ) async {
    final harness = AppHarness(signedInAs: ana);
    await harness.pumpApp(tester, initialLocation: AppRoutes.checkoutReturn);

    expect(location(harness), AppRoutes.checkoutReturn);
    expect(find.text('Está tardando más de lo normal'), findsOneWidget);
  });

  testWidgets('when my_access fails the splash offers a retry', (tester) async {
    final harness = AppHarness(signedInAs: ana, access: trialing);
    await harness.pumpApp(
      tester,
      arrange: (harness) async {
        await harness.planToday();
        harness.subscriptions.nextFailure = const NetworkFailure();
      },
    );

    expect(location(harness), startsWith(AppRoutes.splash));
    expect(find.text('No pudimos conectar con flui.'), findsOneWidget);
    expect(find.byType(FluiLogo), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(location(harness), AppRoutes.today);
  });

  testWidgets('unknown routes show a recovery action', (tester) async {
    final harness = AppHarness(signedInAs: ana, access: trialing);
    await harness.pumpApp(
      tester,
      initialLocation: '/missing-page',
      arrange: (h) => h.planToday(),
    );
    await tester.pumpAndSettle();

    expect(find.text('No encontramos esta página.'), findsOneWidget);
    expect(find.text('Ir al inicio'), findsOneWidget);
    expect(find.byType(FluiLogo), findsOneWidget);
    await tester.tap(find.text('Ir al inicio'));
    await tester.pumpAndSettle();

    expect(location(harness), AppRoutes.today);
  });

  testWidgets('signing out from Tu progreso returns to welcome', (
    tester,
  ) async {
    final harness = AppHarness(signedInAs: ana, access: trialing);
    await harness.pumpApp(tester, initialLocation: AppRoutes.progress);

    // Tu progreso stays reachable before choosing today's time.
    expect(location(harness), AppRoutes.progress);
    await tester.ensureVisible(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(location(harness), AppRoutes.welcome);
  });

  group('Habla, the fourth shell branch (speakingGym OFF, the default)', () {
    testWidgets(
      'the old /speaking/challenge deep link still resolves, inside the shell',
      (tester) async {
        final harness = AppHarness(signedInAs: ana, access: trialing);
        await harness.pumpApp(
          tester,
          initialLocation: AppRoutes.speakingChallenge,
          arrange: (h) => h.planToday(),
        );

        expect(location(harness), AppRoutes.speakingChallenge);
        // Still inside the shell: the tab bar renders, Habla selected, and
        // the landing content is the challenge's own "ready" phase.
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.text('Habla'), findsOneWidget);
        expect(find.text('Abrir ejercicio'), findsOneWidget);
      },
    );

    testWidgets('switching to Habla from another tab lands on "ready"', (
      tester,
    ) async {
      final harness = AppHarness(signedInAs: ana, access: trialing);
      await harness.pumpApp(tester, arrange: (h) => h.planToday());

      expect(location(harness), AppRoutes.today);
      await tester.tap(find.text('Habla'));
      await tester.pumpAndSettle();

      expect(location(harness), AppRoutes.speakingChallenge);
      expect(find.text('Abrir ejercicio'), findsOneWidget);
    });

    testWidgets('opening a challenge takes over full screen before recording', (
      tester,
    ) async {
      final harness = AppHarness(signedInAs: ana, access: trialing);
      await harness.pumpApp(
        tester,
        initialLocation: AppRoutes.speakingChallenge,
        arrange: (h) => h.planToday(),
      );

      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.tap(find.text('Abrir ejercicio'));
      await tester.pumpAndSettle();

      expect(location(harness), AppRoutes.speakingChallengeLive);
      // Full-screen take-over: the shell's own chrome is gone.
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Empezar a hablar'), findsOneWidget);
    });

    testWidgets(
      'the shell matches the pre-U16 app exactly: same 4 tab labels/order, '
      'Habla page opens, no train route reachable',
      (tester) async {
        final harness = AppHarness(signedInAs: ana, access: trialing);
        await harness.pumpApp(tester, arrange: (h) => h.planToday());

        final navigation = tester.widget<NavigationBar>(
          find.byType(NavigationBar),
        );
        expect(navigation.destinations, hasLength(4));
        expect(navigation.selectedIndex, 0);
        expect(find.text('Hoy'), findsOneWidget);
        expect(find.text('Palabras'), findsOneWidget);
        expect(find.text('Habla'), findsOneWidget);
        expect(find.text('Progreso'), findsOneWidget);
        expect(find.text('Entrenar'), findsNothing);

        harness.container.read(goRouterProvider).go(AppRoutes.train);
        await tester.pumpAndSettle();

        // /train is not a route while the flag is off: NotFoundPage, never
        // the training-lab mode picker.
        expect(find.text('Piensa y habla'), findsNothing);
        expect(find.text('No encontramos esta página.'), findsOneWidget);
      },
    );
  });

  group("HOY's own loop, /today/train (speakingGym ON, U15a)", () {
    const seededChallengeId = '072b6134-a2b7-4e79-86bf-5a6aeeb5118c';

    testWidgets('/today/train is unreachable while the flag is off', (
      tester,
    ) async {
      final harness = AppHarness(signedInAs: ana, access: trialing);
      await harness.pumpApp(tester, arrange: (h) => h.planToday());

      harness.container.read(goRouterProvider).go(AppRoutes.todayTrain);
      await tester.pumpAndSettle();

      expect(find.text('No encontramos esta página.'), findsOneWidget);
    });

    testWidgets(
      'a session with a persisted challenge starts the loop on the branch '
      "navigator, not a full-screen take-over — HOY's context, unlike "
      "ENTRENAR's",
      (tester) async {
        final harness = AppHarness(
          signedInAs: ana,
          access: trialing,
          overrides: [speakingGymEnabledProvider.overrideWithValue(true)],
        );
        await harness.pumpApp(
          tester,
          initialLocation: AppRoutes.todayTrain,
          arrange: (h) async {
            harness.skillProfiles.seedProfile(_seededProfile);
            await harness.dailySessions.saveSession(
              DailySession(
                localDate: harness.clock.localToday(),
                minutes: 10,
                challengeId: seededChallengeId,
              ),
            );
          },
        );

        expect(
          find.text('Cuéntame qué hiciste esta mañana, de principio a fin.'),
          findsOneWidget,
        );
        // Branch child, not a root-navigator take-over (design D30): the
        // shell chrome stays, same as ENTRENAR's `/train/:mode`.
        expect(find.byType(FluiBottomBar), findsOneWidget);
      },
    );

    testWidgets('(a) picking a duration then tapping the bottom-bar mic on HOY '
        'plans the session and navigates to /today/train WITHOUT recording '
        "anything — the challenge prompt shows, the mic label is the loop's "
        '(U15a review fix: HOY never records directly)', (tester) async {
      final recorder = _FakeSpeechRecorder();
      final harness = AppHarness(
        signedInAs: ana,
        access: trialing,
        overrides: [
          speakingGymEnabledProvider.overrideWithValue(true),
          speechRecorderFactoryProvider.overrideWithValue(() => recorder),
        ],
      );
      await harness.pumpApp(
        tester,
        arrange: (h) async => h.skillProfiles.seedProfile(_seededProfile),
      );

      await tester.tap(find.text('30 min'));
      await tester.pumpAndSettle();

      // A single TAP (not a hold gesture): `TodayStartTarget.availability`
      // is always `MicPrepare`, which never leads to a capture on this
      // same gesture — matches `QuickPracticeTarget`'s own established
      // first-activation shape.
      await tester.tap(find.byType(MicButton));
      await tester.pumpAndSettle();

      expect(recorder.startCalls, 0);
      final saved =
          (await harness.dailySessions.fetchSessions()).valueOrNull!.single;
      expect(saved.minutes, 30);
      expect(saved.challengeId, isNotNull);
      expect(harness.speakingAttempts.attemptsForCurrentUser, isEmpty);
      expect(location(harness), AppRoutes.todayTrain);

      // The mic is now bound to the loop's registered LoopMicTarget, not
      // TodayStartTarget — same real-path assertion style as the
      // ENTRENAR mic test above.
      final registry = harness.container.read(micTargetRegistryProvider);
      final (onLoop, _) = registry.resolve();
      expect(onLoop, isA<LoopMicTarget>());
    });

    testWidgets('(b) the NEXT mic press, on /today/train, actually records and '
        'delivers to the loop', (tester) async {
      final recorder = _FakeSpeechRecorder();
      final harness = AppHarness(
        signedInAs: ana,
        access: trialing,
        overrides: [
          speakingGymEnabledProvider.overrideWithValue(true),
          speechRecorderFactoryProvider.overrideWithValue(() => recorder),
        ],
      );
      await harness.pumpApp(
        tester,
        arrange: (h) async => h.skillProfiles.seedProfile(_seededProfile),
      );
      await tester.tap(find.text('30 min'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MicButton));
      await tester.pumpAndSettle();
      expect(location(harness), AppRoutes.todayTrain);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(MicButton)),
      );
      for (var i = 0; i < 3; i++) {
        await tester.pump();
      }
      harness.clock.advance(const Duration(milliseconds: 700));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(recorder.startCalls, 1);
      expect(harness.speakingAttempts.attemptsForCurrentUser, hasLength(1));
    });

    testWidgets('(c) with a plan already persisted, the HOY mic press shows '
        '"Continuar la sesión de hoy" and navigates without re-planning', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final recorder = _FakeSpeechRecorder();
      final harness = AppHarness(
        signedInAs: ana,
        access: trialing,
        overrides: [
          speakingGymEnabledProvider.overrideWithValue(true),
          speechRecorderFactoryProvider.overrideWithValue(() => recorder),
        ],
      );
      await harness.pumpApp(
        tester,
        arrange: (h) async {
          h.skillProfiles.seedProfile(_seededProfile);
          await h.dailySessions.saveSession(
            DailySession(
              localDate: h.clock.localToday(),
              minutes: 20,
              challengeId: seededChallengeId,
            ),
          );
        },
      );

      expect(
        tester.getSemantics(find.byType(MicButton)).label,
        'Continuar la sesión de hoy',
      );
      await tester.tap(find.byType(MicButton));
      await tester.pumpAndSettle();

      expect(recorder.startCalls, 0);
      expect(location(harness), AppRoutes.todayTrain);
      final saved =
          (await harness.dailySessions.fetchSessions()).valueOrNull!.single;
      // Unchanged — still 20, never re-planned to a chip default.
      expect(saved.minutes, 20);
      handle.dispose();
    });

    testWidgets(
      '(d) a planning failure shows the notice, keeps the user on HOY, '
      'and records nothing',
      (tester) async {
        final recorder = _FakeSpeechRecorder();
        final harness = AppHarness(
          signedInAs: ana,
          access: trialing,
          overrides: [
            speakingGymEnabledProvider.overrideWithValue(true),
            speechRecorderFactoryProvider.overrideWithValue(() => recorder),
          ],
        );
        await harness.pumpApp(
          tester,
          arrange: (h) async => h.skillProfiles.seedProfile(_seededProfile),
        );
        harness.dailySessions.nextFailure = const NetworkFailure();

        await tester.tap(find.byType(MicButton));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'No pudimos preparar tu sesión de hoy. Inténtalo de '
            'nuevo.',
          ),
          findsOneWidget,
        );
        expect(location(harness), AppRoutes.today);
        expect(recorder.startCalls, 0);
        expect(
          (await harness.dailySessions.fetchSessions()).valueOrNull,
          isEmpty,
        );
        expect(harness.speakingAttempts.attemptsForCurrentUser, isEmpty);
      },
    );
  });

  group("HOY's woven words -> mic hint + mastery (speakingGym ON, U15b)", () {
    // Real `seedWordsWithThemes` ids (not synthetic fixtures): the mic's
    // hint and the spoken-use detection both run against the REAL app —
    // `speechAnalysisRepositoryProvider`/`contentRepositoryProvider` are
    // already fixed by `AppHarness`'s own backend, so the words are picked
    // so that `FakeSpeechAnalysisRepository`'s first-attempt fixed
    // transcript ("...organizar mejor mi mañana para trabajar con más
    // claridad.") naturally uses "claridad" (lemma) and never "perspicaz".
    const claridadId = 'a3bff3b7-ff0a-4b41-be29-f722a6e2ea94'; // claridad
    const perspicazId = 'a0000000-0000-4000-8000-000000000001'; // perspicaz
    const seededChallengeId = '072b6134-a2b7-4e79-86bf-5a6aeeb5118c';

    Future<void> seedWovenWords(AppHarness h) async {
      h.skillProfiles.seedProfile(_seededProfile);
      final today = h.clock.localToday();
      await h.wordProgress.saveProgress(
        WordProgress(
          wordId: claridadId,
          state: WordState.practica,
          introducedOn: LocalDate(2026, 9, 1),
          nextDueOn: today,
        ),
      );
      await h.wordProgress.saveProgress(
        WordProgress(
          wordId: perspicazId,
          state: WordState.practica,
          introducedOn: LocalDate(2026, 9, 1),
          nextDueOn: today,
        ),
      );
      await h.dailySessions.saveSession(
        DailySession(
          localDate: today,
          minutes: 10,
          challengeId: seededChallengeId,
          wovenWordIds: [claridadId, perspicazId],
        ),
      );
    }

    Future<void> holdToRecord(WidgetTester tester, AppHarness harness) async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(MicButton)),
      );
      for (var i = 0; i < 3; i++) {
        await tester.pump();
      }
      harness.clock.advance(const Duration(milliseconds: 700));
      await gesture.up();
      await tester.pumpAndSettle();
    }

    testWidgets(
      'recording detects the spoken word, advances only its mastery, and '
      'the transfer-step hint then shows both woven words',
      (tester) async {
        final handle = tester.ensureSemantics();
        final recorder = _FakeSpeechRecorder();
        final harness = AppHarness(
          signedInAs: ana,
          access: trialing,
          overrides: [
            speakingGymEnabledProvider.overrideWithValue(true),
            speechRecorderFactoryProvider.overrideWithValue(() => recorder),
          ],
        );
        await harness.pumpApp(
          tester,
          initialLocation: AppRoutes.todayTrain,
          arrange: seedWovenWords,
        );

        await holdToRecord(tester, harness);

        final saved = harness.speakingAttempts.attemptsForCurrentUser.single;
        expect(saved.targetWordIds, [claridadId, perspicazId]);
        expect(saved.wordsUsed, [claridadId]);
        final progress =
            (await harness.wordProgress.fetchProgress()).valueOrNull!;
        final claridadAfter = progress.firstWhere(
          (row) => row.wordId == claridadId,
        );
        final perspicazAfter = progress.firstWhere(
          (row) => row.wordId == perspicazId,
        );
        expect(claridadAfter.ladderStep, 1);
        expect(claridadAfter.productionDone, isTrue);
        // The unused word is byte-identical to what was seeded.
        expect(perspicazAfter.ladderStep, 0);
        expect(perspicazAfter.productionDone, isFalse);
        expect(perspicazAfter.nextDueOn, harness.clock.localToday());

        await holdToRecord(tester, harness); // repeat attempt -> comparison

        final hint = tester.getSemantics(find.byType(MicButton)).hint;
        expect(hint, contains('claridad'));
        expect(hint, contains('perspicaz'));
        handle.dispose();
      },
    );

    testWidgets('no due words woven in -> the mic hint stays generic', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final recorder = _FakeSpeechRecorder();
      final harness = AppHarness(
        signedInAs: ana,
        access: trialing,
        overrides: [
          speakingGymEnabledProvider.overrideWithValue(true),
          speechRecorderFactoryProvider.overrideWithValue(() => recorder),
        ],
      );
      await harness.pumpApp(
        tester,
        initialLocation: AppRoutes.todayTrain,
        arrange: (h) async {
          h.skillProfiles.seedProfile(_seededProfile);
          await h.dailySessions.saveSession(
            DailySession(
              localDate: h.clock.localToday(),
              minutes: 10,
              challengeId: seededChallengeId,
            ),
          );
        },
      );

      await holdToRecord(tester, harness);
      await holdToRecord(tester, harness); // repeat attempt -> comparison

      final hint = tester.getSemantics(find.byType(MicButton)).hint;
      expect(hint, 'Aplica lo que acabas de practicar.');
      handle.dispose();
    });

    testWidgets(
      'retrySave after a failed insert saves once and records mastery '
      'exactly once, never twice',
      (tester) async {
        final recorder = _FakeSpeechRecorder();
        final harness = AppHarness(
          signedInAs: ana,
          access: trialing,
          overrides: [
            speakingGymEnabledProvider.overrideWithValue(true),
            speechRecorderFactoryProvider.overrideWithValue(() => recorder),
          ],
        );
        await harness.pumpApp(
          tester,
          initialLocation: AppRoutes.todayTrain,
          arrange: seedWovenWords,
        );
        harness.speakingAttempts.failInserts = true;

        await holdToRecord(tester, harness);

        expect(find.text('Reintentar guardar'), findsOneWidget);
        expect(harness.speakingAttempts.attemptsForCurrentUser, isEmpty);
        final beforeRetry =
            (await harness.wordProgress.fetchProgress()).valueOrNull!;
        expect(
          beforeRetry.firstWhere((row) => row.wordId == claridadId).ladderStep,
          0,
        );

        harness.speakingAttempts.failInserts = false;
        await tester.tap(find.text('Reintentar guardar'));
        await tester.pumpAndSettle();

        expect(harness.speakingAttempts.attemptsForCurrentUser, hasLength(1));
        final afterRetry =
            (await harness.wordProgress.fetchProgress()).valueOrNull!;
        // Exactly one ladder advance — the failed automatic retry inside
        // the first `submit()` call never recorded mastery (the attempt
        // was never saved), and the manual `retrySave` recorded it once.
        expect(
          afterRetry.firstWhere((row) => row.wordId == claridadId).ladderStep,
          1,
        );
      },
    );
  });

  group('Entrenar, the second shell branch (speakingGym ON, U16)', () {
    List<Override> gymOn() => [
      speakingGymEnabledProvider.overrideWithValue(true),
    ];

    testWidgets('the old /speaking/challenge deep link redirects into train', (
      tester,
    ) async {
      final harness = AppHarness(
        signedInAs: ana,
        access: trialing,
        overrides: gymOn(),
      );
      await harness.pumpApp(
        tester,
        initialLocation: AppRoutes.speakingChallenge,
        arrange: _planAndCompleteDiagnosis,
      );

      expect(location(harness), AppRoutes.train);
      // Still inside the shell: the tab bar renders, and the landing
      // content is the mode picker, never a 404.
      expect(find.byType(FluiBottomBar), findsOneWidget);
      expect(find.text('Piensa y habla'), findsOneWidget);
    });

    testWidgets('switching to Entrenar from another tab lands on the picker', (
      tester,
    ) async {
      final harness = AppHarness(
        signedInAs: ana,
        access: trialing,
        overrides: gymOn(),
      );
      await harness.pumpApp(tester, arrange: _planAndCompleteDiagnosis);

      expect(location(harness), AppRoutes.today);
      await tester.tap(find.text('Entrenar'));
      await tester.pumpAndSettle();

      expect(location(harness), AppRoutes.train);
      expect(find.text('Piensa y habla'), findsOneWidget);
    });

    testWidgets(
      'starting a mode stays on the branch navigator, unlike the retired '
      'full-screen speaking-challenge take-over',
      (tester) async {
        final harness = AppHarness(
          signedInAs: ana,
          access: trialing,
          overrides: gymOn(),
        );
        await harness.pumpApp(
          tester,
          initialLocation: AppRoutes.train,
          arrange: _planAndCompleteDiagnosis,
        );

        expect(find.byType(FluiBottomBar), findsOneWidget);
        await tester.tap(find.text('Piensa y habla'));
        await tester.pumpAndSettle();

        expect(
          location(harness),
          AppRoutes.trainMode(TrainingMode.thinkAndSpeak),
        );
        // Branch child, not a root-navigator take-over (design D30): the
        // shell chrome stays, unlike the retired speaking-challenge "live".
        expect(find.byType(FluiBottomBar), findsOneWidget);
      },
    );

    testWidgets(
      "tapping the shell mic delivers to the ENTRENAR branch's registered "
      'LoopMicTarget; switching to Hoy changes what the mic resolves '
      '(U23c real-path wiring)',
      (tester) async {
        final recorder = _FakeSpeechRecorder();
        final harness = AppHarness(
          signedInAs: ana,
          access: trialing,
          overrides: [
            ...gymOn(),
            speechRecorderFactoryProvider.overrideWithValue(() => recorder),
          ],
        );
        await harness.pumpApp(
          tester,
          initialLocation: AppRoutes.trainMode(TrainingMode.thinkAndSpeak),
          arrange: _planAndCompleteDiagnosis,
        );

        final registry = harness.container.read(micTargetRegistryProvider);
        final (onEntrenar, _) = registry.resolve();
        expect(onEntrenar, isA<LoopMicTarget>());

        final controller = harness.container.read(micControllerProvider);
        expect(controller, isNotNull);
        final notices = <MicNotice>[];
        controller!.notices.listen(notices.add);

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(MicButton)),
        );
        for (var i = 0; i < 3; i++) {
          await tester.pump();
        }
        expect(controller.state, isA<MicRecording>());

        harness.clock.advance(const Duration(milliseconds: 700));
        await gesture.up();
        await tester.pumpAndSettle();

        // The delivery actually reached the registered target (not the
        // explained fallback, which would have emitted deliveryFailed):
        // the mic settles back to idle with no failure notice.
        expect(notices, isNot(contains(MicNotice.deliveryFailed)));
        expect(controller.state, isA<MicIdle>());
        expect((controller.state as MicIdle).block, isNull);

        // Switching tabs changes which target the mic resolves against.
        await tester.tap(find.text('Hoy'));
        await tester.pumpAndSettle();
        final (onHoy, _) = registry.resolve();
        expect(onHoy, isNot(isA<LoopMicTarget>()));
      },
    );

    testWidgets(
      "switching tabs refreshes the mic's visible idle label to the newly "
      'active branch (orchestrator review finding on U23c: setActiveBranch '
      'must notify MicController, not just flip an internal index)',
      (tester) async {
        final handle = tester.ensureSemantics();
        const distinctiveLabel = 'ETIQUETA_DISTINTIVA_ENTRENAR';
        final harness = AppHarness(
          signedInAs: ana,
          access: trialing,
          overrides: gymOn(),
        );
        await harness.pumpApp(tester, arrange: _planAndCompleteDiagnosis);
        // Lands on Hoy (branch 0) by default.

        harness.container
            .read(micTargetRegistryProvider)
            .register(
              _FakeMicTarget(
                prompt: const MicPrompt(actionLabel: distinctiveLabel),
              ),
              layer: MicLayer.branch,
              branch: 1,
            );
        await tester.pump();

        // Still on Hoy: the ENTRENAR-only target must not be visible yet.
        var label = tester.getSemantics(find.byType(MicButton)).label;
        expect(label, isNot(distinctiveLabel));

        await tester.tap(find.text('Entrenar'));
        await tester.pumpAndSettle();
        label = tester.getSemantics(find.byType(MicButton)).label;
        expect(label, distinctiveLabel);

        await tester.tap(find.text('Hoy'));
        await tester.pumpAndSettle();
        label = tester.getSemantics(find.byType(MicButton)).label;
        expect(label, isNot(distinctiveLabel));

        await tester.tap(find.text('Entrenar'));
        await tester.pumpAndSettle();
        label = tester.getSemantics(find.byType(MicButton)).label;
        expect(label, distinctiveLabel);
        handle.dispose();
      },
    );
  });

  group('U23d — MicNavigationBinding, notices, blocked sheets (real path)', () {
    List<Override> gymOn() => [
      speakingGymEnabledProvider.overrideWithValue(true),
    ];

    testWidgets(
      'starting a capture via the real bottom-bar mic then switching tabs '
      'cancels it, with the cancelledByNavigation notice visible',
      (tester) async {
        final recorder = _FakeSpeechRecorder();
        final harness = AppHarness(
          signedInAs: ana,
          access: trialing,
          overrides: [
            ...gymOn(),
            speechRecorderFactoryProvider.overrideWithValue(() => recorder),
          ],
        );
        await harness.pumpApp(
          tester,
          initialLocation: AppRoutes.trainMode(TrainingMode.thinkAndSpeak),
          arrange: _planAndCompleteDiagnosis,
        );
        final controller = harness.container.read(micControllerProvider)!;

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(MicButton)),
        );
        for (var i = 0; i < 3; i++) {
          await tester.pump();
        }
        expect(controller.state, isA<MicRecording>());

        await tester.tap(find.text('Hoy'));
        await tester.pump();

        expect(controller.state, isA<MicIdle>());
        expect(
          find.text('Grabación cancelada: cambiaste de pantalla.'),
          findsOneWidget,
        );

        await gesture.up();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'backgrounding the app cancels an active recording silently; the '
      'cancelledByBackground notice appears only once resumed',
      (tester) async {
        final recorder = _FakeSpeechRecorder();
        final harness = AppHarness(
          signedInAs: ana,
          access: trialing,
          overrides: [
            ...gymOn(),
            speechRecorderFactoryProvider.overrideWithValue(() => recorder),
          ],
        );
        await harness.pumpApp(
          tester,
          initialLocation: AppRoutes.trainMode(TrainingMode.thinkAndSpeak),
          arrange: _planAndCompleteDiagnosis,
        );
        final controller = harness.container.read(micControllerProvider)!;

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(MicButton)),
        );
        for (var i = 0; i < 3; i++) {
          await tester.pump();
        }
        expect(controller.state, isA<MicRecording>());

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        await tester.pump();

        expect(controller.state, isA<MicIdle>());
        expect(
          find.text('Grabación cancelada: la app pasó a segundo plano.'),
          findsNothing,
        );

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();

        expect(
          find.text('Grabación cancelada: la app pasó a segundo plano.'),
          findsOneWidget,
        );

        await gesture.up();
        await tester.pumpAndSettle();
      },
    );

    testWidgets('an in-flight delivery is NEVER cancelled by navigating away', (
      tester,
    ) async {
      final recorder = _FakeSpeechRecorder();
      final pendingDelivery = Completer<MicDelivery>();
      final harness = AppHarness(
        signedInAs: ana,
        access: trialing,
        overrides: [
          ...gymOn(),
          speechRecorderFactoryProvider.overrideWithValue(() => recorder),
        ],
      );
      await harness.pumpApp(
        tester,
        initialLocation: AppRoutes.trainMode(TrainingMode.thinkAndSpeak),
        arrange: _planAndCompleteDiagnosis,
      );
      // A controllable target outranks the real LoopMicTarget so the
      // delivery's completion is deterministic, not a race against the
      // fake backend's own (zero-latency but still async) pipeline.
      harness.container
          .read(micTargetRegistryProvider)
          .register(
            _FakeMicTarget(
              prompt: const MicPrompt(actionLabel: 'Grabar'),
              pendingDelivery: pendingDelivery,
            ),
            layer: MicLayer.branch,
          );
      await tester.pump();
      final controller = harness.container.read(micControllerProvider)!;

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(MicButton)),
      );
      for (var i = 0; i < 3; i++) {
        await tester.pump();
      }
      harness.clock.advance(const Duration(milliseconds: 700));
      await gesture.up();
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
      expect(controller.state, isA<MicDelivering>());

      await tester.tap(find.text('Hoy'));
      await tester.pump();

      expect(controller.state, isA<MicDelivering>());
      expect(
        find.text('Grabación cancelada: cambiaste de pantalla.'),
        findsNothing,
      );

      pendingDelivery.complete(const MicAccepted());
      await tester.pumpAndSettle();

      expect(controller.state, isA<MicIdle>());
    });

    testWidgets(
      'a blocked mic tap (quota reached) opens the quota sheet, with no '
      'retry offered',
      (tester) async {
        final recorder = _FakeSpeechRecorder();
        final harness = AppHarness(
          signedInAs: ana,
          access: trialing,
          overrides: [
            ...gymOn(),
            speechRecorderFactoryProvider.overrideWithValue(() => recorder),
          ],
        );
        await harness.pumpApp(
          tester,
          initialLocation: AppRoutes.trainMode(TrainingMode.thinkAndSpeak),
          arrange: _planAndCompleteDiagnosis,
        );
        harness.container
            .read(micTargetRegistryProvider)
            .register(
              _FakeMicTarget(
                prompt: const MicPrompt(actionLabel: 'Grabar'),
                deliveryResult: const MicDailyLimitReached(),
              ),
              layer: MicLayer.branch,
            );
        await tester.pump();

        // One real recording cycle that reports the quota as reached,
        // latching the mic.
        final firstGesture = await tester.startGesture(
          tester.getCenter(find.byType(MicButton)),
        );
        for (var i = 0; i < 3; i++) {
          await tester.pump();
        }
        harness.clock.advance(const Duration(milliseconds: 700));
        await firstGesture.up();
        await tester.pumpAndSettle();

        // The next tap must open the quota sheet instead of starting a
        // capture. `TrainingLoopView`'s own inline status panel ALSO shows
        // this same block/message persistently (design §19.5's generic
        // "explained, blocked" rendering, U13b) — scope to the sheet
        // itself so this asserts the sheet opened, not just the panel.
        await tester.tap(find.byType(MicButton));
        await tester.pumpAndSettle();

        expect(find.byType(MicBlockedSheet), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(MicBlockedSheet),
            matching: find.text(
              'Ya usaste tus análisis de hoy. Vuelve mañana.',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(MicBlockedSheet),
            matching: find.byType(FluiButton),
          ),
          findsNothing,
        );
      },
    );
  });

  group('PROGRESO, quick practice fallback (U23e, real path)', () {
    List<Override> gymOn() => [
      speakingGymEnabledProvider.overrideWithValue(true),
    ];

    testWidgets(
      'the mic on a tab with no registered target shows the quick-practice '
      'prompt without recording; the next activation records and delivers; '
      'feedback then summary appear; the mic label is correct at each '
      'phase',
      (tester) async {
        final handle = tester.ensureSemantics();
        final recorder = _FakeSpeechRecorder();
        final harness = AppHarness(
          signedInAs: ana,
          access: trialing,
          overrides: [
            ...gymOn(),
            speechRecorderFactoryProvider.overrideWithValue(() => recorder),
          ],
        );
        await harness.pumpApp(
          tester,
          initialLocation: AppRoutes.progress,
          arrange: _planAndCompleteDiagnosis,
        );

        final controller = harness.container.read(micControllerProvider)!;

        // PROGRESO has no resolvable spoken action: the registry falls
        // through to the quick-practice fallback.
        final registry = harness.container.read(micTargetRegistryProvider);
        expect(registry.resolve().$1, isNot(isA<LoopMicTarget>()));

        // First activation: prompt-first (design §19.13/decision #450.3),
        // no capture started.
        await tester.tap(find.byType(MicButton));
        await tester.pumpAndSettle();

        expect(controller.state, isA<MicIdle>());
        expect(find.text(_l10n.quickPracticeThinkingHeadline), findsOneWidget);
        var label = tester.getSemantics(find.byType(MicButton)).label;
        expect(label, 'Responder');

        // Second activation: records and delivers for the same picked
        // challenge.
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(MicButton)),
        );
        for (var i = 0; i < 3; i++) {
          await tester.pump();
        }
        expect(controller.state, isA<MicRecording>());
        harness.clock.advance(const Duration(milliseconds: 700));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(find.text(_l10n.quickPracticeFeedbackHeadline), findsOneWidget);
        // Ready for a FRESH quick practice again, independent of the
        // panel still showing this one's feedback.
        label = tester.getSemantics(find.byType(MicButton)).label;
        expect(label, isNot('Responder'));

        await tester.tap(find.text(_l10n.loopContinueAction));
        await tester.pumpAndSettle();

        expect(find.text(_l10n.quickPracticeSummaryTitle), findsOneWidget);
        handle.dispose();
      },
    );

    testWidgets(
      'a user without access never sees the quick-practice prompt — the '
      'app-wide paywall redirect applies before the shell (and its mic) '
      'ever renders',
      (tester) async {
        final harness = AppHarness(signedInAs: ana, overrides: gymOn());
        await harness.pumpApp(tester, initialLocation: AppRoutes.progress);

        expect(location(harness), AppRoutes.paywall);
        expect(find.byType(MicButton), findsNothing);
      },
    );
  });

  group('quick-practice dismissal on navigation/registry change '
      '(orchestrator review finding, U23e real path)', () {
    List<Override> gymOn() => [
      speakingGymEnabledProvider.overrideWithValue(true),
    ];

    testWidgets(
      '1. PROGRESO mic -> prompt visible -> switch to ENTRENAR and open a '
      'mode -> the quick overlay is gone; a mic tap delivers to the '
      "loop target, not quick practice, and the mic label is the loop's "
      // HOY itself is no longer a valid quick-practice site once U15a's
      // TodayStartTarget is always registered there (design part-3
      // §11/§19.4: HOY's mic never falls back to quick practice) — this
      // scenario now anchors on PROGRESO, which never registers a target
      // of its own, same as the dedicated PROGRESO group above.
      '(PROGRESO replaces HOY as the no-target tab, U15a)',
      (tester) async {
        final recorder = _FakeSpeechRecorder();
        final harness = AppHarness(
          signedInAs: ana,
          access: trialing,
          overrides: [
            ...gymOn(),
            speechRecorderFactoryProvider.overrideWithValue(() => recorder),
          ],
        );
        await harness.pumpApp(tester, arrange: _planAndCompleteDiagnosis);
        await tester.tap(find.text('Progreso'));
        await tester.pumpAndSettle();

        // First activation on PROGRESO: the quick-practice prompt appears.
        await tester.tap(find.byType(MicButton));
        await tester.pumpAndSettle();
        expect(find.text(_l10n.quickPracticeThinkingHeadline), findsOneWidget);

        // Switch to ENTRENAR and open a mode — registers a
        // LoopMicTarget, which now wins `resolve()`.
        await tester.tap(find.text('Entrenar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Piensa y habla'));
        await tester.pumpAndSettle();

        // The quick overlay is gone — no stale prompt/think/ready text
        // anywhere in the tree.
        expect(find.text(_l10n.quickPracticeThinkingHeadline), findsNothing);
        expect(find.text(_l10n.quickPracticeReadyHint), findsNothing);

        final registry = harness.container.read(micTargetRegistryProvider);
        expect(registry.resolve().$1, isA<LoopMicTarget>());

        // A mic tap now records into the LOOP, never into quick
        // practice.
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(MicButton)),
        );
        for (var i = 0; i < 3; i++) {
          await tester.pump();
        }
        harness.clock.advance(const Duration(milliseconds: 700));
        await gesture.up();
        await tester.pumpAndSettle();

        final attempts = harness.container.read(
          speakingAttemptRepositoryProvider,
        ) as FakeSpeakingAttemptRepository;
        expect(
          attempts.attemptsForCurrentUser.last.context,
          isNot(TrainingContext.quick),
        );
        expect(find.text(_l10n.quickPracticeThinkingHeadline), findsNothing);
      },
    );

    testWidgets('2. a quick-practice delivery already past Finishing is never '
        'cancelled by an immediately-following tab switch — the attempt '
        'is saved; the overlay is dismissed once delivery settles because '
        'another target now wins (the deferred-dismissal rule itself is '
        'unit-tested exhaustively in quick_practice_target_test.dart)', (
      tester,
    ) async {
      final recorder = _FakeSpeechRecorder();
      final harness = AppHarness(
        signedInAs: ana,
        access: trialing,
        overrides: [
          ...gymOn(),
          speechRecorderFactoryProvider.overrideWithValue(() => recorder),
        ],
      );
      await harness.pumpApp(tester, arrange: _planAndCompleteDiagnosis);
      // PROGRESO (not HOY): U15a's TodayStartTarget is always registered
      // on HOY once the flag is on, so HOY is no longer a valid
      // quick-practice site — see test 1's own note above.
      await tester.tap(find.text('Progreso'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(MicButton));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(MicButton)),
      );
      for (var i = 0; i < 3; i++) {
        await tester.pump();
      }
      harness.clock.advance(const Duration(milliseconds: 700));
      await gesture.up();
      // Deliberately NO pump here: switch tabs and open a mode
      // immediately, whether or not the (zero-latency) analysis has
      // already resolved by this exact point —
      // `MicController.cancelActiveCapture` only ever cancels
      // `RequestingPermission`/`Recording`, never a capture already
      // past `Finishing`/`Delivering` (design D28), so the attempt can
      // never be lost either way.
      await tester.tap(find.text('Entrenar'));
      await tester.pump();
      await tester.tap(find.text('Piensa y habla'));
      await tester.pumpAndSettle();

      final attempts = harness.container.read(
        speakingAttemptRepositoryProvider,
      ) as FakeSpeakingAttemptRepository;
      expect(
        attempts.attemptsForCurrentUser.last.context,
        TrainingContext.quick,
      );
      // Dismissed once settled: ENTRENAR's open mode now wins
      // resolve(), so the overlay is no longer shown.
      expect(find.text(_l10n.quickPracticeFeedbackHeadline), findsNothing);
      expect(find.text(_l10n.quickPracticeSummaryTitle), findsNothing);
    });

    testWidgets(
      '3. with the prompt showing, switching away and back to PROGRESO '
      'leaves no stale panel; the next mic tap is a fresh first '
      'activation, not an immediate capture (PROGRESO replaces HOY as the '
      'no-target tab, U15a)',
      (tester) async {
        final recorder = _FakeSpeechRecorder();
        final harness = AppHarness(
          signedInAs: ana,
          access: trialing,
          overrides: [
            ...gymOn(),
            speechRecorderFactoryProvider.overrideWithValue(() => recorder),
          ],
        );
        await harness.pumpApp(tester, arrange: _planAndCompleteDiagnosis);
        await tester.tap(find.text('Progreso'));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(MicButton));
        await tester.pumpAndSettle();
        expect(find.text(_l10n.quickPracticeThinkingHeadline), findsOneWidget);

        // ENTRENAR's mode PICKER (no mode open) never registers a
        // target of its own — quick practice is STILL what resolve()
        // returns there. The route change alone must still dismiss.
        await tester.tap(find.text('Entrenar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Progreso'));
        await tester.pumpAndSettle();

        expect(find.text(_l10n.quickPracticeThinkingHeadline), findsNothing);
        expect(find.text(_l10n.quickPracticeReadyHint), findsNothing);
        final controller = harness.container.read(micControllerProvider)!;
        expect(controller.state, isA<MicIdle>());

        // The next mic tap starts a FRESH first activation, not an
        // immediate capture.
        await tester.tap(find.byType(MicButton));
        await tester.pumpAndSettle();

        expect(controller.state, isA<MicIdle>());
        expect(find.text(_l10n.quickPracticeThinkingHeadline), findsOneWidget);
      },
    );
  });

  testWidgets('category detail back restores its family filter and page', (
    tester,
  ) async {
    final theme = seedThemes.first;
    final word = seedWordsWithThemes.firstWhere(
      (word) => word.themeIds.contains(theme.id),
    );
    final harness = AppHarness(signedInAs: ana, access: trialing);
    await harness.pumpApp(
      tester,
      initialLocation: AppRoutes.categoryCatalog(theme.family.name),
      arrange: (h) => h.planToday(),
    );
    expect(location(harness), AppRoutes.categoryCatalog(theme.family.name));

    await tester.ensureVisible(find.text(theme.name));
    await tester.tap(find.text(theme.name));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(word.lemma));
    await tester.ensureVisible(find.byType(FluiCard).first);
    await tester.tap(find.byType(FluiCard).first);
    await tester.pumpAndSettle();

    final detailLocation = Uri.parse(location(harness));
    expect(detailLocation.path, AppRoutes.wordDetail(word.id));
    final returnLocation = detailLocation.queryParameters['returnTo'];
    expect(returnLocation, contains('theme=${theme.id}'));
    expect(find.text(word.lemma), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(location(harness), returnLocation);
    expect(find.text(word.lemma), findsOneWidget);
    final catalogScrollable = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );
    tester.state<ScrollableState>(catalogScrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.text(theme.name), findsOneWidget);
    expect(find.text(word.lemma), findsOneWidget);
  });

  testWidgets(
    'Words detail keeps the selected shell tab and returns to Words',
    (tester) async {
      final theme = seedThemes.first;
      final word = seedWordsWithThemes.firstWhere(
        (word) => word.themeIds.contains(theme.id),
      );
      final harness = AppHarness(signedInAs: ana, access: trialing);
      await harness.pumpApp(
        tester,
        initialLocation: AppRoutes.words,
        arrange: (harness) async {
          await harness.planToday();
          await harness.wordProgress.saveProgress(
            WordProgress.introduced(
              wordId: word.id,
              today: LocalDate.fromDateTime(harness.clock.now()),
            ),
          );
        },
      );

      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.tap(find.text(word.lemma));
      await tester.pumpAndSettle();

      expect(location(harness), AppRoutes.wordDetail(word.id));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Palabras'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(location(harness), AppRoutes.words);
      expect(find.text(word.lemma), findsOneWidget);
    },
  );

  testWidgets('direct category link back falls back to Today', (tester) async {
    final theme = seedThemes.first;
    final harness = AppHarness(signedInAs: ana, access: trialing);
    await harness.pumpApp(
      tester,
      initialLocation: AppRoutes.categoryCatalog(theme.family.name),
      arrange: (h) => h.planToday(),
    );

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(location(harness), AppRoutes.today);
  });
}
