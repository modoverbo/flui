import 'dart:async';

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/features/vocabulary/presentation/controllers/word_speak_target.dart';
import 'package:flui/features/vocabulary/presentation/providers/my_words.dart';
import 'package:flui/features/vocabulary/presentation/providers/today_words.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'today_word_target.g.dart';

/// PALABRAS' own mic action on the words list itself (design §19.4's
/// table: "`/words` -> `TodayWordTarget` or passThrough", U17): the
/// earliest-due entry of [todayWordsProvider] (never a second selection
/// rule for "today's words"), delegated to a [WordSpeakTarget] so the mic
/// action from the LIST is byte-identical to the same action on that
/// word's own detail page (D23: one capture/analysis path, not a second
/// copy). `MicPassThrough` when nothing is due, so the registry's plain
/// fallback (quick practice, U23e) applies instead — never a lab-specific
/// fallback (decision #450).
final class TodayWordTarget implements MicTarget {
  new(this._ref) {
    _subscription = _ref.listen(todayWordsProvider, (_, _) => _rebuild());
    _rebuild();
  }

  final Ref _ref;
  final _changes = StreamController<void>.broadcast();
  late final ProviderSubscription<AsyncValue<List<WordEntry>>> _subscription;
  WordSpeakTarget? _delegate;
  StreamSubscription<void>? _delegateSubscription;

  /// Whether [todayWordsProvider] has resolved at least once. `false` (not
  /// yet confirmed) must NEVER resolve to [MicPassThrough]: the registry
  /// skips a passthrough target and resolves the fallback instead (design
  /// §19.4), and `MicController` only subscribes to whichever target it
  /// CURRENTLY resolves (`_subscribeToResolvedTarget`) — so a passthrough
  /// shown before the due word is even known would bind the controller to
  /// the FALLBACK's `changes`, never this target's, and a due word
  /// arriving moments later would silently never reach the mic label.
  bool _resolved = false;

  /// Called once [deliver] actually saves the top due word's first attempt
  /// — the widget layer navigates to `AppRoutes.wordSpeak(wordId)` in
  /// response (same pattern as `TodayStartTarget.onSessionStarted`).
  void Function(String wordId)? onWordSpeakStarted;

  void _rebuild() {
    final today = _ref.read(todayWordsProvider);
    _resolved = today.hasValue;
    final due = today.value ?? const [];
    final wordId = due.isEmpty ? null : due.first.word.id;
    if (wordId == _delegate?.wordId) {
      _changes.add(null);
      return;
    }
    unawaited(_delegateSubscription?.cancel());
    _delegate?.dispose();
    final delegate = wordId == null ? null : WordSpeakTarget(_ref, wordId);
    delegate?.onDelivered = wordId == null
        ? null
        : () => onWordSpeakStarted?.call(wordId);
    _delegateSubscription = delegate?.changes.listen((_) => _changes.add(null));
    _delegate = delegate;
    _changes.add(null);
  }

  @override
  MicPrompt get prompt =>
      _delegate?.prompt ?? const MicPrompt(actionLabel: 'Úsala en voz alta');

  @override
  Duration get maxDuration =>
      _delegate?.maxDuration ?? const Duration(seconds: 30);

  @override
  MicAvailability get availability {
    final delegate = _delegate;
    if (delegate != null) return delegate.availability;
    if (!_resolved) {
      // Still loading `todayWordsProvider`: never passthrough (see
      // `_resolved`'s own doc) — busy is accurate (nothing to record YET)
      // and, critically, keeps this target the one `MicController`
      // resolves and subscribes to.
      return const MicBusy('Cargando tus palabras de hoy…');
    }
    return const MicPassThrough();
  }

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<MicDelivery> deliver(RecordedAudio audio) {
    final delegate = _delegate;
    if (delegate == null) {
      return Future.value(
        const MicDeliveryFailed('No hay ninguna palabra activa hoy.'),
      );
    }
    return delegate.deliver(audio);
  }

  void disposeTarget() {
    _subscription.close();
    unawaited(_delegateSubscription?.cancel());
    _delegate?.dispose();
    unawaited(_changes.close());
  }
}

@Riverpod(keepAlive: true)
TodayWordTarget todayWordTarget(Ref ref) {
  final target = TodayWordTarget(ref);
  ref.onDispose(target.disposeTarget);
  return target;
}
