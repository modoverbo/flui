import 'dart:typed_data';

import 'package:flui/core/error/result.dart';

/// Stores the recorded audio of an eligible `speaking_attempts` row (design
/// part-3 §5 "Milestones" write order) and later removes it.
///
/// Both operations own the row's `audio_status` transition themselves — they
/// are a separate concern from `SpeakingAttemptRepository`, which only ever
/// inserts a row with `audio_status` already `pending` or `none`. The port
/// takes raw [Uint8List] bytes and a MIME type rather than `core/audio`'s
/// `RecordedAudio` — `features/training/domain` stays pure and never depends
/// on the audio pipeline (`app/test/architecture/import_rules_test.dart`); a
/// caller in the presentation layer unpacks its own `RecordedAudio` first.
abstract interface class AttemptAudioStore {
  /// Uploads [bytes] as `<uid>/<attemptId>.<ext>` in the private
  /// `speaking-audio` bucket, then marks the attempt `stored` (with its
  /// path/mime) on success or `failed` otherwise.
  ///
  /// Never throws and never returns a value: this is fire-and-forget by
  /// design — training never waits on upload (design part-3 §5). A caller
  /// that wants completion for its own bookkeeping may still `await` it.
  Future<void> upload({
    required String attemptId,
    required Uint8List bytes,
    required String mimeType,
  });

  /// Removes the stored object referenced by [attemptId]'s own row — the
  /// object path is resolved client-side through an RLS-scoped select of
  /// the attempt's own row, never trusted from a caller-supplied value, so
  /// a caller can never remove another attempt's object.
  ///
  /// Requires the row to currently be `stored`; anything else (never
  /// uploaded, still `pending`/`failed`) fails. Idempotent when the row is
  /// already `deleted`: succeeds without a storage call.
  ///
  /// The row is marked `deleted` BEFORE the object is removed: if the
  /// object removal itself then fails, the row is already consistent and
  /// the orphaned object is reconciled server-side by the retention sweep
  /// (24 h grace period) rather than left pointing at a missing object.
  Future<Result<void>> delete({required String attemptId});

  /// A time-limited signed URL to play back the object at [path] (design
  /// part-3 §3's playback contract: 300 s TTL) — [path] is an already-known
  /// `AudioRetentionStored.path` from the attempt's own row, never
  /// reconstructed from an id, so a caller can only ever ask for a path it
  /// was already handed (RLS's own-folder select policy still applies
  /// server-side; a path outside the caller's own folder fails).
  Future<Result<Uri>> signedUrlFor({required String path});
}

/// Maps a `speaking_attempts.audio_mime` / bucket-allowed MIME type to the
/// file extension its stored object path carries.
///
/// Returns `null` for anything outside the bucket's `allowed_mime_types`
/// (design part-3 §5) — callers must treat that as an upload failure rather
/// than storing an object under a misleading extension.
String? extensionForAudioMime(String mimeType) => switch (mimeType) {
  'audio/wav' => 'wav',
  'audio/webm' => 'webm',
  'audio/ogg' => 'ogg',
  'audio/mp4' => 'mp4',
  _ => null,
};
