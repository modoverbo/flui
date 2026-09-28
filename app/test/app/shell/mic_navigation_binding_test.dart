import 'dart:async';
import 'dart:typed_data';

import 'package:flui/app/shell/mic_navigation_binding.dart';
import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/audio/speech_recorder.dart';
import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/mic/mic_controller.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/core/mic/mic_target_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ported from `mic_controller_test.dart`'s fakes.
final class _FakeMicTarget implements MicTarget {
  new({MicAvailability? availability})
    : _availability = availability ?? const MicReady();

  @override
  final MicPrompt prompt = const MicPrompt(actionLabel: 'Grabar');

  @override
  final Duration maxDuration = const Duration(seconds: 30);

  final MicAvailability _availability;

  @override
  MicAvailability get availability => _availability;

  final _changesController = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changesController.stream;

  Completer<MicDelivery>? pendingDelivery;
  int deliverCalls = 0;

  @override
  Future<MicDelivery> deliver(RecordedAudio audio) async {
    deliverCalls++;
    final pending = pendingDelivery;
    if (pending != null) return await pending.future;
    return const MicAccepted();
  }
}

final class _FakeSpeechRecorder implements SpeechRecorder {
  new({this.permissionResult});

  /// When set, [requestPermission] awaits this instead of resolving
  /// immediately, so a test can hold the controller in
  /// `MicRequestingPermission` deliberately.
  final Completer<bool>? permissionResult;

  @override
  Stream<double> get amplitude => const Stream.empty();

  @override
  Future<bool> requestPermission() async {
    final pending = permissionResult;
    if (pending != null) return await pending.future;
    return true;
  }

  @override
  Future<void> start() async {}

  @override
  Future<Uint8List> stop() async => Uint8List.fromList(const [1, 2, 3]);

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}

/// A minimal fake router surface: a `ChangeNotifier` [go] flips, mirroring
/// `GoRouter.routerDelegate`'s own shape (`Listenable` + current location).
final class _FakeRouterLocationSource extends ChangeNotifier
    implements MicRouterLocationSource {
  Uri _location = Uri.parse('/today');

  @override
  Listenable get listenable => this;

  @override
  Uri get location => _location;

  void go(String path) {
    _location = Uri.parse(path);
    notifyListeners();
  }
}

