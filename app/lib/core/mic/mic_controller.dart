import 'dart:async';

import 'package:flui/core/audio/application/hold_to_record.dart';
import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/audio/speech_recorder.dart';
import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/core/mic/mic_target_registry.dart';
import 'package:meta/meta.dart';

/// Every observable state `MicController` can be in (design §19.2).
@immutable
sealed class MicState {
  const new();
}

/// Nothing is recording. [prompt] is the currently resolved target's
/// contextual label; [block] is non-null while a controller-level latch
/// (access/quota/permission) or the resolved target's own [MicBlocked]
/// availability is preventing a new capture.
final class MicIdle extends MicState {
  const new(this.prompt, {this.block});

  final MicPrompt prompt;
  final MicBlocked? block;
}

final class MicRequestingPermission extends MicState {
  const new();
}

final class MicRecording extends MicState {
  const new({
    required this.secondsLeft,
    required this.maxSeconds,
    required this.mode,
  });

  final int secondsLeft;
  final int maxSeconds;
  final CaptureMode mode;
}

final class MicFinishing extends MicState {
  const new();
}

final class MicDelivering extends MicState {
  const new();
}

/// A one-shot, dismissible explanation, distinct from a persistent
/// [MicIdle.block] sheet (design §19.6, D43). Presented with its own
/// copy per code at the presentation layer (`MicNoticeHost`, U23d).
/// [cancelledByNavigation]/[cancelledByBackground] are emitted by
/// `MicNavigationBinding` (U23d), not by `MicController` itself.
enum MicNotice {
  cancelledByNavigation,
  cancelledByBackground,
  tooShort,
  permissionDenied,
  busy,
  deliveryFailed,
}

/// Owns the shell's single [HoldToRecord] for the signed-in session (D23)
/// and the precedence/binding/delivery/latching state machine in front of
/// it (design §19.5). Feature-agnostic: never analyzes audio itself, only
/// calls the resolved [MicTarget.deliver] (D25).
final class MicController {
  new({
    required SpeechRecorder Function() recorderFactory,
    required MicTargetRegistry registry,
    required Clock clock,
    // Named `registry`/`clock` (not `_registry`/`_clock`) so external
    // callers (mic_providers.dart, tests) can pass them — an
    // initializing formal would force the private field name onto the
    // public constructor signature.
    // ignore: prefer_initializing_formals
  }) : _registry = registry,
       _clock = clock,
       _holdToRecord = HoldToRecord(
         recorderFactory(),
         minDuration: const Duration(milliseconds: 600),
         maxDuration: const Duration(seconds: 60),
         clock: clock,
       ) {
    _holdSubscription = _holdToRecord.states.listen(_onHoldState);
    _registrySubscription = _registry.changes.listen(
      (_) => _refreshIdlePrompt(),
    );
    _emit(_idleState());
  }

  final MicTargetRegistry _registry;
  final Clock _clock;
  final HoldToRecord _holdToRecord;
  late final StreamSubscription<HoldToRecordState> _holdSubscription;
  late final StreamSubscription<void> _registrySubscription;

  final _stateController = StreamController<MicState>.broadcast();
  final _noticeController = StreamController<MicNotice>.broadcast();

  Stream<MicState> get states => _stateController.stream;
  Stream<MicNotice> get notices => _noticeController.stream;

  /// Re-broadcast dBFS samples of the current recording (D45).
  Stream<double> get levels => _holdToRecord.levels;

  MicState _state = const MicIdle(MicPrompt(actionLabel: ''));

  /// The current state, mirrored by every event on [states].
  MicState get state => _state;

  /// The token bound to the currently in-flight (or most recently
  /// finished) capture, identifying which exact
  /// [MicTargetRegistry.resolve] result it is tied to.
  /// `MicNavigationBinding` (U23d) uses this to detect when the bound
  /// registration is no longer the one the registry resolves.
  Object? get boundToken => _boundToken;

  // Fail-closed by default: `mic_providers.dart` sets this from
  // `accessGateProvider` immediately at construction, so this starting
  // value is only observable for the instant before that first listen.
  bool _accessGranted = false;
  bool _accessLatched = false;
  DateTime? _quotaLatchedUtcDate;
  bool _permissionLatchedDenied = false;
  bool _delivering = false;

  MicTarget? _boundTarget;
  Object? _boundToken;
  Duration? _boundMaxDuration;

