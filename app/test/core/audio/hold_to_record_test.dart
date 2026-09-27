import 'dart:async';
import 'dart:typed_data';

import 'package:flui/core/audio/application/hold_to_record.dart';
import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/audio/speech_recorder.dart';
import 'package:flui/core/clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ported from `speaking_challenge_page_test.dart`'s `FakeSpeechRecorder`:
/// same controllable permission/start completers, now exercised directly
/// against [HoldToRecord] instead of through a widget. [permissionResult]
/// and [stopResult] additionally let U23a's gesture-matrix tests pause mid
/// `RequestingPermission`/`Finishing` to prove events arriving there are
/// handled/ignored correctly; [amplitudeAccessCount] and [emitAmplitude]
/// let the `levels` stream tests prove a single subscription is opened per
/// recording (D45).
final class _FakeSpeechRecorder implements SpeechRecorder {
  new({
    this.permission = true,
    this.startResult,
    this.permissionResult,
    this.stopResult,
  });

  final bool permission;
  final Completer<void>? startResult;
  final Completer<bool>? permissionResult;
  final Completer<void>? stopResult;
  final events = <String>[];
  int permissionRequests = 0;
  int starts = 0;
  int stops = 0;
  int cancellations = 0;
  int amplitudeAccessCount = 0;
  final _amplitudeController = StreamController<double>.broadcast();

  void emitAmplitude(double value) => _amplitudeController.add(value);

  @override
  Stream<double> get amplitude {
    amplitudeAccessCount++;
    return _amplitudeController.stream;
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionResult == null
        ? permission
        : await permissionResult!.future;
  }

  @override
  Future<void> start() async {
    starts++;
    events.add('start-requested');
    await startResult?.future;
    events.add('start-completed');
  }

  @override
  Future<Uint8List> stop() async {
    stops++;
    await stopResult?.future;
    return Uint8List.fromList(const [1, 2, 3]);
  }

  @override
  Future<void> cancel() async {
    cancellations++;
    events.add('cancel');
  }

  @override
  Future<void> dispose() async {
    events.add('dispose');
    await _amplitudeController.close();
  }
}

