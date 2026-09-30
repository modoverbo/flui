import 'dart:async';
import 'dart:math' as math;

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/audio/speech_recorder.dart';
import 'package:flui/core/clock/clock.dart';
import 'package:meta/meta.dart';

/// Whether a recording is being physically held down ([held]) or was
/// latched by a quick tap / non-pointer activation ([toggled]) — design
/// §19.3. [held] stops on release (above [HoldToRecord.minDuration]);
/// [toggled] stops on the next matching gesture ([HoldToRecord.pointerDown]
/// or [HoldToRecord.toggle]).
enum CaptureMode { held, toggled }

/// Every observable state [HoldToRecord] can be in. Widgets render from
/// [HoldToRecord.states] instead of owning any race-handling themselves
/// (design §2/§3.2, D2).
@immutable
sealed class HoldToRecordState {
  const new();
}

/// No hold in progress; ready for the next [HoldToRecord.press].
final class HoldToRecordIdle extends HoldToRecordState {
  const new({this.tooShort = false});

  /// True when this [HoldToRecordIdle] resulted from a discard below
  /// [HoldToRecord.minDuration] (design §19.3/§19.6 — the recorder's
  /// `minDuration` check), rather than an explicit
  /// [HoldToRecord.cancel]/[HoldToRecord.pointerCancel] or a hold denied at
  /// [HoldToRecordRequestingPermission]. `MicController` (U23b) surfaces
  /// this as the distinct `tooShort` notice, kept apart from a navigation
  /// cancel.
  final bool tooShort;
}

/// Waiting on [SpeechRecorder.requestPermission].
final class HoldToRecordRequestingPermission extends HoldToRecordState {
  const new();
}

/// Actively capturing audio. [secondsLeft] counts down to 0, at which
/// point the recording auto-finishes without requiring a release. [mode]
/// reflects whether the capture is currently [CaptureMode.held] or has
/// been latched to [CaptureMode.toggled] (design §19.3).
final class HoldToRecordRecording extends HoldToRecordState {
  const new(this.secondsLeft, {this.mode = CaptureMode.held});

  final int secondsLeft;
  final CaptureMode mode;
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
///
/// [pointerDown]/[pointerUp]/[pointerCancel]/[toggle]/[stop] (design §19.3,
/// U23a) are additive: they classify a single gesture recognizer into both
/// a hold and a tap-to-toggle, so `MicController` (U23b) never needs two
/// recognizers. [press]/[release]/[cancel] keep their original U2 behavior
/// unchanged — [pointerDown]/[pointerUp] delegate to them.
final class HoldToRecord {
  new(
    this._recorder, {
    required this.minDuration,
    required this.maxDuration,
    required this.clock,
    this.tapThreshold = const Duration(milliseconds: 300),
  });

  final SpeechRecorder _recorder;

  /// Below this hold duration, [release]/[stop] discard the recording
  /// instead of finishing it (a brief accidental tap, not an attempt).
  final Duration minDuration;

  /// The hard cutoff used when a gesture does not request its own
  /// per-capture override (design §19.3's `maxDuration` param on
  /// [pointerDown]/[toggle]); every per-capture value is clamped to
  /// [_maxDurationCeiling] regardless of source.
  final Duration maxDuration;

  /// The time source used for the [minDuration] check and the finished
  /// attempt's measured duration — injected so tests can freeze it.
  final Clock clock;

  /// Below this elapsed time since [pointerDown], [pointerUp] latches the
  /// recording to [CaptureMode.toggled] instead of releasing it (design
  /// §19.3, R13).
  final Duration tapThreshold;

  static const _maxDurationCeiling = Duration(seconds: 60);

  final _stateController = StreamController<HoldToRecordState>.broadcast();

  /// Emits every state transition.
  Stream<HoldToRecordState> get states => _stateController.stream;

  HoldToRecordState _state = const HoldToRecordIdle();

  /// The current state, mirrored by every event on [states].
  HoldToRecordState get state => _state;

  /// Raw dBFS amplitude samples, e.g. for a level-meter widget. Stops
  /// emitting once the recording stops or is cancelled (the underlying
  /// [SpeechRecorder] contract). Opens a fresh platform stream on every
  /// access — new capture-owning code should prefer [levels], which
  /// shares one subscription (D45).
  Stream<double> get amplitude => _recorder.amplitude;

  /// Raw dBFS samples collected via exactly ONE subscription to
  /// [SpeechRecorder.amplitude] per recording, re-broadcast to every
  /// listener (design §19.3, D45) — unlike [amplitude], this never opens a
  /// second platform stream just because a second widget is listening.
  /// The same samples feed [RecordedAudio.levelsDbfs] on
  /// [HoldToRecordFinished].
  Stream<double> get levels => _levelsController.stream;

  final _levelsController = StreamController<double>.broadcast();
  StreamSubscription<double>? _amplitudeSubscription;
  final _levelSamples = <double>[];

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
  CaptureMode _mode = CaptureMode.held;
  Duration? _captureMaxDuration;
  DateTime? _pointerDownAt;

  void _emit(HoldToRecordState next) {
    _state = next;
    _stateController.add(next);
  }

  Duration _clampToCeiling(Duration requested) =>
      requested > _maxDurationCeiling ? _maxDurationCeiling : requested;

  /// Starts a hold: requests permission (if needed), then starts capture.
  /// A no-op while a hold is already requested, a start is pending, or a
  /// cancellation is pending — never a second concurrent capture.
  void press() => _press(maxDuration: null, mode: CaptureMode.held);

