import 'dart:async';

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/features/daily/domain/session_step.dart';
import 'package:flui/features/daily/presentation/controllers/session_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'form_recall_mic_target.g.dart';

/// `/session`'s form-recall Úsala step, answered aloud (design §10, D34-D36,
/// U17b): `deliver` forwards straight to
/// `SessionController.answerFormRecallAloud` (D25 — this class never
/// transcribes or judges an answer itself), root-layer, alongside `MicDock`
/// (D30, D36 — `/session` stays on the root navigator).
final class FormRecallMicTarget implements MicTarget {
  new(this._ref, this._mode) {
    _subscription = _ref.listen(
      sessionControllerProvider(_mode),
      (_, _) => _changes.add(null),
    );
  }

  final Ref _ref;
  final SessionMode _mode;
  final _changes = StreamController<void>.broadcast();
  late final ProviderSubscription<AsyncValue<SessionState>> _subscription;

  SessionState? get _state => _ref.read(sessionControllerProvider(_mode)).value;

  @override
  MicPrompt get prompt => const MicPrompt(actionLabel: 'Decir la palabra');

  /// D42's own explicit override for this exercise (not the general
  /// `1.5x target_seconds` challenge rule): a single recalled word never
  /// needs more than 10s.
  @override
  Duration get maxDuration => const Duration(seconds: 10);

  /// Ready only while the form recall step is active and not yet resolved
  /// (design D36) — a pass-through the rest of the time, so the registry's
  /// stack (or fallback) resolves underneath instead of this target
  /// blocking on a step it has nothing left to offer for. Checked here, at
  /// the domain-adjacent presentation layer, on top of
  /// `SessionController.answerFormRecallAloud`'s own guard: two
  /// independent layers, matching the U17 review-finding precedent (a
  /// single call site is not enough to guarantee no quota is spent on a
  /// resolved/inactive step).
  @override
  MicAvailability get availability {
    final state = _state;
    final check = state?.formRecall;
    if (state == null || check == null || state.step is! FormRecallStep) {
      return const MicPassThrough();
    }
    if (check.isResolved) return const MicPassThrough();
    if (state.saving) {
      return const MicBusy('Estamos guardando tu respuesta.');
    }
    return const MicReady();
  }

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<MicDelivery> deliver(RecordedAudio audio) => _ref
      .read(sessionControllerProvider(_mode).notifier)
      .answerFormRecallAloud(audio);

  /// A widget registering this target via `MicTargetScope` calls this from
  /// its own `dispose()`.
  void dispose() {
    _subscription.close();
    unawaited(_changes.close());
  }
}

@riverpod
FormRecallMicTarget formRecallMicTarget(Ref ref, SessionMode mode) {
  final target = FormRecallMicTarget(ref, mode);
  ref.onDispose(target.dispose);
  return target;
}
