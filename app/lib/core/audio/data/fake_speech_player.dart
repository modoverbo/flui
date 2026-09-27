import 'dart:async';
import 'dart:typed_data';

import 'package:flui/core/audio/speech_player.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';

/// A controllable [SpeechPlayer] for tests and the fake app backend
/// (design part-3 §3). Every call goes through [PlaybackStatus.loading]
/// before settling, exactly like the `just_audio`-backed adapter.
///
/// Set [failNext] before a call to make that ONE playback attempt reach
/// [PlaybackStatus.failed] instead of [PlaybackStatus.playing]; call
/// [completeNow] to simulate the current source reaching its natural end.
final class FakeSpeechPlayer implements SpeechPlayer {
  final _statusController = StreamController<PlaybackStatus>.broadcast();
  var _disposed = false;

  /// When true, the NEXT [playBytes]/[playUrl] call reaches
  /// [PlaybackStatus.failed] and resets to false — a single-shot toggle so
  /// a retry after a simulated failure succeeds normally.
  bool failNext = false;

  @override
  Stream<PlaybackStatus> get status => _statusController.stream;

  @override
  Future<Result<void>> playBytes(
    Uint8List bytes, {
    required String mimeType,
  }) async {
    if (_disposed) return const Result<void>.err(UnexpectedFailure('disposed'));
    if (bytes.isEmpty) {
      _emit(PlaybackStatus.unavailable);
      return const Result.ok(null);
    }
    return await _play();
  }

  @override
  Future<Result<void>> playUrl(Uri url) async {
    if (_disposed) return const Result<void>.err(UnexpectedFailure('disposed'));
    return await _play();
  }

  Future<Result<void>> _play() async {
    _emit(PlaybackStatus.loading);
    if (failNext) {
      failNext = false;
      _emit(PlaybackStatus.failed);
      return const Result<void>.err(UnexpectedFailure('fake playback failure'));
    }
    _emit(PlaybackStatus.playing);
    return const Result.ok(null);
  }

  /// Test/dev helper: simulates the current source reaching its natural
  /// end, as `just_audio`'s `ProcessingState.completed` would.
  void completeNow() => _emit(PlaybackStatus.completed);

  @override
  Future<void> stop() async {
    if (_disposed) return;
    _emit(PlaybackStatus.idle);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _statusController.close();
  }

  void _emit(PlaybackStatus next) {
    if (!_statusController.isClosed) _statusController.add(next);
  }
}
