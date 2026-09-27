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
        // The 'stored' update failed (e.g. its response was lost) — the
        // uploaded object is never removed from here: a retried upload on
        // an attempt that already IS 'stored' is rejected by the server,
        // and a client that then deleted the object on that rejection
        // would destroy a correctly stored recording. Orphan objects (this
        // one, or one left by a client that never got to run this line at
        // all) are reconciled server-side by a scheduled sweep (U21),
        // which can read the true row state instead of guessing from a
        // possibly-lost response.
        await _markStatus(attemptId, 'failed');
      }
    } on Object catch (error, stackTrace) {
      // Fire-and-forget: an upload failure never reaches the caller, only
      // the attempt's audio_status. The call may have actually succeeded
      // server-side even though the client saw an error/timeout — never
      // remove the object client-side for the same reason as above.
      _logFailure('upload audio for', attemptId, error, stackTrace);
      await _markStatus(attemptId, 'failed');
    }
  }

  /// Returns whether the update was applied. A `false` result never throws
  /// — a failed status update is logged (never silently swallowed) and left
  /// for server-side reconciliation (U21), never compensated client-side.
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