  static const _accessBlock = MicBlocked(
    'Reactiva tu acceso para seguir practicando.',
    cta: MicBlockedCta(label: 'Reactivar', route: '/paywall'),
  );
  static const _quotaBlock = MicBlocked(
    'Ya usaste tus análisis de hoy. Vuelve mañana.',
  );
  static const _permissionBlock = MicBlocked(
    'Necesitamos acceso al micrófono. Actívalo en los ajustes y vuelve a '
    'intentarlo.',
    cta: MicBlockedCta(label: 'Intentar de nuevo'),
  );

  /// Called from `ref.listen(accessGateProvider, ...)` (`mic_providers`) —
  /// clears the access latch once access is granted again (design §19.5).
  // ignore: avoid_positional_boolean_parameters
  void setAccessGranted(bool granted) {
    _accessGranted = granted;
    if (granted) _accessLatched = false;
    _refreshIdleBlock();
  }

  /// The "Intentar de nuevo" one-shot re-request offered by
  /// [_permissionBlock]'s CTA (design §19.5 item 4): unlike [toggle]/
  /// [pointerDown], a permission latch alone never blocks this — it
  /// clears the latch first, then attempts the exact same capture-start
  /// flow, giving the now-possibly-fixed OS/browser permission a chance
  /// to succeed. Still subject to the access/quota latches ahead of it.
  void retryPermission() {
    _permissionLatchedDenied = false;
    unawaited(_beginCapture(toggle: true));
  }

  /// Starts a capture from idle/denied/failed/finished (subject to the
  /// precedence checks in [_beginCapture]); the next pointer-down while a
  /// [CaptureMode.toggled] recording is active stops it instead (design
  /// §19.3).
  void pointerDown() {
    if (_holdToRecord.state case HoldToRecordRecording(
      mode: CaptureMode.toggled,
    )) {
      _holdToRecord.pointerDown();
      return;
    }
    unawaited(_beginCapture(toggle: false));
  }

  void pointerUp() => _holdToRecord.pointerUp();

  void pointerCancel() => _holdToRecord.pointerCancel();

  /// Non-pointer activation (keyboard, switch access, screen reader,
  /// D44): reaches the exact same precedence flow as [pointerDown].
  void toggle() {
    if (_holdToRecord.state is HoldToRecordRecording) {
      _holdToRecord.toggle();
      return;
    }
    unawaited(_beginCapture(toggle: true));
  }

  /// Cancels the current capture and discards it — a no-op (returns
  /// `false`) unless [state] is [MicRequestingPermission] or
  /// [MicRecording]; an in-flight [MicFinishing]/[MicDelivering] is NEVER
  /// cancelled here (design D28). Emits no notice itself — `emitNotice` is
  /// a separate call so `MicNavigationBinding` (U23d) can show
  /// `cancelledByNavigation` immediately or defer `cancelledByBackground`
  /// until the app is visible again.
  bool cancelActiveCapture() {
    if (_state is! MicRequestingPermission && _state is! MicRecording) {
      return false;
    }
    _holdToRecord.cancel();
    return true;
  }

  /// Emits [notice] on [notices] directly — the other half of
  /// [cancelActiveCapture], and how `MicNavigationBinding` (U23d) shows a
  /// notice that was deliberately deferred (e.g. `cancelledByBackground`,
  /// only shown once the app resumes, never while backgrounded).
  void emitNotice(MicNotice notice) => _emitNotice(notice);

  Future<void> _beginCapture({required bool toggle}) async {
    // 1. An analysis is already in flight for the previous attempt.
    if (_delivering) {
      _emitNotice(MicNotice.busy);
      return;
    }
    // 2-4. Controller-level latches, in precedence order, explained
    // rather than silently ignored (D31).
    final latchBlock = _currentLatchBlock();
    if (latchBlock != null) {
      _emit(MicIdle(_resolvedPrompt(), block: latchBlock));
      return;
    }
    // 5. Resolve the current screen's spoken action.
    final (target, token) = _registry.resolve();
    switch (target.availability) {
      case final MicBlocked blocked:
        _emit(MicIdle(target.prompt, block: blocked));
        return;
      case MicBusy():
        _emitNotice(MicNotice.busy);
        return;
      case MicPrepare(:final onActivate):
        await onActivate();
        // Re-emit: the mic must reflect the target's new prompt/
        // availability right away (e.g. "Practicar en voz alta" ->
        // "Responder" once a quick-practice challenge is picked), not
        // wait for some unrelated event to happen to refresh it — the
        // same class of stale-label bug as the U23c `setActiveBranch`
        // finding.
        if (_state is MicIdle) _emit(_idleState());
        return;
      case MicReady():
      case MicPassThrough():
        break;
    }
    // 6. Bind and start.
    _boundTarget = target;
    _boundToken = token;
    _boundMaxDuration = target.maxDuration;
    if (toggle) {
      _holdToRecord.toggle(maxDuration: target.maxDuration);
    } else {
      _holdToRecord.pointerDown(maxDuration: target.maxDuration);
    }
  }

