import 'dart:async';
import 'dart:typed_data';

import 'package:flui/core/audio/application/hold_to_record.dart';
import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/audio/speech_recorder.dart';
import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/mic/mic_controller.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/core/mic/mic_target_registry.dart';
import 'package:flutter_test/flutter_test.dart';

/// A controllable [MicTarget] test double. [pendingDelivery], when set,
/// makes [deliver] hang until completed — used to exercise
/// `MicController`'s busy precedence and its "delivery survives
/// disposal" guarantee.
final class _FakeMicTarget implements MicTarget {
  new({
    MicPrompt? prompt,
    this.maxDuration = const Duration(seconds: 30),
    MicAvailability? availability,
    this.deliveryResult = const MicAccepted(),
  }) : prompt = prompt ?? const MicPrompt(actionLabel: 'Grabar'),
       _availability = availability ?? const MicReady();

  @override
  final MicPrompt prompt;

  @override
  final Duration maxDuration;

  MicAvailability _availability;

  @override
  MicAvailability get availability => _availability;

  set availability(MicAvailability value) => _availability = value;

  MicDelivery deliveryResult;
  Completer<MicDelivery>? pendingDelivery;
  int deliverCalls = 0;
  RecordedAudio? lastDelivered;

  final _changesController = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changesController.stream;

  @override
  Future<MicDelivery> deliver(RecordedAudio audio) async {
    deliverCalls++;
    lastDelivered = audio;
    final pending = pendingDelivery;
    if (pending != null) return await pending.future;
    return deliveryResult;
  }
}

/// Ported from `hold_to_record_test.dart`'s fake, minus the U23a-specific
/// controllable completers this unit does not need. [permission] is
/// mutable so a test can flip it after `MicController` has already
/// captured this exact instance via its `recorderFactory`.
final class _FakeSpeechRecorder implements SpeechRecorder {
  new({this.permission = true});

  bool permission;
  int starts = 0;
  int stops = 0;

  @override
  Stream<double> get amplitude => const Stream.empty();

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<void> start() async => starts++;

  @override
  Future<Uint8List> stop() async {
    stops++;
    return Uint8List.fromList(const [1, 2, 3]);
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}

Future<void> _flush() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  MicController build({
    Clock? clock,
    MicTargetRegistry? registry,
    SpeechRecorder Function()? recorderFactory,
  }) {
    final controller = MicController(
      recorderFactory: recorderFactory ?? _FakeSpeechRecorder.new,
      registry: registry ?? MicTargetRegistry(),
      clock: clock ?? const SystemClock(),
    )..setAccessGranted(true);
    return controller;
  }

  /// Starts a toggled recording and stops it once [clock] has advanced
  /// past `HoldToRecord`'s default 600ms minDuration, so the capture
  /// actually finishes and reaches delivery instead of being discarded.
  Future<void> recordAndDeliver(
    MicController controller,
    FixedClock clock,
  ) async {
    controller.toggle();
    await _flush();
    clock.advance(const Duration(milliseconds: 700));
    controller.toggle();
    await _flush();
  }

