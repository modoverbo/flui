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
import 'package:flui/core/mic/mic_controller.dart';
import 'package:flui/core/mic/mic_providers.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/core/mic/presentation/mic_blocked_sheet.dart';
import 'package:flui/core/mic/presentation/mic_button.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/features/auth/domain/app_user.dart';
import 'package:flui/features/daily/presentation/providers/daily_providers.dart';
import 'package:flui/features/subscription/domain/access_status.dart';
import 'package:flui/features/themes/data/fake/seed_themes.dart';
import 'package:flui/features/training/domain/training_mode.dart';
import 'package:flui/features/training/presentation/controllers/loop_mic_target.dart';
import 'package:flui/features/vocabulary/domain/word_progress.dart';
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

  @override
  Stream<double> get amplitude => const Stream.empty();

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> start() async {}

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
        arrange: (h) => h.planToday(),
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
      await harness.pumpApp(tester, arrange: (h) => h.planToday());

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
          arrange: (h) => h.planToday(),
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
          arrange: (h) => h.planToday(),
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
        await harness.pumpApp(tester, arrange: (h) => h.planToday());
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
          arrange: (h) => h.planToday(),
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
          arrange: (h) => h.planToday(),
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
        arrange: (h) => h.planToday(),
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
          arrange: (h) => h.planToday(),
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