  void _onHoldState(HoldToRecordState holdState) {
    switch (holdState) {
      case HoldToRecordIdle(:final tooShort):
        _boundTarget = null;
        _boundToken = null;
        if (tooShort) _emitNotice(MicNotice.tooShort);
        _emit(_idleState());
      case HoldToRecordRequestingPermission():
        _emit(const MicRequestingPermission());
      case HoldToRecordRecording(:final secondsLeft, :final mode):
        _permissionLatchedDenied = false;
        _emit(
          MicRecording(
            secondsLeft: secondsLeft,
            maxSeconds: _boundMaxDuration?.inSeconds ?? secondsLeft,
            mode: mode,
          ),
        );
      case HoldToRecordFinishing():
        _emit(const MicFinishing());
      case HoldToRecordDenied():
        _permissionLatchedDenied = true;
        _boundTarget = null;
        _boundToken = null;
        _emitNotice(MicNotice.permissionDenied);
        _emit(_idleState());
      case HoldToRecordFailed():
        _boundTarget = null;
        _boundToken = null;
        _emitNotice(MicNotice.deliveryFailed);
        _emit(_idleState());
      case HoldToRecordFinished(:final audio):
        unawaited(_deliver(audio));
    }
  }

  /// Delivers on the CAPTURED [_boundTarget] reference directly, never by
  /// re-resolving from [_registry] — so an in-flight delivery always
  /// completes even if the bound registration is disposed in the
  /// meantime (never cancelled by navigation here; that guard is
  /// `MicNavigationBinding`'s job, U23d).
  Future<void> _deliver(RecordedAudio audio) async {
    final target = _boundTarget;
    _delivering = true;
    _emit(const MicDelivering());
    try {
      final result = target == null
          ? const MicDeliveryFailed(
              'No hay una acción activa para este intento.',
            )
          : await target.deliver(audio);
      switch (result) {
        case MicAccepted():
          break;
        case MicAccessRequired():
          _accessLatched = true;
        case MicDailyLimitReached():
          _quotaLatchedUtcDate = _clock.now().toUtc();
        case MicDeliveryFailed():
          _emitNotice(MicNotice.deliveryFailed);
      }
    } finally {
      _delivering = false;
      _boundTarget = null;
      _boundToken = null;
      _emit(_idleState());
    }
  }

  MicIdle _idleState() =>
      MicIdle(_resolvedPrompt(), block: _currentLatchBlock());

  MicPrompt _resolvedPrompt() {
    final (target, _) = _registry.resolve();
    return target.prompt;
  }

  void _refreshIdlePrompt() {
    if (_state is MicIdle) _emit(_idleState());
  }

  void _refreshIdleBlock() {
    if (_state is MicIdle) _emit(_idleState());
  }

  MicBlocked? _currentLatchBlock() {
    if (!_accessGranted || _accessLatched) return _accessBlock;
    if (_quotaLatchedToday) return _quotaBlock;
    if (_permissionLatchedDenied) return _permissionBlock;
    return null;
  }

  bool get _quotaLatchedToday {
    final latched = _quotaLatchedUtcDate;
    if (latched == null) return false;
    final now = _clock.now().toUtc();
    return now.year == latched.year &&
        now.month == latched.month &&
        now.day == latched.day;
  }

  void _emit(MicState next) {
    _state = next;
    if (!_stateController.isClosed) _stateController.add(next);
  }

  void _emitNotice(MicNotice notice) {
    if (!_noticeController.isClosed) _noticeController.add(notice);
  }

  /// Cancels any active hold, disposes the underlying [HoldToRecord], and
  /// closes [states]/[notices]. Safe to call from a provider's
  /// `ref.onDispose`.
  Future<void> dispose() async {
    await _holdSubscription.cancel();
    await _registrySubscription.cancel();
    await _holdToRecord.dispose();
    await _stateController.close();
    await _noticeController.close();
  }
}