/// Flushes the microtask queue (as many hops as our async chains use) so
/// fire-and-forget async chains (`press()`/`pointerDown()`/`_finish()`)
/// settle before assertions.
Future<void> _flush() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  HoldToRecord build(
    SpeechRecorder recorder, {
    Clock? clock,
    Duration minDuration = const Duration(milliseconds: 600),
    Duration maxDuration = const Duration(seconds: 45),
  }) => HoldToRecord(
    recorder,
    minDuration: minDuration,
    maxDuration: maxDuration,
    clock: clock ?? const SystemClock(),
  );

  test('cancel requested while start is still pending leaves the final state '
      'not-recording with no orphaned capture stream', () async {
    final startResult = Completer<void>();
    final recorder = _FakeSpeechRecorder(startResult: startResult);
    final holdToRecord = build(recorder);
    addTearDown(holdToRecord.dispose);

    holdToRecord.press();
    await _flush();
    expect(recorder.events, ['start-requested']);

    holdToRecord.cancel();
    expect(holdToRecord.state, isA<HoldToRecordIdle>());

    startResult.complete();
    await _flush();

    expect(recorder.events, ['start-requested', 'start-completed', 'cancel']);
    expect(holdToRecord.state, isA<HoldToRecordIdle>());
  });

  test('a second start requested while a recording is already active is '
      'rejected, leaving the original recording unaffected', () async {
    final recorder = _FakeSpeechRecorder();
    final holdToRecord = build(recorder);
    addTearDown(holdToRecord.dispose);

    holdToRecord.press();
    await _flush();
    expect(holdToRecord.state, isA<HoldToRecordRecording>());

    holdToRecord.press();
    await _flush();

    expect(recorder.starts, 1);
    expect(holdToRecord.state, isA<HoldToRecordRecording>());
  });

  test('releasing before the minimum duration cancels and discards the '
      'recording instead of producing an analyzable attempt', () async {
    final clock = FixedClock(DateTime(2026));
    final recorder = _FakeSpeechRecorder();
    final holdToRecord = build(recorder, clock: clock);
    addTearDown(holdToRecord.dispose);

    holdToRecord.press();
    await _flush();
    expect(holdToRecord.state, isA<HoldToRecordRecording>());

    holdToRecord.release();
    await _flush();

    expect(recorder.cancellations, 1);
    expect(recorder.stops, 0);
    expect(holdToRecord.state, isA<HoldToRecordIdle>());
  });

  test('a hold auto-finishes once the maximum duration elapses, without '
      'requiring a release', () async {
    final recorder = _FakeSpeechRecorder();
    final holdToRecord = build(
      recorder,
      maxDuration: const Duration(seconds: 1),
    );
    addTearDown(holdToRecord.dispose);

    holdToRecord.press();
    await _flush();
    expect(holdToRecord.state, isA<HoldToRecordRecording>());

    await Future<void>.delayed(const Duration(milliseconds: 1200));

    expect(recorder.stops, 1);
    expect(holdToRecord.state, isA<HoldToRecordFinished>());
    expect(
      (holdToRecord.state as HoldToRecordFinished).audio,
      isA<RecordedAudio>(),
    );
  });

  test('permission denial surfaces the denied state without starting the '
      'recorder or stalling indefinitely', () async {
    final recorder = _FakeSpeechRecorder(permission: false);
    final holdToRecord = build(recorder);
    addTearDown(holdToRecord.dispose);

    holdToRecord.press();
    await _flush();

    expect(recorder.permissionRequests, 1);
    expect(recorder.starts, 0);
    expect(holdToRecord.state, isA<HoldToRecordDenied>());
  });

  group('tap-vs-hold classification (pointerDown/pointerUp, U23a)', () {
    test('a quick release before tapThreshold latches to a toggled '
        'recording instead of stopping it', () async {
      final clock = FixedClock(DateTime(2026));
      final recorder = _FakeSpeechRecorder();
      final holdToRecord = build(recorder, clock: clock);
      addTearDown(holdToRecord.dispose);

      holdToRecord.pointerDown();
      await _flush();
      expect(holdToRecord.state, isA<HoldToRecordRecording>());
      expect(
        (holdToRecord.state as HoldToRecordRecording).mode,
        CaptureMode.held,
      );

      holdToRecord.pointerUp();

      expect(holdToRecord.state, isA<HoldToRecordRecording>());
      expect(
        (holdToRecord.state as HoldToRecordRecording).mode,
        CaptureMode.toggled,
      );
      expect(recorder.stops, 0);
    });

    test('the next pointer-down while a toggled recording is active stops '
        'it', () async {
      final clock = FixedClock(DateTime(2026));
      final recorder = _FakeSpeechRecorder();
      final holdToRecord = build(recorder, clock: clock);
      addTearDown(holdToRecord.dispose);

      holdToRecord.pointerDown();
      await _flush();
      holdToRecord.pointerUp();
      clock.advance(const Duration(milliseconds: 700));

      holdToRecord.pointerDown();
      await _flush();

      expect(recorder.stops, 1);
      expect(holdToRecord.state, isA<HoldToRecordFinished>());
    });

    test('a release at or after tapThreshold but below minDuration still '
        'discards, marked tooShort', () async {
      final clock = FixedClock(DateTime(2026));
      final recorder = _FakeSpeechRecorder();
      final holdToRecord = build(recorder, clock: clock);
      addTearDown(holdToRecord.dispose);

      holdToRecord.pointerDown();
      await _flush();
      clock.advance(const Duration(milliseconds: 400));

      holdToRecord.pointerUp();
      await _flush();

      expect(recorder.stops, 0);
      expect(recorder.cancellations, 1);
      expect(holdToRecord.state, isA<HoldToRecordIdle>());
      expect((holdToRecord.state as HoldToRecordIdle).tooShort, isTrue);
    });

    test('a release at or after both tapThreshold and minDuration finalizes '
        'the attempt as a normal hold-stop', () async {
      final clock = FixedClock(DateTime(2026));
      final recorder = _FakeSpeechRecorder();
      final holdToRecord = build(recorder, clock: clock);
      addTearDown(holdToRecord.dispose);

      holdToRecord.pointerDown();
      await _flush();
      clock.advance(const Duration(milliseconds: 700));

      holdToRecord.pointerUp();
      await _flush();

      expect(recorder.stops, 1);
      expect(holdToRecord.state, isA<HoldToRecordFinished>());
    });

    test('a double-tap whose total elapsed stays below minDuration discards '
        'as tooShort instead of finalizing', () async {
      final clock = FixedClock(DateTime(2026));
      final recorder = _FakeSpeechRecorder();
      final holdToRecord = build(recorder, clock: clock);
      addTearDown(holdToRecord.dispose);

      holdToRecord.pointerDown();
      await _flush();
      holdToRecord
        ..pointerUp()
        ..pointerDown();
      await _flush();

      expect(recorder.stops, 0);
      expect(recorder.cancellations, 1);
      expect(holdToRecord.state, isA<HoldToRecordIdle>());
      expect((holdToRecord.state as HoldToRecordIdle).tooShort, isTrue);
    });
  });

  group('pointerCancel and the first-use permission prompt (R13, U23a)', () {
    test('pointerCancel while RequestingPermission behaves as pointerUp, '
        'latching to a toggled recording once permission resolves', () async {
      final clock = FixedClock(DateTime(2026));
      final permissionResult = Completer<bool>();
      final recorder = _FakeSpeechRecorder(permissionResult: permissionResult);
      final holdToRecord = build(recorder, clock: clock);
      addTearDown(holdToRecord.dispose);

      holdToRecord.pointerDown();
      await _flush();
      expect(holdToRecord.state, isA<HoldToRecordRequestingPermission>());

      holdToRecord.pointerCancel();
      expect(holdToRecord.state, isA<HoldToRecordRequestingPermission>());
      expect(recorder.cancellations, 0);

      permissionResult.complete(true);
      await _flush();

      expect(holdToRecord.state, isA<HoldToRecordRecording>());
      expect(
        (holdToRecord.state as HoldToRecordRecording).mode,
        CaptureMode.toggled,
      );

      clock.advance(const Duration(milliseconds: 700));
      holdToRecord.pointerDown();
      await _flush();

      expect(recorder.stops, 1);
      expect(holdToRecord.state, isA<HoldToRecordFinished>());
    });

    test('pointerCancel while actively recording discards outright', () async {
      final recorder = _FakeSpeechRecorder();
      final holdToRecord = build(recorder);
      addTearDown(holdToRecord.dispose);

      holdToRecord.pointerDown();
      await _flush();
      expect(holdToRecord.state, isA<HoldToRecordRecording>());

      holdToRecord.pointerCancel();

      expect(recorder.cancellations, 1);
      expect(recorder.stops, 0);
      expect(holdToRecord.state, isA<HoldToRecordIdle>());
    });
  });

  group('toggle (keyboard/switch-access/screen-reader, D44, U23a)', () {
    test('toggle from idle starts a toggled recording', () async {
      final recorder = _FakeSpeechRecorder();
      final holdToRecord = build(recorder);
      addTearDown(holdToRecord.dispose);

      holdToRecord.toggle();
      await _flush();

      expect(holdToRecord.state, isA<HoldToRecordRecording>());
      expect(
        (holdToRecord.state as HoldToRecordRecording).mode,
        CaptureMode.toggled,
      );
    });

    test('a second toggle while recording stops it', () async {
      final clock = FixedClock(DateTime(2026));
      final recorder = _FakeSpeechRecorder();
      final holdToRecord = build(recorder, clock: clock);
      addTearDown(holdToRecord.dispose);

      holdToRecord.toggle();
      await _flush();
      clock.advance(const Duration(milliseconds: 700));

      holdToRecord.toggle();
      await _flush();

      expect(recorder.stops, 1);
      expect(holdToRecord.state, isA<HoldToRecordFinished>());
    });
  });

  group('stop() and per-capture max duration (U23a)', () {
    test('stop() while idle is a no-op', () {
      final recorder = _FakeSpeechRecorder();
      final holdToRecord = build(recorder);
      addTearDown(holdToRecord.dispose);

      holdToRecord.stop();

      expect(holdToRecord.state, isA<HoldToRecordIdle>());
      expect(recorder.stops, 0);
    });

    test('a per-capture maxDuration passed to pointerDown overrides the '
        "default maxDuration for that capture's countdown", () async {
      final recorder = _FakeSpeechRecorder();
      final holdToRecord = build(recorder);
      addTearDown(holdToRecord.dispose);

      holdToRecord.pointerDown(maxDuration: const Duration(seconds: 1));
      await _flush();

      expect((holdToRecord.state as HoldToRecordRecording).secondsLeft, 1);

      await Future<void>.delayed(const Duration(milliseconds: 1200));

      expect(recorder.stops, 1);
      expect(holdToRecord.state, isA<HoldToRecordFinished>());
    });

    test('a per-capture maxDuration above the 60s ceiling is clamped to '
        '60s', () async {
      final recorder = _FakeSpeechRecorder();
      final holdToRecord = build(recorder);
      addTearDown(holdToRecord.dispose);

      holdToRecord.pointerDown(maxDuration: const Duration(seconds: 90));
      await _flush();

      expect((holdToRecord.state as HoldToRecordRecording).secondsLeft, 60);
    });

    test('auto-stop at the per-capture max always delivers, never discards, '
        'even for a maxDuration shorter than minDuration', () async {
      final recorder = _FakeSpeechRecorder();
      final holdToRecord = build(
        recorder,
        minDuration: const Duration(seconds: 5),
      );
      addTearDown(holdToRecord.dispose);

      holdToRecord.pointerDown(maxDuration: const Duration(seconds: 1));
      await _flush();

      await Future<void>.delayed(const Duration(milliseconds: 1200));

      expect(recorder.stops, 1);
      expect(recorder.cancellations, 0);
      expect(holdToRecord.state, isA<HoldToRecordFinished>());
    });

    test('gesture events arriving while Finishing are ignored, never '
        'starting a second concurrent capture', () async {
      final clock = FixedClock(DateTime(2026));
      final stopResult = Completer<void>();
      final recorder = _FakeSpeechRecorder(stopResult: stopResult);
      final holdToRecord = build(recorder, clock: clock);
      addTearDown(holdToRecord.dispose);

      holdToRecord.pointerDown();
      await _flush();
      clock.advance(const Duration(milliseconds: 700));
      holdToRecord.stop();
      await _flush();
      expect(holdToRecord.state, isA<HoldToRecordFinishing>());

      holdToRecord
        ..pointerDown()
        ..toggle();
      await _flush();

      expect(holdToRecord.state, isA<HoldToRecordFinishing>());
      expect(recorder.starts, 1);

      stopResult.complete();
      await _flush();

      expect(holdToRecord.state, isA<HoldToRecordFinished>());
    });
  });

  group('levels stream (D45, U23a)', () {
    test('opens exactly one recorder amplitude subscription per recording, '
        're-broadcasting samples to every listener and feeding '
        'RecordedAudio.levelsDbfs', () async {
      final clock = FixedClock(DateTime(2026));
      final recorder = _FakeSpeechRecorder();
      final holdToRecord = build(recorder, clock: clock);
      addTearDown(holdToRecord.dispose);

      final firstListener = <double>[];
      final secondListener = <double>[];
      holdToRecord.levels.listen(firstListener.add);
      holdToRecord.levels.listen(secondListener.add);

      holdToRecord.pointerDown();
      await _flush();
      expect(recorder.amplitudeAccessCount, 1);

      recorder
        ..emitAmplitude(-30)
        ..emitAmplitude(-12);
      await _flush();

      expect(firstListener, [-30, -12]);
      expect(secondListener, [-30, -12]);
      expect(recorder.amplitudeAccessCount, 1);

      clock.advance(const Duration(milliseconds: 700));
      holdToRecord.stop();
      await _flush();

      expect(holdToRecord.state, isA<HoldToRecordFinished>());
      expect((holdToRecord.state as HoldToRecordFinished).audio.levelsDbfs, [
        -30,
        -12,
      ]);

      recorder.emitAmplitude(-5);
      await _flush();

      expect(firstListener, [-30, -12]);
      expect(secondListener, [-30, -12]);
    });

    test('a new recording opens a fresh subscription, counted separately '
        'per recording', () async {
      final clock = FixedClock(DateTime(2026));
      final recorder = _FakeSpeechRecorder();
      final holdToRecord = build(recorder, clock: clock);
      addTearDown(holdToRecord.dispose);

      holdToRecord.pointerDown();
      await _flush();
      clock.advance(const Duration(milliseconds: 700));
      holdToRecord.stop();
      await _flush();
      expect(recorder.amplitudeAccessCount, 1);

      holdToRecord.pointerDown();
      await _flush();

      expect(recorder.amplitudeAccessCount, 2);
    });
  });
}
