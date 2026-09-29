import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/id/id_providers.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:flui/features/training/domain/training_loop.dart';
import 'package:flui/features/training/presentation/controllers/loop_mic_target.dart';
import 'package:flui/features/training/presentation/controllers/training_loop_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'word_speak_target.g.dart';

/// One word's own spoken-use session id, stable per [wordId] for the
/// lifetime of the app (`keepAlive`, unlike `TrainingLabModePage`'s own
/// autoDispose `labSessionIdProvider`) — [WordSpeakTarget] reads this from
/// several independent places (its own construction, `WordSpeakPage`
/// re-resolving the exact same `LoopRequest` after navigation), so it must
/// never mint a second id for the same word mid-flow.
@Riverpod(keepAlive: true)
String wordSpeakSessionId(Ref ref, String wordId) =>
    ref.read(idGeneratorProvider).generate();

/// PALABRAS' own spoken-use action (design §19.4's table: "`/words/:id` ->
/// `WordSpeakTarget` (first attempt, then push `/words/:id/speak`)", U17;
/// reuses U15b's mastery wiring — design D15).
///
/// Wraps a [LoopMicTarget] for `LoopScript.wordUse()`/`context = word`
/// instead of reimplementing its phase-to-availability mapping (D23:
/// capture/analysis plumbing belongs to `core/mic`/the shared training
/// loop, never a second copy per feature). This class only relabels the
/// very first (not-yet-started) prompt as "Úsala en voz alta" and, once
/// that first attempt is actually ACCEPTED (analyzed and saved), calls
/// [onDelivered] so the widget layer can push `AppRoutes.wordSpeak(wordId)`
/// — the rest of the loop (feedback, the repeat attempt, comparison)
/// continues there through the exact SAME `TrainingLoopController`
/// instance (same [LoopRequest], resolved by its own `LoopMicTarget` via
/// `TrainingLoopView`), never a second analysis of the first attempt.
final class WordSpeakTarget implements MicTarget {
  new(this._ref, this.wordId)
    : request = requestFor(_ref, wordId),
      _loop = LoopMicTarget(_ref, requestFor(_ref, wordId)) {
    resetIfFinished();
  }

  final Ref _ref;
  final String wordId;

  /// This word's own [LoopRequest] — exposed so `WordSpeakPage`
  /// (`AppRoutes.wordSpeak`) resolves the exact same `TrainingLoopController`
  /// family instance this target already advanced. Mutable: [resetIfFinished]
  /// replaces it (with a freshly-minted session id) once the wrapped loop
  /// has run its course, so this is never the SAME finished request forever.
  LoopRequest request;
  LoopMicTarget _loop;

  /// Called once [deliver] actually saves the first attempt — never on a
  /// blocked/failed/busy outcome.
  void Function()? onDelivered;

  static LoopRequest requestFor(Ref ref, String wordId) => LoopRequest(
    context: TrainingContext.word,
    sessionId: ref.read(wordSpeakSessionIdProvider(wordId)),
    script: const LoopScript.wordUse(),
    targetWordIds: [wordId],
  );

  bool get _isFirstUnstarted =>
      _ref.read(trainingLoopControllerProvider(request)).loop.phase ==
      LoopPhase.focus;

  /// `LoopScript.wordUse()` has no `transfer` step
  /// (`TrainingLoop._advanceWordUse` throws for it): its only two speak
  /// steps are `first` -> `feedback` -> `repeat` -> `comparison`, and
  /// `comparison` is as far as the domain
  /// ever advances it — there is no `LoopPhase.summary` for this script.
  /// `comparison` is therefore this loop's own finished state.
  bool get _isFinished =>
      _ref.read(trainingLoopControllerProvider(request)).loop.phase ==
      LoopPhase.comparison;

