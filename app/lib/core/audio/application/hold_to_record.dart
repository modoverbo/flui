import 'dart:async';
import 'dart:math' as math;

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/audio/speech_recorder.dart';
import 'package:flui/core/clock/clock.dart';
import 'package:meta/meta.dart';

/// Every observable state [HoldToRecord] can be in. Widgets render from
/// [HoldToRecord.states] instead of owning any race-handling themselves
/// (design §2/§3.2, D2).
@immutable
sealed class HoldToRecordState {
  const new();
}

/// No hold in progress; ready for the next [HoldToRecord.press].
final class HoldToRecordIdle extends HoldToRecordState {
  const new();
}

/// Waiting on [SpeechRecorder.requestPermission].
final class HoldToRecordRequestingPermission extends HoldToRecordState {
  const new();
}

/// Actively capturing audio. [secondsLeft] counts down to 0, at which
/// point the recording auto-finishes without requiring a release.
final class HoldToRecordRecording extends HoldToRecordState {
  const new(this.secondsLeft);

  final int secondsLeft;
}

/// Stopping the recorder and encoding the captured audio.
final class HoldToRecordFinishing extends HoldToRecordState {
  const new();
}

/// The user denied microphone permission, or it was already denied at the
/// OS level and cannot be re-prompted.
final class HoldToRecordDenied extends HoldToRecordState {
  const new();
}

/// The recorder failed to start, or produced no usable audio.
final class HoldToRecordFailed extends HoldToRecordState {
  const new();
}

/// A completed hold produced [audio], ready for analysis, playback, or
/// upload.
final class HoldToRecordFinished extends HoldToRecordState {
  const new(this.audio);

  final RecordedAudio audio;
}

/// Orchestrates one hold-to-record gesture end to end: permission request,
/// start, per-second countdown with auto-finish, and every
/// start/cancel/release race — independent of any widget.
///
/// This is the exact hold-generation / pending-start / pending-cancel
/// bookkeeping that used to live inline in `_SpeakingChallengePageState`
/// (fields `_holdGeneration`, `_startPending`, `_cancellationPending`,
/// `_recorderStartFuture`, `_cancelFuture`), extracted so it is testable
/// with a fake [SpeechRecorder] and [Clock] and reusable by every training
/// context (design §1 seam 1, §3.2). A widget only forwards pointer events
/// to [press]/[release]/[cancel] and renders [states]/[amplitude].
final class HoldToRecord {
  new(
    this._recorder, {
    required this.minDuration,
    required this.maxDuration,
    required this.clock,
  });

  final SpeechRecorder _recorder;

  /// Below this hold duration, [release] discards the recording instead of
  /// finishing it (a brief accidental tap, not an attempt).
  final Duration minDuration;

  /// The hard cutoff: a hold reaching this duration auto-finishes.
  final Duration maxDuration;

  /// The time source used for the [minDuration] check and the finished
  /// attempt's measured duration — injected so tests can freeze it.
  final Clock clock;

  final _stateController = StreamController<HoldToRecordState>.broadcast();

  /// Emits every state transition.
  Stream<HoldToRecordState> get states => _stateController.stream;

  HoldToRecordState _state = const HoldToRecordIdle();

  /// The current state, mirrored by every event on [states].
  HoldToRecordState get state => _state;

  /// Raw dBFS amplitude samples, e.g. for a level-meter widget. Stops
  /// emitting once the recording stops or is cancelled (the underlying
  /// [SpeechRecorder] contract).
  Stream<double> get amplitude => _recorder.amplitude;

  bool _holdRequested = false;
  bool _recorderActive = false;
  bool _startPending = false;
  bool _cancellationPending = false;
  Future<void>? _recorderStartFuture;
  Future<void>? _cancelFuture;
  int _holdGeneration = 0;
  Timer? _countdown;
  int _secondsLeft = 0;
  DateTime? _recordingStartedAt;

  void _emit(HoldToRecordState next) {
    _state = next;
    _stateController.add(next);
  }

  /// Starts a hold: requests permission (if needed), then starts capture.
  /// A no-op while a hold is already requested, a start is pending, or a
  /// cancellation is pending — never a second concurrent capture.
  void press() {
    if (_holdRequested || _startPending || _cancellationPending) return;
    _holdRequested = true;
    _cancelFuture = null;
    _startPending = true;
    unawaited(_startHold(++_holdGeneration));
  }

