import 'dart:typed_data';

import 'package:flui/core/error/result.dart';

/// Playback state exposed on [SpeechPlayer.status] (design part-3 §3, D4).
///
/// [unavailable] is this port's explicit "nothing to play" signal — e.g. an
/// empty in-memory capture — kept distinct from [failed] (an attempt that
/// broke) so a caller never renders a stalled loading spinner over silence
/// (spec `audio-capture-playback`, "No stored audio").
enum PlaybackStatus { idle, loading, playing, completed, failed, unavailable }

/// Plays the user's own speech: a just-captured in-memory recording, or a
/// persisted attempt fetched from Storage via a signed URL (design part-3
/// §3). Implemented with `just_audio` (U3): web-capable on both Web and
/// Android/iOS.
abstract interface class SpeechPlayer {
  /// Plays [bytes] (e.g. a just-finished `RecordedAudio.bytes`) directly,
  /// with no network round-trip. Empty [bytes] never attempts playback and
  /// instead emits [PlaybackStatus.unavailable] on [status].
  ///
  /// The returned [Result] only reflects whether the call was accepted
  /// (e.g. rejected because this player was already [dispose]d); the
  /// actual playback outcome is reported asynchronously on [status].
  Future<Result<void>> playBytes(Uint8List bytes, {required String mimeType});

  /// Plays a persisted attempt from a signed Storage URL. A network
  /// failure or a 403/404 response reaches [PlaybackStatus.failed] on
  /// [status] (never an indefinite [PlaybackStatus.loading]).
  Future<Result<void>> playUrl(Uri url);

  /// Stops any in-progress playback and releases the current source (temp
  /// file / blob URL), returning to [PlaybackStatus.idle].
  Future<void> stop();

  /// Every playback state transition, in order.
  Stream<PlaybackStatus> get status;

  /// Releases the player and any resource it is holding (temp file / blob
  /// URL). Safe to call once the widget owning this player is gone; no
  /// further [playBytes]/[playUrl] call succeeds afterwards.
  Future<void> dispose();
}
