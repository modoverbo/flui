import 'dart:async';

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/features/training/domain/attempt_kind.dart';
import 'package:flui/features/training/domain/training_loop.dart';
import 'package:flui/features/training/presentation/controllers/training_loop_controller.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/features/vocabulary/presentation/providers/vocabulary_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    // Only when this session actually wove words in (U15b, design D15):
    // an ENTRENAR/diagnosis loop, which never carries `targetWordIds`,
    // never touches the word catalog at all. Re-fires `changes` if the
    // catalog is still loading when this target is first registered, so
    // the mic's hint picks up the word text as soon as it arrives.
    if (_request.targetWordIds.isNotEmpty) {
      _wordsSubscription = _ref.listen(
        wordsByIdProvider,
        (_, _) => _changes.add(null),
      );
    }
  }

  final Ref _ref;
  final LoopRequest _request;
  final _changes = StreamController<void>.broadcast();
  late final ProviderSubscription<TrainingLoopControllerState> _subscription;
  ProviderSubscription<AsyncValue<Map<String, Word>>>? _wordsSubscription;

  TrainingLoopState get _loop =>
      _ref.read(trainingLoopControllerProvider(_request)).loop;

  /// Orchestrator review finding: `wordUse` has no `transfer` step, so its
  /// own `comparison` (reached once the repeat attempt's analysis
  /// succeeds) IS its terminal state — it never reaches `LoopPhase.summary`
  /// the way `full`/`quick`/`diagnosis` do. The generic phase mapping below
  /// (`_promptFor`/`_availabilityFor`, deliberately UNCHANGED — every other
  /// script's own comparison/summary handling stays exactly as it was)
  /// would otherwise show `MicReady` with `full`'s own transfer-step label
  /// ("Grabar tu transferencia") forever, and recording there has no valid
  /// next step (`TrainingLoopController.submit` now refuses it before any
  /// paid analysis, but the mic itself must never offer it in the first
  /// place). Checked here, not inside the static helpers, so `full`,
  /// `diagnosis` and `quick`'s own mappings stay byte-identical.
  bool get _isWordUseFinished =>
      _request.script is WordUseLoopScript &&
      _loop.phase == LoopPhase.comparison &&
      _loop.attemptStep == AttemptKind.repeat;

  @override
  MicPrompt get prompt => _isWordUseFinished
      ? const MicPrompt(actionLabel: 'Práctica en voz alta')
      : _promptFor(_loop, _wovenWordTexts);

  @override
  Duration get maxDuration => const Duration(seconds: 60);

  @override
  MicAvailability get availability =>
      _isWordUseFinished ? const MicPassThrough() : _availabilityFor(_loop);

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<MicDelivery> deliver(RecordedAudio audio) => _ref
      .read(trainingLoopControllerProvider(_request).notifier)
      .submit(audio);

  /// Releases the subscriptions feeding [changes]. A widget registering
  /// this target via `MicTargetScope` calls this from its own `dispose()`.
  void dispose() {
    _subscription.close();
    _wordsSubscription?.close();
    unawaited(_changes.close());
  }

  /// The catalog text of every [LoopRequest.targetWordIds] entry that has
  /// already loaded, in order — `const []` if there are none woven in, or
  /// if the catalog has not resolved yet (a safe default: the hint simply
  /// stays generic until [wordsByIdProvider] fires [changes]).
  List<String> get _wovenWordTexts {
    final ids = _request.targetWordIds;
    if (ids.isEmpty) return const <String>[];
    final wordsById = _ref.read(wordsByIdProvider).value;
    if (wordsById == null) return const <String>[];
    return [
      for (final id in ids)
        if (wordsById[id] case final word?) word.lemma,
    ];
  }

  static MicPrompt _promptFor(
    TrainingLoopState loop,
    List<String> wovenWords,
  ) => switch (loop.phase) {
    LoopPhase.focus when loop.attemptStep == AttemptKind.first =>
      const MicPrompt(actionLabel: 'Grabar tu respuesta'),
    LoopPhase.focus => const MicPrompt(actionLabel: 'Grabar tu intento'),
    LoopPhase.feedback => const MicPrompt(actionLabel: 'Grabar tu repetición'),
    LoopPhase.comparison => MicPrompt(
      actionLabel: 'Grabar tu transferencia',
      hint: wovenWords.isEmpty
          ? 'Aplica lo que acabas de practicar.'
          : 'Usa ${_wordList(wovenWords)} en tu respuesta.',
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

  /// "«a»", "«a» y «b»", "«a», «b» y «c»" — weaving 1-3 words (decision
  /// #450.4's own limit, enforced upstream by `TrainingPlanner.planDay`)
  /// into one natural-Spanish list.
  static String _wordList(List<String> words) => switch (words.length) {
    1 => '«${words[0]}»',
    2 => '«${words[0]}» y «${words[1]}»',
    _ =>
      '${words.sublist(0, words.length - 1).map((w) => '«$w»').join(', ')} '
          'y «${words.last}»',
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
