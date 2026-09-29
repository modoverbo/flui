import 'dart:typed_data';

import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/core/fake/fake_remote.dart';
import 'package:flui/features/training/domain/attempt_audio_store.dart';
import 'package:flui/features/training/domain/speaking_attempt.dart';

/// In-memory `speaking-audio` bucket + the `audio_status` it drives.
final class FakeAttemptAudioStore with FakeRemote implements AttemptAudioStore {
  new({
    required this.currentUserId,
    this.latency = Duration.zero,
    this.onAudioChanged,
  });

  final String? Function() currentUserId;

  /// Notified with every status this store itself writes (`upload`'s
  /// `stored`/`failed`, `delete`'s `deleted`) — wired to a paired
  /// `FakeSpeakingAttemptRepository.updateAudio` (U18b) so a caller that
  /// re-fetches attempts afterwards sees the same status this store
  /// reports via [statusOf], exactly as one real `speaking_attempts` row
  /// would. `null` (the default) keeps every existing caller unchanged.
  final void Function(String attemptId, AudioRetention audio)? onAudioChanged;

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
    // Mirrors `speaking_audio_insert_own` (the STORAGE object-insert
    // policy, migration `20260913120800_speaking_history.sql`): an object
    // insert is accepted only while the row is currently 'pending'. upload()
    // is only ever called for an attempt the repository already inserted as
    // 'pending' (design part-3 §5's write order), so an untracked attempt is
    // treated as 'pending' here too, not the DB's unrelated 'none' default
    // (see delete()'s different treatment below). Any other current status
    // — 'stored' (already uploaded) or 'failed' (never re-armed to
    // 'pending', see U13a.6) — is rejected the same way a real 403 rejects
    // it: the row is left completely unchanged, path/mime included.
    final current = _statusByAttemptId[attemptId];
    if (current != null && current is! AudioRetentionPending) return;
    final extension = extensionForAudioMime(mimeType);
    final userId = currentUserId();
    final next = failure != null || extension == null || userId == null
        ? const AudioRetention.failed()
        : AudioRetention.stored(
            path: '$userId/$attemptId.$extension',
            mime: mimeType,
          );
    _statusByAttemptId[attemptId] = next;
    onAudioChanged?.call(attemptId, next);
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
    onAudioChanged?.call(attemptId, const AudioRetention.deleted());
    return const Result.ok(null);
  }

  @override
  Future<Result<Uri>> signedUrlFor({required String path}) async {
    if (await simulateCall() case final failure?) return Result.err(failure);
    final userId = currentUserId();
    if (userId == null) return const Result.err(notSignedInFailure);
    // Mirrors the storage `select` policy scoping reads to the caller's own
    // `<uid>/` folder — a path this store was never handed for this user
    // never resolves to a URL, real or fake.
    if (!path.startsWith('$userId/')) {
      return const Result.err(UnexpectedFailure('not_own_path'));
    }
    return Result.ok(Uri.parse('fake://speaking-audio/$path'));
  }
}
