import 'dart:typed_data';

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
    if (failure != null || extension == null || userId == null) {
      _statusByAttemptId[attemptId] = const AudioRetention.failed();
      return;
    }
    _statusByAttemptId[attemptId] = AudioRetention.stored(
      path: '$userId/$attemptId.$extension',
      mime: mimeType,
    );
  }

  @override
  Future<Result<void>> delete({
    required String attemptId,
    required String path,
  }) async {
    if (await simulateCall() case final failure?) return Result.err(failure);
    // Idempotent: succeeds whether or not an object was already there.
    _statusByAttemptId[attemptId] = const AudioRetention.deleted();
    return const Result.ok(null);
  }
}
