import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:flui/core/error/result.dart';
import 'package:flui/core/supabase/data_error_mapper.dart';
import 'package:flui/features/training/domain/attempt_audio_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The private `speaking-audio` bucket + the `speaking_attempts` row it
/// drives (design part-3 §5, column-scoped update grant on
/// `audio_status`/`audio_path`/`audio_mime`).
final class SupabaseAttemptAudioStore implements AttemptAudioStore {
  const new(this._client, {required this.currentUserId});

  static const _bucket = 'speaking-audio';

  final SupabaseClient _client;
  final String? Function() currentUserId;

  @override
  Future<void> upload({
    required String attemptId,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final userId = currentUserId();
    final extension = extensionForAudioMime(mimeType);
    if (userId == null || extension == null) {
      await _markStatus(attemptId, 'failed');
      return;
    }
    final path = '$userId/$attemptId.$extension';
    try {
      await _client.storage
          .from(_bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mimeType),
          );
      final stored = await _markStatus(
        attemptId,
        'stored',
        path: path,
        mime: mimeType,
      );
      if (!stored) {
        // The object landed in the bucket but nothing points at it: an
        // orphan with no 'stored' row would be invisible to every deletion
        // flow that walks stored rows (consent revocation, account
        // deletion, retention sweep) — remove it before giving up.
        await _compensateOrphan(attemptId, path);
      }
    } on Object catch (error, stackTrace) {
      // Fire-and-forget: an upload failure never reaches the caller, only
      // the attempt's audio_status. The call may have actually succeeded
      // server-side even though the client saw an error/timeout, so remove
      // whatever might have landed at [path] before marking the row failed.
      _logFailure('upload audio for', attemptId, error, stackTrace);
      await _compensateOrphan(attemptId, path);
    }
  }

  /// Best-effort removal of a possibly-orphaned object at [path], followed
  /// by marking [attemptId] `failed`. Removing an already-gone object is
  /// harmless (the storage API's delete is idempotent).
  Future<void> _compensateOrphan(String attemptId, String path) async {
    try {
      await _client.storage.from(_bucket).remove([path]);
    } on Object catch (error, stackTrace) {
      _logFailure(
        'remove orphaned audio object for',
        attemptId,
        error,
        stackTrace,
      );
    }
    await _markStatus(attemptId, 'failed');
  }

  /// Returns whether the update was applied. A `false` result never throws
  /// — the caller decides whether a failed status update leaves an orphan
  /// that needs compensating.
  Future<bool> _markStatus(
    String attemptId,
    String status, {
    String? path,
    String? mime,
  }) async {
    try {
      await _client
          .from('speaking_attempts')
          .update({
            'audio_status': status,
            'audio_path': ?path,
            'audio_mime': ?mime,
          })
          .eq('id', attemptId);
      return true;
    } on Object catch (error, stackTrace) {
      _logFailure('mark $status for', attemptId, error, stackTrace);
      return false;
    }
  }

  void _logFailure(
    String action,
    String attemptId,
    Object error,
    StackTrace stackTrace,
  ) {
    developer.log(
      'Failed to $action attempt $attemptId',
      name: 'SupabaseAttemptAudioStore',
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  Future<Result<void>> delete({
    required String attemptId,
    required String path,
  }) async {
    try {
      // The storage API's delete is idempotent: removing an already-gone
      // object still succeeds (design part-3 §5).
      await _client.storage.from(_bucket).remove([path]);
    } on Object catch (error) {
      return Result.err(mapDataError(error));
    }
    try {
      await _client
          .from('speaking_attempts')
          .update({'audio_status': 'deleted'})
          .eq('id', attemptId);
      return const Result.ok(null);
    } on Object catch (error) {
      return Result.err(mapDataError(error));
    }
  }
}
