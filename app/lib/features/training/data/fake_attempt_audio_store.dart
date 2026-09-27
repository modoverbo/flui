import 'dart:typed_data';

import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/core/fake/fake_remote.dart';
import 'package:flui/features/training/domain/attempt_audio_store.dart';
import 'package:flui/features/training/domain/speaking_attempt.dart';

/// In-memory `speaking-audio` bucket + the `audio_status` it drives.
final class FakeAttemptAudioStore with FakeRemote implements AttemptAudioStore {
  new({required this.currentUserId, this.latency = Duration.zero});

  final String? Function() currentUserId;

  @override
  final Duration latency;

  final _statusByAttemptId = <String, AudioRetention>{};

  /// The current [AudioRetention] this store recorded for [attemptId], or
  /// `null` if [upload]/[delete] was never called for it.
  AudioRetention? statusOf(String attemptId) => _statusByAttemptId[attemptId];

  @override
  Future<void> upload({
    required String attemptId,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final failure = await simulateCall();
    final extension = extensionForAudioMime(mimeType);
    final userId = currentUserId();
    final next = failure != null || extension == null || userId == null
        ? const AudioRetention.failed()
        : AudioRetention.stored(
            path: '$userId/$attemptId.$extension',
            mime: mimeType,
          );
    // upload() is only ever called for an attempt the repository already
    // inserted as 'pending' (design part-3 §5's write order), so an
    // untracked attempt is treated as 'pending' here, not the DB's
    // unrelated 'none' default (see delete()'s different treatment below).
    final current =
        _statusByAttemptId[attemptId] ?? const AudioRetention.pending();
    if (AudioRetention.isAllowedTransition(current, next)) {
      _statusByAttemptId[attemptId] = next;
    }
    // A rejected transition (e.g. a failed retry on an already-'stored'
    // attempt) mirrors `speaking_attempts_guard_audio` rejecting the same
    // update server-side: the row is left unchanged.
  }

  @override
  Future<Result<void>> delete({required String attemptId}) async {
    if (await simulateCall() case final failure?) return Result.err(failure);
    final current = _statusByAttemptId[attemptId];
    if (!AudioRetention.isAllowedTransition(
      current,
      const AudioRetention.deleted(),
    )) {
      return const Result.err(UnexpectedFailure('attempt_not_stored'));
    }
    // Idempotent: an already-'deleted' attempt is a same-status no-op.
    _statusByAttemptId[attemptId] = const AudioRetention.deleted();
    return const Result.ok(null);
  }
}
