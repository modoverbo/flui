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
    : _loop = LoopMicTarget(_ref, requestFor(_ref, wordId));

  final Ref _ref;
  final String wordId;
  final LoopMicTarget _loop;

  /// Called once [deliver] actually saves the first attempt — never on a
  /// blocked/failed/busy outcome.
  void Function()? onDelivered;

  /// This word's own [LoopRequest] — exposed so `WordSpeakPage`
  /// (`AppRoutes.wordSpeak`) resolves the exact same `TrainingLoopController`
  /// family instance this target already advanced.
  LoopRequest get request => requestFor(_ref, wordId);

  static LoopRequest requestFor(Ref ref, String wordId) => LoopRequest(
    context: TrainingContext.word,
    sessionId: ref.read(wordSpeakSessionIdProvider(wordId)),
    script: const LoopScript.wordUse(),
    targetWordIds: [wordId],
  );

  bool get _isFirstUnstarted =>
      _ref.read(trainingLoopControllerProvider(request)).loop.phase ==
      LoopPhase.focus;

  @override
  MicPrompt get prompt => _isFirstUnstarted
      ? const MicPrompt(actionLabel: 'Úsala en voz alta')
      : _loop.prompt;

  @override
  Duration get maxDuration => _loop.maxDuration;

  @override
  MicAvailability get availability => _loop.availability;

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
