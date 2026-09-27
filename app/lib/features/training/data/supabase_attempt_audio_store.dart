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
      await _markStatus(attemptId, 'stored', path: path, mime: mimeType);
    } on Object catch (_) {
      // Fire-and-forget: an upload failure never reaches the caller, only
      // the attempt's audio_status.
      await _markStatus(attemptId, 'failed');
    }
  }

  Future<void> _markStatus(
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
    } on Object catch (_) {
      // Nothing left to report: the caller never awaits this outcome.
    }
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
