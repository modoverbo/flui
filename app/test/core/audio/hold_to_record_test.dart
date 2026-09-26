import 'dart:async';
import 'dart:typed_data';

import 'package:flui/core/audio/application/hold_to_record.dart';
import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/audio/speech_recorder.dart';
import 'package:flui/core/clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ported from `speaking_challenge_page_test.dart`'s `FakeSpeechRecorder`:
/// same controllable permission/start completers, now exercised directly
/// against [HoldToRecord] instead of through a widget.
final class _FakeSpeechRecorder implements SpeechRecorder {
  new({this.permission = true, this.startResult});

  final bool permission;
  final Completer<void>? startResult;
  final events = <String>[];
  int permissionRequests = 0;
  int starts = 0;
  int stops = 0;
  int cancellations = 0;

  @override
  Stream<double> get amplitude => const Stream.empty();

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permission;
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
  }
}

/// Flushes the microtask queue (as many hops as our async chains use) so
/// `press()`'s fire-and-forget `_startHold` settles before assertions.
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
}