  Future<void> _startHold(int generation) async {
    try {
      _emit(const HoldToRecordRequestingPermission());
      final permitted = await _recorder.requestPermission();
      if (!_holdRequested || generation != _holdGeneration) return;
      if (!permitted) {
        _holdRequested = false;
        _emit(const HoldToRecordDenied());
        return;
      }
      final recorderStart = _recorder.start();
      _recorderStartFuture = recorderStart;
      try {
        await recorderStart;
      } finally {
        if (identical(_recorderStartFuture, recorderStart)) {
          _recorderStartFuture = null;
        }
      }
      if (!_holdRequested || generation != _holdGeneration) {
        await _cancelRecorder();
        return;
      }
      _recorderActive = true;
      _recordingStartedAt = clock.now();
      _secondsLeft = maxDuration.inSeconds;
      _countdown?.cancel();
      _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_secondsLeft <= 1) {
          _holdRequested = false;
          unawaited(_finish());
        } else {
          _emit(HoldToRecordRecording(--_secondsLeft));
        }
      });
      _emit(HoldToRecordRecording(_secondsLeft));
    } on Object catch (_) {
      if (generation == _holdGeneration && _holdRequested) {
        _holdRequested = false;
        _emit(const HoldToRecordFailed());
      }
    } finally {
      _startPending = false;
    }
  }

  /// Ends a hold normally: below [minDuration] discards the recording,
  /// otherwise stops and finishes it.
  void release() {
    if (!_holdRequested) return;
    _holdRequested = false;
    _holdGeneration++;
    if (_state is HoldToRecordRequestingPermission) {
      _emit(const HoldToRecordIdle());
      return;
    }
    if (_state is! HoldToRecordRecording) return;
    final elapsed = clock.now().difference(_recordingStartedAt ?? clock.now());
    if (elapsed < minDuration) {
      _countdown?.cancel();
      unawaited(_cancelRecorder());
      _emit(const HoldToRecordIdle());
      return;
    }
    unawaited(_finish());
  }

  /// Discards the current hold outright (e.g. a pointer-cancel event),
  /// regardless of how much of [minDuration] has elapsed.
  void cancel() {
    if (!_holdRequested) return;
    _holdRequested = false;
    _holdGeneration++;
    _countdown?.cancel();
    if (_state is HoldToRecordRecording ||
        _state is HoldToRecordRequestingPermission) {
      unawaited(_cancelRecorder());
      _emit(const HoldToRecordIdle());
    }
  }

  Future<void> _cancelRecorder() {
    final inFlight = _cancelFuture;
    if (inFlight != null) return inFlight;
    _cancellationPending = true;
    _recorderActive = false;
    final cancellation = _cancelAndCaptureFailure();
    _cancelFuture = cancellation;
    return cancellation;
  }

  Future<void> _cancelAndCaptureFailure() async {
    final pendingStart = _recorderStartFuture;
    if (pendingStart != null) {
      try {
        await pendingStart;
      } on Object catch (_) {
        // The start failure is handled by the start flow; cancellation
        // remains best-effort cleanup for any partial platform startup.
      }
    }
    try {
      await _recorder.cancel();
    } on Object catch (_) {
      // Cancellation is a best-effort discard; disposal still releases
      // the recorder even if the platform plugin has already stopped it.
    } finally {
      _cancellationPending = false;
    }
  }

  Future<void> _finish() async {
    if (_state is! HoldToRecordRecording || !_recorderActive) return;
    _countdown?.cancel();
    _recorderActive = false;
    _emit(const HoldToRecordFinishing());
    try {
      final bytes = await _recorder.stop();
      if (bytes.isEmpty) throw StateError('empty recording');
      final elapsed = clock.now().difference(
        _recordingStartedAt ?? clock.now(),
      );
      final duration = Duration(
        milliseconds: math.max(500, elapsed.inMilliseconds),
      );
      _emit(
        HoldToRecordFinished(
          RecordedAudio(
            bytes: bytes,
            mimeType: 'audio/wav',
            duration: duration,
            levelsDbfs: const [],
          ),
        ),
      );
    } on Object catch (_) {
      _emit(const HoldToRecordFailed());
    }
  }

  /// Cancels any active hold, disposes the underlying recorder, and closes
  /// [states]. Safe to call from a widget's `dispose()`.
  Future<void> dispose() async {
    final wasActive = _holdRequested || _recorderActive;
    // Unlike a widget's `mounted`, nothing else marks this instance as
    // gone — without resetting these, a `_startHold` still suspended on a
    // pending `SpeechRecorder.start()` would resume after disposal and
    // start the countdown Timer on a discarded instance.
    _holdRequested = false;
    _holdGeneration++;
    _countdown?.cancel();
    if (wasActive) await _cancelRecorder();
    if (_cancelFuture case final cancellation?) await cancellation;
    await _recorder.dispose();
    await _stateController.close();
  }
}
