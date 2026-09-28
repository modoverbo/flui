import 'dart:async';

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/id/id_providers.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/features/training/domain/challenge.dart';
import 'package:flui/features/training/domain/quick_practice_picker.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:flui/features/training/domain/training_loop.dart';
import 'package:flui/features/training/presentation/controllers/training_loop_controller.dart';
import 'package:flui/features/training/presentation/providers/training_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'quick_practice_target.g.dart';

const _defaultMaxDuration = Duration(seconds: 30);
const _maxCeiling = Duration(seconds: 60);
const _usedWithinDays = 7;

/// The registry's quick-practice fallback (design §19.13; decision
/// #450.3, supersedes design D27's immediate-capture default and U23b's
/// `ExplainedFallbackTarget`): prompt-first, never immediate capture. The
/// FIRST activation only picks a challenge and prepares the panel
/// (`MicAvailability.MicPrepare`, no capture); the very NEXT activation
/// records for that same picked challenge.
///
/// `has_access=false` never reaches this target's own logic at all —
/// `MicController._beginCapture` checks its own access latch BEFORE ever
/// resolving the registry (design §19.5 precedence item 2), so the
/// paywall sheet shows instead and [_activate] is never called. This
/// target has no access-checking logic of its own for that reason.
final class QuickPracticeTarget implements MicTarget {
  new(this._ref);

  final Ref _ref;
  final _changes = StreamController<void>.broadcast();

  Challenge? _picked;
  LoopRequest? _request;
  bool _prepared = false;

  /// The request currently backing the quick-practice panel — set once
  /// [_activate] resolves, and kept alive through delivery/feedback/summary
  /// (unlike [_prepared], which resets right after [deliver] so the mic is
  /// immediately ready to start a FRESH quick practice) until [dismiss] or
  /// [another] replaces it. `null` before the first activation, or once
  /// dismissed.
  LoopRequest? get currentRequest => _request;

  /// The challenge [currentRequest] answers, for the panel's prompt/cue —
  /// `null` when the catalog had nothing to offer.
  Challenge? get currentChallenge => _picked;

  @override
  MicPrompt get prompt => _prepared
      ? MicPrompt(actionLabel: 'Responder', hint: _picked?.prompt)
      : const MicPrompt(actionLabel: 'Practicar en voz alta');

  @override
  Duration get maxDuration {
    final target = _picked?.targetDuration ?? _defaultMaxDuration;
    final scaled = target * 1.5;
    return scaled > _maxCeiling ? _maxCeiling : scaled;
  }

  @override
  MicAvailability get availability =>
      _prepared ? const MicReady() : MicPrepare(prompt.actionLabel, _activate);

  @override
  Stream<void> get changes => _changes.stream;

  Future<void> _activate() async {
    final catalog =
        (await _ref.read(challengeRepositoryProvider).fetchCatalog())
            .valueOrNull ??
        const <Challenge>[];
    final since = _ref
        .read(clockProvider)
        .localToday()
        .addDays(-_usedWithinDays);
    final used =
        (await _ref
                .read(speakingAttemptRepositoryProvider)
                .usedChallengeIdsSince(since))
            .valueOrNull ??
        const <String>{};
    _picked = const QuickPracticePicker().pick(
      publishedChallenges: catalog,
      recentlyUsedChallengeIds: used,
    );
    _request = LoopRequest(
      context: TrainingContext.quick,
      sessionId: _ref.read(idGeneratorProvider).generate(),
      script: const LoopScript.quick(),
      challengeId: _picked?.id,
    );
    _prepared = true;
    _changes.add(null);
  }

  @override
  Future<MicDelivery> deliver(RecordedAudio audio) async {
    final request = _request;
    // Ready for a FRESH quick practice immediately, independent of how
    // long the panel keeps showing this one's feedback/summary.
    _prepared = false;
    _changes.add(null);
    if (request == null) {
      return const MicDeliveryFailed(
        'No hay ningún reto disponible ahora mismo.',
      );
    }
    return await _ref
        .read(trainingLoopControllerProvider(request).notifier)
        .submit(audio);
  }

  /// "Otro reto" (design §19.13): re-picks without consuming a gesture or
  /// quota — a free tap the panel offers.
  Future<void> another() => _activate();

  /// "Cerrar", or navigating away before a second activation (design
  /// §19.13: "nothing was ever captured, so there is nothing to cancel"):
  /// discards the prepared/finished state. The next activation starts a
  /// brand-new quick practice from scratch.
  void dismiss() {
    _picked = null;
    _request = null;
    _prepared = false;
    _changes.add(null);
  }

  void disposeTarget() => unawaited(_changes.close());
}

@Riverpod(keepAlive: true)
QuickPracticeTarget quickPracticeTarget(Ref ref) {
  final target = QuickPracticeTarget(ref);
  ref.onDispose(target.disposeTarget);
  return target;
}
