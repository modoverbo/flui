import 'dart:async';

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/features/training/domain/attempt_kind.dart';
import 'package:flui/features/training/domain/training_loop.dart';
import 'package:flui/features/training/presentation/controllers/training_loop_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderSubscription;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'loop_mic_target.g.dart';

/// Adapts one [TrainingLoopController] session to the shell's mic (design
/// §19.2): maps [TrainingLoopState.phase] to [MicAvailability]/[MicPrompt]
/// and forwards [deliver] straight to `submit` (D25) — this class never
/// analyzes audio itself, and never owns capture.
final class LoopMicTarget implements MicTarget {
  new(this._ref, this._request) {
    _subscription = _ref.listen(
      trainingLoopControllerProvider(_request),
      (_, _) => _changes.add(null),
    );
  }

  final Ref _ref;
  final LoopRequest _request;
  final _changes = StreamController<void>.broadcast();
  late final ProviderSubscription<TrainingLoopControllerState> _subscription;

  TrainingLoopState get _loop =>
      _ref.read(trainingLoopControllerProvider(_request)).loop;

  @override
  MicPrompt get prompt => _promptFor(_loop);

  @override
  Duration get maxDuration => const Duration(seconds: 60);

  @override
  MicAvailability get availability => _availabilityFor(_loop);

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<MicDelivery> deliver(RecordedAudio audio) => _ref
      .read(trainingLoopControllerProvider(_request).notifier)
      .submit(audio);

  /// Releases the subscription feeding [changes]. A widget registering this
  /// target via `MicTargetScope` calls this from its own `dispose()`.
  void dispose() {
    _subscription.close();
    unawaited(_changes.close());
  }

  static MicPrompt _promptFor(TrainingLoopState loop) => switch (loop.phase) {
    LoopPhase.focus when loop.attemptStep == AttemptKind.first =>
      const MicPrompt(actionLabel: 'Grabar tu respuesta'),
    LoopPhase.focus => const MicPrompt(actionLabel: 'Grabar tu intento'),
    LoopPhase.feedback => const MicPrompt(actionLabel: 'Grabar tu repetición'),
    LoopPhase.comparison => const MicPrompt(
      actionLabel: 'Grabar tu transferencia',
      hint: 'Aplica lo que acabas de practicar.',
    ),
    LoopPhase.analysisFailed when loop.failureCode == notSavedFailureCode =>
      const MicPrompt(actionLabel: 'Intento pendiente de guardar'),
    LoopPhase.analysisFailed => const MicPrompt(
      actionLabel: 'Reintentar grabación',
    ),
    LoopPhase.recording || LoopPhase.analyzing => const MicPrompt(
      actionLabel: 'Analizando tu intento',
    ),
    LoopPhase.accessRequired => const MicPrompt(
      actionLabel: 'Reactivar acceso',
    ),
    LoopPhase.permissionDenied => const MicPrompt(
      actionLabel: 'Permiso de micrófono requerido',
    ),
    LoopPhase.summary => const MicPrompt(actionLabel: 'Práctica en voz alta'),
  };

  /// Design §19.2's mapping table: `focus/feedback/comparison` are all
  /// ready (the mic itself auto-advances past a passive feedback/comparison
  /// view, design §19.8); `recording/analyzing` are busy;
  /// `accessRequired` is blocked with the "Reactivar" CTA;
  /// `analysisFailed` is ready for a re-record UNLESS its own failure was a
  /// daily-limit rejection (stays blocked until tomorrow) or the attempt
  /// simply was not saved yet (blocked — a fresh recording here would
  /// silently orphan the unsaved one instead of retrying its save, see the
  /// orchestrator review fix); `summary` passes through to whatever the
  /// registry resolves beneath it.
  static MicAvailability _availabilityFor(TrainingLoopState loop) =>
      switch (loop.phase) {
        LoopPhase.focus ||
        LoopPhase.feedback ||
        LoopPhase.comparison ||
        LoopPhase.permissionDenied => const MicReady(),
        LoopPhase.recording ||
        LoopPhase.analyzing => const MicBusy('Estamos analizando tu intento.'),
        LoopPhase.accessRequired => const MicBlocked(
          'Reactiva tu acceso para seguir practicando.',
          cta: MicBlockedCta(label: 'Reactivar', route: '/paywall'),
        ),
        LoopPhase.analysisFailed => switch (loop.failureCode) {
          'dailyLimitReached' => const MicBlocked(
            'Ya usaste tus análisis de hoy. Vuelve mañana.',
          ),
          notSavedFailureCode => const MicBlocked(
            'No pudimos guardar tu intento. Reintenta guardarlo antes de '
            'grabar de nuevo.',
          ),
          _ => const MicReady(),
        },
        LoopPhase.summary => const MicPassThrough(),
      };
}

/// One [LoopMicTarget] per [LoopRequest] (mirrors the family it wraps): a
/// screen registers `ref.watch(loopMicTargetProvider(request))` with
/// `MicTargetScope` and disposes it the same way.
@riverpod
LoopMicTarget loopMicTarget(Ref ref, LoopRequest request) {
  final target = LoopMicTarget(ref, request);
  ref.onDispose(target.dispose);
  return target;
}