  group('precedence: busy > access > quota > permission > target', () {
    test('a pending delivery (busy) blocks a new gesture even when other '
        'latches are also active, emitting only a busy notice', () async {
      final clock = FixedClock(DateTime(2026));
      final registry = MicTargetRegistry();
      final target = _FakeMicTarget()
        ..pendingDelivery = Completer<MicDelivery>();
      registry.register(target, layer: MicLayer.branch);
      final controller = build(registry: registry, clock: clock);
      addTearDown(controller.dispose);

      await recordAndDeliver(controller, clock);
      expect(controller.state, isA<MicDelivering>());

      controller.setAccessGranted(false);
      final notices = <MicNotice>[];
      controller.notices.listen(notices.add);

      controller.toggle();
      await _flush();

      expect(notices, [MicNotice.busy]);
      expect(target.deliverCalls, 1);
      expect(controller.state, isA<MicDelivering>());

      target.pendingDelivery!.complete(const MicAccepted());
      await _flush();
    });

    test('an access latch shows its own explanation ahead of the target '
        'itself being blocked', () async {
      final registry = MicTargetRegistry()
        ..register(
          _FakeMicTarget(availability: const MicBlocked('target blocked')),
          layer: MicLayer.branch,
        );
      final controller = build(registry: registry);
      addTearDown(controller.dispose);
      controller
        ..setAccessGranted(false)
        ..toggle();
      await _flush();

      final block = (controller.state as MicIdle).block;
      expect(block?.message, contains('Reactiva'));
    });

    test('a quota latch shows its own explanation ahead of a permission '
        'latch or the target itself being blocked', () async {
      final clock = FixedClock(DateTime.utc(2026));
      final registry = MicTargetRegistry();
      final target = _FakeMicTarget(
        deliveryResult: const MicDailyLimitReached(),
      );
      registry.register(target, layer: MicLayer.branch);
      final controller = build(registry: registry, clock: clock);
      addTearDown(controller.dispose);

      await recordAndDeliver(controller, clock);
      expect(
        (controller.state as MicIdle).block?.message,
        contains('Vuelve mañana'),
      );

      // A blocked target and a denied-permission recorder are ALSO now
      // present, but the quota latch (checked first) must still win.
      target.availability = const MicBlocked('target blocked');
      controller.toggle();
      await _flush();

      expect(
        (controller.state as MicIdle).block?.message,
        contains('Vuelve mañana'),
      );
    });

    test('a permission latch shows its own explanation ahead of the target '
        'itself being blocked', () async {
      final registry = MicTargetRegistry();
      final target = _FakeMicTarget();
      registry.register(target, layer: MicLayer.branch);
      final recorder = _FakeSpeechRecorder(permission: false);
      final controller = build(
        registry: registry,
        recorderFactory: () => recorder,
      );
      addTearDown(controller.dispose);

      controller.toggle();
      await _flush();
      expect(
        (controller.state as MicIdle).block?.message,
        contains('micrófono'),
      );

      target.availability = const MicBlocked('target blocked');
      controller.toggle();
      await _flush();

      expect(
        (controller.state as MicIdle).block?.message,
        contains('micrófono'),
      );
    });

    test(
      'with no latch active, a blocked target surfaces its own message',
      () async {
        final registry = MicTargetRegistry()
          ..register(
            _FakeMicTarget(
              availability: const MicBlocked('Elige un reto en Entrenar.'),
            ),
            layer: MicLayer.branch,
          );
        final controller = build(registry: registry);
        addTearDown(controller.dispose);

        controller.toggle();
        await _flush();

        expect(
          (controller.state as MicIdle).block?.message,
          'Elige un reto en Entrenar.',
        );
      },
    );

    test('with no latch active, a busy target emits a busy notice instead of '
        'starting a capture', () async {
      final registry = MicTargetRegistry()
        ..register(
          _FakeMicTarget(availability: const MicBusy('Analizando')),
          layer: MicLayer.branch,
        );
      final controller = build(registry: registry);
      addTearDown(controller.dispose);
      final notices = <MicNotice>[];
      controller.notices.listen(notices.add);

      controller.toggle();
      await _flush();

      expect(notices, [MicNotice.busy]);
      expect(controller.state, isA<MicIdle>());
    });
  });

  group('toggle path reaches the identical flow as the pointer path', () {
    test(
      'pointerDown is blocked by the exact same latches as toggle',
      () async {
        final registry = MicTargetRegistry()
          ..register(_FakeMicTarget(), layer: MicLayer.branch);
        final controller = build(registry: registry);
        addTearDown(controller.dispose);
        controller
          ..setAccessGranted(false)
          ..pointerDown();
        await _flush();

        expect(
          (controller.state as MicIdle).block?.message,
          contains('Reactiva'),
        );
        expect(controller.state, isNot(isA<MicRequestingPermission>()));
      },
    );

    test('a toggle-started recording reports CaptureMode.toggled and the '
        "target's own maxDuration", () async {
      final registry = MicTargetRegistry()
        ..register(
          _FakeMicTarget(maxDuration: const Duration(seconds: 45)),
          layer: MicLayer.branch,
        );
      final controller = build(registry: registry);
      addTearDown(controller.dispose);

      controller.toggle();
      await _flush();

      expect(controller.state, isA<MicRecording>());
      expect((controller.state as MicRecording).mode, CaptureMode.toggled);
      expect((controller.state as MicRecording).maxSeconds, 45);
    });
  });

  group('MicPrepare (D40)', () {
    test('the first activation awaits onActivate with no capture; the '
        'following pointerUp is a no-op', () async {
      final registry = MicTargetRegistry();
      var activated = false;
      final target = _FakeMicTarget(
        availability: MicPrepare('Practicar', () async {
          activated = true;
        }),
      );
      registry.register(target, layer: MicLayer.branch);
      final controller = build(registry: registry);
      addTearDown(controller.dispose);

      controller.pointerDown();
      await _flush();

      expect(activated, isTrue);
      expect(controller.state, isA<MicIdle>());
      expect(target.deliverCalls, 0);

      controller.pointerUp();
      await _flush();

      expect(controller.state, isA<MicIdle>());
      expect(target.deliverCalls, 0);
    });
  });