  void _press({required Duration? maxDuration, required CaptureMode mode}) {
    if (_holdRequested || _startPending || _cancellationPending) return;
    _mode = mode;
    _captureMaxDuration = _clampToCeiling(maxDuration ?? this.maxDuration);
    _holdRequested = true;
    _cancelFuture = null;
    _startPending = true;
    unawaited(_startHold(++_holdGeneration));
  }

  /// Pointer-down half of the gesture recognizer (design §19.3): starts a
  /// hold from idle/denied/failed/finished, clamped to [maxDuration]
  /// (falling back to the constructor's [HoldToRecord.maxDuration]) or the
  /// 60 s ceiling, whichever is smaller. A pointer-down while a
  /// [CaptureMode.toggled] recording is already active is the "next tap"
  /// that stops it. Ignored while [HoldToRecordFinishing] (no event
  /// corrupts an in-flight finish).
  void pointerDown({Duration? maxDuration}) {
    if (_state is HoldToRecordFinishing) return;
    if (_state case HoldToRecordRecording(mode: CaptureMode.toggled)) {
      stop();
      return;
    }
    _pointerDownAt = clock.now();
    _press(maxDuration: maxDuration, mode: CaptureMode.held);
  }

  /// Pointer-up half of the gesture recognizer. While
  /// [HoldToRecordRequestingPermission] (the permission dialog stole the
  /// pointer, R13), latches to [CaptureMode.toggled] without emitting a
  /// new state — the capture keeps going once permission resolves. While
  /// [HoldToRecordRecording], an elapsed time (since [pointerDown]) below
  /// [tapThreshold] latches to toggled instead of stopping; at or above it,
  /// behaves as a normal [release].
  void pointerUp() {
    if (_state is HoldToRecordRequestingPermission) {
      _mode = CaptureMode.toggled;
      return;
    }
    if (_state is! HoldToRecordRecording) return;
    final elapsed = clock.now().difference(_pointerDownAt ?? clock.now());
    if (elapsed < tapThreshold) {
      _mode = CaptureMode.toggled;
      _emit(HoldToRecordRecording(_secondsLeft, mode: CaptureMode.toggled));
    } else {
      release();
    }
  }

  /// A pointer-cancel event (design §19.3). During
  /// [HoldToRecordRequestingPermission] the permission dialog steals the
  /// pointer (R13), so this behaves exactly like [pointerUp] instead of
  /// discarding outright. Otherwise behaves as [cancel].
  void pointerCancel() {
    if (_state is HoldToRecordRequestingPermission) {
      pointerUp();
      return;
    }
    cancel();
  }

  /// Non-pointer activation (keyboard, switch access, screen reader, D44):
  /// idle/denied/failed/finished starts a [CaptureMode.toggled] recording
  /// directly (no elapsed-time classification, since there is no release
  /// event to measure); an active recording stops via [stop]. Ignored
  /// while [HoldToRecordFinishing].
  void toggle({Duration? maxDuration}) {
    if (_state is HoldToRecordFinishing) return;
    if (_state is HoldToRecordRecording) {
      stop();
      return;
    }
    _press(maxDuration: maxDuration, mode: CaptureMode.toggled);
  }

  /// Finishes the current recording immediately, regardless of gesture
  /// mode. Below [minDuration], discards instead of finishing (marked
  /// [HoldToRecordIdle.tooShort]) — this is what a `stop()`-driven
  /// double-tap discard and a too-short toggle both resolve to. A no-op
  /// unless currently [HoldToRecordRecording].
  void stop() {
    if (_state is! HoldToRecordRecording) return;
    _holdRequested = false;
    _holdGeneration++;
    _finishOrDiscard();
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
    _finishOrDiscard();
  }

  void _finishOrDiscard() {
    final elapsed = clock.now().difference(_recordingStartedAt ?? clock.now());
    if (elapsed < minDuration) {
      _countdown?.cancel();
      unawaited(_cancelRecorder());
      _emit(const HoldToRecordIdle(tooShort: true));
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
    unawaited(_stopLevelsSubscription());
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

  void _startLevelsSubscription() {
    _levelSamples.clear();
    _amplitudeSubscription = _recorder.amplitude.listen((value) {
      _levelSamples.add(value);
      if (!_levelsController.isClosed) _levelsController.add(value);
    });
  }

  Future<void> _stopLevelsSubscription() async {
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
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
      _startLevelsSubscription();
      _secondsLeft = (_captureMaxDuration ?? maxDuration).inSeconds;
      _countdown?.cancel();
      _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_secondsLeft <= 1) {
          _holdRequested = false;
          unawaited(_finish());
        } else {
          _emit(HoldToRecordRecording(--_secondsLeft, mode: _mode));
        }
      });
      _emit(HoldToRecordRecording(_secondsLeft, mode: _mode));
    } on Object catch (_) {
      if (generation == _holdGeneration && _holdRequested) {
        _holdRequested = false;
        _emit(const HoldToRecordFailed());
      }
    } finally {
      _startPending = false;
    }
  }

  Future<void> _finish() async {
    if (_state is! HoldToRecordRecording || !_recorderActive) return;
    _countdown?.cancel();
    _recorderActive = false;
    // Fire-and-forget, like `_cancelRecorder`'s own call below: the
    // `Finishing` emit must stay synchronous with the call that triggered
    // it (`release()`/`stop()`/the auto-finish timer), matching U2's
    // original behavior that widget tests already assert against with a
    // single `pump()`.
    unawaited(_stopLevelsSubscription());
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
            levelsDbfs: List<double>.of(_levelSamples),
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
    await _stopLevelsSubscription();
    await _levelsController.close();
    await _recorder.dispose();
    await _stateController.close();
  }
}