/// `testWidgets` runs under `AutomatedTestWidgetsFlutterBinding`'s fake
/// clock — `Future.delayed`/real `Timer`s never fire without a `pump()`
/// (unlike `mic_controller_test.dart`'s plain `test()`, which needs no
/// pumping at all).
Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  late FixedClock clock;
  late MicTargetRegistry registry;
  late MicController controller;
  late _FakeRouterLocationSource router;
  late MicNavigationBinding binding;

  MicController buildController({SpeechRecorder Function()? recorderFactory}) =>
      MicController(
        recorderFactory: recorderFactory ?? _FakeSpeechRecorder.new,
        registry: registry,
        clock: clock,
      )..setAccessGranted(true);

  MicNavigationBinding buildBinding() => MicNavigationBinding(
    registry: registry,
    controllerOf: () => controller,
    routerSource: router,
  );

  setUp(() {
    clock = FixedClock(DateTime(2026));
    registry = MicTargetRegistry();
    router = _FakeRouterLocationSource();
  });

  group('router path change (tab switch, push, pop, redirect)', () {
    testWidgets(
      'cancels an active Recording immediately with cancelledByNavigation',
      (tester) async {
        registry.register(_FakeMicTarget(), layer: MicLayer.branch);
        controller = buildController();
        addTearDown(() => unawaited(controller.dispose()));
        binding = buildBinding();
        addTearDown(binding.dispose);
        final notices = <MicNotice>[];
        controller.notices.listen(notices.add);

        controller.toggle();
        await _flush(tester);
        expect(controller.state, isA<MicRecording>());

        router.go('/train');
        await _flush(tester);

        expect(controller.state, isA<MicIdle>());
        expect(notices, [MicNotice.cancelledByNavigation]);
      },
    );

    testWidgets('cancels a capture still stuck in RequestingPermission', (
      tester,
    ) async {
      registry.register(_FakeMicTarget(), layer: MicLayer.branch);
      final permissionResult = Completer<bool>();
      controller = buildController(
        recorderFactory: () =>
            _FakeSpeechRecorder(permissionResult: permissionResult),
      );
      addTearDown(() => unawaited(controller.dispose()));
      binding = buildBinding();
      addTearDown(binding.dispose);
      final notices = <MicNotice>[];
      controller.notices.listen(notices.add);

      controller.toggle();
      await _flush(tester);
      expect(controller.state, isA<MicRequestingPermission>());

      router.go('/train');
      await _flush(tester);

      expect(controller.state, isA<MicIdle>());
      expect(notices, [MicNotice.cancelledByNavigation]);
      permissionResult.complete(true);
      await _flush(tester);
    });

    testWidgets('never cancels an in-flight delivery', (tester) async {
      final target = _FakeMicTarget()
        ..pendingDelivery = Completer<MicDelivery>();
      registry.register(target, layer: MicLayer.branch);
      controller = buildController();
      addTearDown(() => unawaited(controller.dispose()));
      binding = buildBinding();
      addTearDown(binding.dispose);

      controller.toggle();
      await _flush(tester);
      clock.advance(const Duration(milliseconds: 700));
      controller.toggle();
      await _flush(tester);
      expect(controller.state, isA<MicDelivering>());

      router.go('/train');
      await _flush(tester);

      expect(controller.state, isA<MicDelivering>());
      target.pendingDelivery!.complete(const MicAccepted());
      await _flush(tester);
      expect(target.deliverCalls, 1);
    });

    testWidgets('a location change to the SAME uri never cancels', (
      tester,
    ) async {
      registry.register(_FakeMicTarget(), layer: MicLayer.branch);
      controller = buildController();
      addTearDown(() => unawaited(controller.dispose()));
      binding = buildBinding();
      addTearDown(binding.dispose);
      final notices = <MicNotice>[];
      controller.notices.listen(notices.add);

      controller.toggle();
      await _flush(tester);

      router.go('/today');
      await _flush(tester);

      expect(controller.state, isA<MicRecording>());
      expect(notices, isEmpty);

      // Cleanup: stop the still-active recording so no countdown Timer is
      // left pending once the test ends.
      controller.cancelActiveCapture();
      await _flush(tester);
    });
  });

  group('bound registration disposed or no longer resolved', () {
    testWidgets(
      'a new top-of-stack registration cancels an active Recording bound to '
      'the entry it displaced, with no router change at all',
      (tester) async {
        registry.register(_FakeMicTarget(), layer: MicLayer.branch);
        controller = buildController();
        addTearDown(() => unawaited(controller.dispose()));
        binding = buildBinding();
        addTearDown(binding.dispose);
        final notices = <MicNotice>[];
        controller.notices.listen(notices.add);

        controller.toggle();
        await _flush(tester);
        expect(controller.state, isA<MicRecording>());

        // Steals the top of the stack without any router navigation, e.g.
        // a modal registering its own target.
        registry.register(_FakeMicTarget(), layer: MicLayer.branch);
        await _flush(tester);

        expect(controller.state, isA<MicIdle>());
        expect(notices, [MicNotice.cancelledByNavigation]);
      },
    );

    testWidgets(
      'a registry change while idle never cancels (nothing to cancel) and '
      'never double-emits a notice',
      (tester) async {
        registry.register(_FakeMicTarget(), layer: MicLayer.branch);
        controller = buildController();
        addTearDown(() => unawaited(controller.dispose()));
        binding = buildBinding();
        addTearDown(binding.dispose);
        final notices = <MicNotice>[];
        controller.notices.listen(notices.add);

        registry.register(_FakeMicTarget(), layer: MicLayer.branch);
        await _flush(tester);
        registry.register(_FakeMicTarget(), layer: MicLayer.branch);
        await _flush(tester);

        expect(notices, isEmpty);
        expect(controller.state, isA<MicIdle>());
      },
    );
  });

  group('app lifecycle hide/pause — deferred cancelledByBackground', () {
    testWidgets(
      'hidden cancels an active Recording silently; cancelledByBackground '
      'shows only once the app resumes',
      (tester) async {
        registry.register(_FakeMicTarget(), layer: MicLayer.branch);
        controller = buildController();
        addTearDown(() => unawaited(controller.dispose()));
        binding = buildBinding();
        addTearDown(binding.dispose);
        final notices = <MicNotice>[];
        controller.notices.listen(notices.add);

        controller.toggle();
        await _flush(tester);
        expect(controller.state, isA<MicRecording>());

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        await _flush(tester);

        expect(controller.state, isA<MicIdle>());
        expect(notices, isEmpty);

        // `AppLifecycleListener` only permits entering `resumed` FROM
        // `inactive`/`detached`/null — matching the real OS transition
        // sequence coming back to the foreground.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await _flush(tester);

        expect(notices, [MicNotice.cancelledByBackground]);
      },
    );

    testWidgets('paused (mobile background) behaves the same as hidden', (
      tester,
    ) async {
      registry.register(_FakeMicTarget(), layer: MicLayer.branch);
      controller = buildController();
      addTearDown(() => unawaited(controller.dispose()));
      binding = buildBinding();
      addTearDown(binding.dispose);
      final notices = <MicNotice>[];
      controller.notices.listen(notices.add);

      controller.toggle();
      await _flush(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await _flush(tester);
      expect(controller.state, isA<MicIdle>());
      expect(notices, isEmpty);

      // The real OS sequence back to the foreground from paused passes
      // through hidden then inactive before resumed.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _flush(tester);
      expect(notices, [MicNotice.cancelledByBackground]);
    });

    testWidgets(
      'inactive (a transient system dialog) NEVER cancels a Recording',
      (tester) async {
        registry.register(_FakeMicTarget(), layer: MicLayer.branch);
        controller = buildController();
        addTearDown(() => unawaited(controller.dispose()));
        binding = buildBinding();
        addTearDown(binding.dispose);

        controller.toggle();
        await _flush(tester);
        expect(controller.state, isA<MicRecording>());

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await _flush(tester);

        expect(controller.state, isA<MicRecording>());

        // Cleanup: stop the still-active recording so no countdown Timer
        // is left pending once the test ends.
        controller.cancelActiveCapture();
        await _flush(tester);
      },
    );

    testWidgets('never cancels an in-flight delivery', (tester) async {
      final target = _FakeMicTarget()
        ..pendingDelivery = Completer<MicDelivery>();
      registry.register(target, layer: MicLayer.branch);
      controller = buildController();
      addTearDown(() => unawaited(controller.dispose()));
      binding = buildBinding();
      addTearDown(binding.dispose);

      controller.toggle();
      await _flush(tester);
      clock.advance(const Duration(milliseconds: 700));
      controller.toggle();
      await _flush(tester);
      expect(controller.state, isA<MicDelivering>());

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await _flush(tester);

      expect(controller.state, isA<MicDelivering>());
      target.pendingDelivery!.complete(const MicAccepted());
      await _flush(tester);
    });
  });

  testWidgets('with no signed-in controller yet, every trigger is a silent '
      'no-op', (tester) async {
    controller = buildController();
    unawaited(controller.dispose());
    MicController? nullController;
    binding = MicNavigationBinding(
      registry: registry,
      controllerOf: () => nullController,
      routerSource: router,
    );
    addTearDown(binding.dispose);

    router.go('/train');
    await _flush(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await _flush(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _flush(tester);
    registry.register(_FakeMicTarget(), layer: MicLayer.branch);
    await _flush(tester);
    // No crash is the assertion.
  });
}