  group('quota latch clears on UTC date change', () {
    test('a daily-limit-reached delivery latches the mic for the rest of the '
        'UTC date, clearing once the date changes', () async {
      final clock = FixedClock(DateTime.utc(2026, 1, 1, 23));
      final registry = MicTargetRegistry()
        ..register(
          _FakeMicTarget(deliveryResult: const MicDailyLimitReached()),
          layer: MicLayer.branch,
        );
      final controller = build(registry: registry, clock: clock);
      addTearDown(controller.dispose);

      await recordAndDeliver(controller, clock);
      expect(
        (controller.state as MicIdle).block?.message,
        contains('Vuelve mañana'),
      );

      clock.advance(const Duration(minutes: 30));
      controller.toggle();
      await _flush();
      expect(
        (controller.state as MicIdle).block?.message,
        contains('Vuelve mañana'),
      );

      clock.advance(const Duration(hours: 1));
      controller.toggle();
      await _flush();

      expect(controller.state, isA<MicRecording>());
    });
  });

  group('permission latch clears on the next successful capture start', () {
    test('an ordinary toggle stays blocked, but retryPermission (the '
        '"Intentar de nuevo" CTA) re-attempts and clears the latch on '
        'success', () async {
      final registry = MicTargetRegistry()
        ..register(_FakeMicTarget(), layer: MicLayer.branch);
      final recorder = _FakeSpeechRecorder(permission: false);
      final controller = build(
        registry: registry,
        recorderFactory: () => recorder,
      );
      addTearDown(controller.dispose);

      controller.toggle();
      await _flush();
      expect(
        (controller.state as MicIdle).block?.message,
        contains('micrófono'),
      );

      // An ordinary gesture alone never clears a permission latch.
      recorder.permission = true;
      controller.toggle();
      await _flush();
      expect(
        (controller.state as MicIdle).block?.message,
        contains('micrófono'),
      );

      controller.retryPermission();
      await _flush();

      expect(controller.state, isA<MicRecording>());
    });
  });

  group('access latch clears on granted', () {
    test('setAccessGranted(true) clears an access-required latch', () async {
      final clock = FixedClock(DateTime(2026));
      final registry = MicTargetRegistry()
        ..register(
          _FakeMicTarget(deliveryResult: const MicAccessRequired()),
          layer: MicLayer.branch,
        );
      final controller = build(registry: registry, clock: clock);
      addTearDown(controller.dispose);

      await recordAndDeliver(controller, clock);
      expect(
        (controller.state as MicIdle).block?.message,
        contains('Reactiva'),
      );

      controller.setAccessGranted(true);

      expect(controller.state, isA<MicIdle>());
      expect((controller.state as MicIdle).block, isNull);
    });
  });

  group('in-flight delivery survives registration disposal', () {
    test(
      'delivery still reaches the bound target after its registration is '
      'disposed mid-analysis (never cancelled here — that is U23d)',
      () async {
        final clock = FixedClock(DateTime(2026));
        final registry = MicTargetRegistry();
        final target = _FakeMicTarget()
          ..pendingDelivery = Completer<MicDelivery>();
        final registration = registry.register(target, layer: MicLayer.branch);
        final controller = build(registry: registry, clock: clock);
        addTearDown(controller.dispose);

        controller.toggle();
        await _flush();
        clock.advance(const Duration(milliseconds: 700));
        controller.toggle();
        await _flush();
        expect(controller.state, isA<MicDelivering>());

        registration.dispose();

        target.pendingDelivery!.complete(const MicAccepted());
        await _flush();

        expect(target.deliverCalls, 1);
        expect(controller.state, isA<MicIdle>());
      },
    );
  });

  group('notices', () {
    test('a below-minDuration release emits tooShort', () async {
      final clock = FixedClock(DateTime(2026));
      final registry = MicTargetRegistry()
        ..register(_FakeMicTarget(), layer: MicLayer.branch);
      final controller = build(registry: registry, clock: clock);
      addTearDown(controller.dispose);
      final notices = <MicNotice>[];
      controller.notices.listen(notices.add);

      controller.toggle();
      await _flush();
      controller.toggle();
      await _flush();

      expect(notices, [MicNotice.tooShort]);
    });

    test('a failed delivery emits deliveryFailed', () async {
      final clock = FixedClock(DateTime(2026));
      final registry = MicTargetRegistry()
        ..register(
          _FakeMicTarget(deliveryResult: const MicDeliveryFailed('boom')),
          layer: MicLayer.branch,
        );
      final controller = build(registry: registry, clock: clock);
      addTearDown(controller.dispose);
      final notices = <MicNotice>[];
      controller.notices.listen(notices.add);

      await recordAndDeliver(controller, clock);

      expect(notices, [MicNotice.deliveryFailed]);
    });

    test('a denied permission emits permissionDenied, distinct from tooShort '
        'or deliveryFailed', () async {
      final registry = MicTargetRegistry()
        ..register(_FakeMicTarget(), layer: MicLayer.branch);
      final controller = build(
        registry: registry,
        recorderFactory: () => _FakeSpeechRecorder(permission: false),
      );
      addTearDown(controller.dispose);
      final notices = <MicNotice>[];
      controller.notices.listen(notices.add);

      controller.toggle();
      await _flush();

      expect(notices, [MicNotice.permissionDenied]);
    });
  });
}
