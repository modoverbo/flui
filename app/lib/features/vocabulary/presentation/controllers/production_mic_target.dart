import 'dart:async';

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/features/daily/domain/session_step.dart';
import 'package:flui/features/daily/presentation/controllers/session_controller.dart';
import 'package:flui/features/vocabulary/domain/exercises/production_check.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'production_mic_target.g.dart';

/// `/session`'s production Úsala step (the "writing phase", answered
/// aloud — design §10, D34-D36, U17b): `deliver` forwards straight to
/// `SessionController.answerProductionAloud` (D25), root-layer, alongside
/// `MicDock` (D30, D36). The self-check rubric ("Sí, suena natural"/
/// "Quiero ajustarla") stays taps — this target only covers the writing
/// phase.
final class ProductionMicTarget implements MicTarget {
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
  MicPrompt get prompt => const MicPrompt(actionLabel: 'Grabar tu oración');

  /// D42's own explicit override for this exercise: a single sentence
  /// never needs more than 30s.
  @override
  Duration get maxDuration => const Duration(seconds: 30);

  /// Ready only while the production step is active and still in its
  /// writing phase (design D36) — a pass-through otherwise, mirroring
  /// `FormRecallMicTarget`'s own two-layer guard (this target AND
  /// `SessionController.answerProductionAloud` both refuse a
  /// resolved/inactive step independently).
  @override
  MicAvailability get availability {
    final state = _state;
    final production = state?.production;
    if (state == null || production == null || state.step is! ProductionStep) {
      return const MicPassThrough();
    }
    if (production.phase != ProductionPhase.writing) {
      return const MicPassThrough();
    }
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
      .answerProductionAloud(audio);

  /// A widget registering this target via `MicTargetScope` calls this from
  /// its own `dispose()`.
  void dispose() {
    _subscription.close();
    unawaited(_changes.close());
  }
}

@riverpod
ProductionMicTarget productionMicTarget(Ref ref, SessionMode mode) {
  final target = ProductionMicTarget(ref, mode);
  ref.onDispose(target.dispose);
  return target;
}