  /// Starts a fresh loop (new session id, new [TrainingLoopController]
  /// family instance) once the current one has run its course — otherwise
  /// re-entering this word's speak flow after finishing it once would be
  /// stuck: `wordUse` has no dedicated "finished" mapping (there is no
  /// `LoopPhase.summary` for it, only `comparison`), so `LoopMicTarget`
  /// keeps resolving `MicReady` with the `full` script's own transfer-step
  /// label ("Grabar tu transferencia") FOREVER for a script that has no
  /// transfer step — recording again there reaches
  /// `TrainingLoop._advanceWordUse`'s `throw StateError('wordUse has no
  /// transfer step')` (a pre-existing gap in `LoopMicTarget`'s shared phase
  /// mapping, not something this fix can safely patch without touching
  /// every OTHER script it also maps — flagged, not fixed, in this change).
  /// Minting a fresh loop on re-entry means the mic never sits in that
  /// state again once the user leaves and comes back.
  ///
  /// Called on construction (covers "leave `/words/:id`, come back": the
  /// autoDispose `wordSpeakTargetProvider` rebuilds a fresh [WordSpeakTarget]
  /// on every re-entry) and by `TodayWordTarget` on every rebuild that
  /// reuses the SAME delegate (the word stays today's due word without a
  /// navigation-driven reconstruction in between).
  ///
  /// Never resets a loop still in progress: a mid-flow exit (before
  /// `comparison`) must resume exactly where it left off (design says
  /// nothing to the contrary for word context; matches the resume pattern
  /// already established for daily sessions, `LoopResumePolicy`).
  ///
  /// Deliberately does NOT call `ref.invalidate` on the finished
  /// [TrainingLoopController] family entry — verified (in complete
  /// isolation AND in a real app run) to crash: `ref.invalidate` on a
  /// `keepAlive` class-based Notifier does not construct a fresh instance
  /// once it has zero listeners, so a later flush calls `build()` again on
  /// the SAME object and throws `LateInitializationError` on its `late
  /// final _request` field — reproducible from the framework's OWN
  /// scheduled refresh, not only from an explicit re-read. The finished
  /// entry is simply abandoned instead: nothing in this app ever reads
  /// that exact (now-superseded) [LoopRequest] again, so its stale
  /// `comparison` state is harmless — it stays cached (a bounded, modest
  /// memory footprint: one entry per DISTINCT word finished this app
  /// session, the same `keepAlive` tradeoff every other loop context in
  /// this app — lab, quick practice, diagnosis — already makes) rather
  /// than crashing the app trying to reclaim it.
  void resetIfFinished() {
    if (!_isFinished) return;
    _loop.dispose();
    _ref.invalidate(wordSpeakSessionIdProvider(wordId));
    request = requestFor(_ref, wordId);
    _loop = LoopMicTarget(_ref, request);
  }

  @override
  MicPrompt get prompt {
    if (_isFirstUnstarted) {
      return const MicPrompt(actionLabel: 'Úsala en voz alta');
    }
    if (_isFinished) return const MicPrompt(actionLabel: 'Practicar otra vez');
    return _loop.prompt;
  }

  @override
  Duration get maxDuration => _loop.maxDuration;

  /// Orchestrator review finding: `_loop.availability` alone would resolve
  /// `MicPassThrough` once finished (see `LoopMicTarget`'s own fix) — an
  /// honest "nothing more to offer" for a GENERIC loop target that cannot
  /// itself start a new session. `WordSpeakTarget` CAN (it owns
  /// [resetIfFinished]), so it offers a real action instead of falling
  /// through to the registry's fallback (quick practice): `MicPrepare`
  /// shows "Practicar otra vez" with no capture on that same activation —
  /// only [resetIfFinished] runs, minting a fresh loop; the FOLLOWING mic
  /// activation records that fresh loop's own first attempt normally.
  @override
  MicAvailability get availability {
    if (_isFinished) {
      return MicPrepare('Practicar otra vez', () async => resetIfFinished());
    }
    return _loop.availability;
  }

  @override
  Stream<void> get changes => _loop.changes;

  @override
  Future<MicDelivery> deliver(RecordedAudio audio) async {
    final result = await _loop.deliver(audio);
    if (result is MicAccepted) onDelivered?.call();
    return result;
  }

  void dispose() => _loop.dispose();
}

@riverpod
WordSpeakTarget wordSpeakTarget(Ref ref, String wordId) {
  final target = WordSpeakTarget(ref, wordId);
  ref.onDispose(target.dispose);
  return target;
}
