import 'dart:typed_data';

/// Prepares in-memory [Uint8List] bytes so a native player that cannot
/// stream raw bytes can open them as a `Uri` (design part-3 §3, U3 spike:
/// `just_audio`'s `StreamAudioSource` passes on Web via a blob URL but
/// fails on Android without relaxing cleartext, which this change does
/// not do). Each platform gets its own implementation — `WebBlobAudioSource`
/// (Blob + `createObjectURL`, in `bytes_source_web.dart`) or
/// `TempFileAudioSource` (a temp file, in `bytes_source_io.dart`) —
/// selected by conditional import in `just_audio_speech_player.dart`.
///
/// One [InMemoryAudioSource] instance is single-use: exactly one [prepare]
/// per instance, released by exactly one [release] before the instance is
/// dropped.
abstract interface class InMemoryAudioSource {
  /// Makes [bytes] playable, returning a `Uri` `just_audio` can open
  /// directly (a `blob:` URL on Web, a `file://` path on Android/iOS).
  Future<Uri> prepare(Uint8List bytes, String mimeType);

  /// Releases whatever [prepare] created (revokes the blob URL / deletes
  /// the temp file). Safe to call before [prepare], or more than once.
  Future<void> release();
}

/// Pure create-once/revoke-once bookkeeping for a web Blob URL (U3 spike:
/// blob URLs must be revoked after use or they leak for the page's
/// lifetime). Kept free of `dart:js_interop`/`package:web` so it is
/// testable on the VM, unlike the browser calls it guards in
/// `WebBlobAudioSource`. Models a single create/revoke cycle, matching
/// [InMemoryAudioSource]'s single-use contract — a new instance is created
/// per attempt, never reused across a second [InMemoryAudioSource.prepare].
final class BlobUrlLifecycle {
  var _created = false;
  var _revoked = false;

  /// True until [markCreated] has been called.
  bool get shouldCreate => !_created;

  /// True only between a [markCreated] and its matching [markRevoked].
  bool get shouldRevoke => _created && !_revoked;

  void markCreated() => _created = true;

  void markRevoked() => _revoked = true;
}
