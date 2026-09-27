import 'dart:async';
import 'dart:typed_data';

import 'package:flui/core/audio/data/bytes_source.dart';
import 'package:flui/core/audio/data/bytes_source_stub.dart'
    if (dart.library.io) 'package:flui/core/audio/data/bytes_source_io.dart'
    if (dart.library.js_interop) 'package:flui/core/audio/data/bytes_source_web.dart';
import 'package:flui/core/audio/speech_player.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:just_audio/just_audio.dart';

/// `just_audio`-backed [SpeechPlayer] (design part-3 §3, D4). A persisted
/// attempt plays straight from its Storage signed URL; in-memory bytes go
/// through a platform-specific [InMemoryAudioSource] (U3 spike: web blob
/// URL, or a temp file on Android/iOS — `StreamAudioSource` fails on
/// Android without relaxing cleartext, which this change does not do).
final class JustAudioSpeechPlayer implements SpeechPlayer {
  new({AudioPlayer? player}) : _player = player ?? AudioPlayer() {
    _playerStateSubscription = _player.playerStateStream.listen(
      (state) => _emit(mapPlayerState(state)),
      onError: (Object _, StackTrace _) {
        unawaited(_releaseInMemorySource());
        _emit(PlaybackStatus.failed);
      },
    );
  }

  final AudioPlayer _player;
  late final StreamSubscription<PlayerState> _playerStateSubscription;
  final _statusController = StreamController<PlaybackStatus>.broadcast();
  InMemoryAudioSource? _inMemorySource;
  var _disposed = false;

  @override
  Stream<PlaybackStatus> get status => _statusController.stream;

  @override
  Future<Result<void>> playBytes(
    Uint8List bytes, {
    required String mimeType,
  }) async {
    if (_disposed) {
      return const Result<void>.err(UnexpectedFailure('disposed'));
    }
    await _releaseInMemorySource();
    if (bytes.isEmpty) {
      _emit(PlaybackStatus.unavailable);
      return const Result.ok(null);
    }
    final source = createInMemoryAudioSource();
    _inMemorySource = source;
    try {
      _emit(PlaybackStatus.loading);
      final uri = await source.prepare(bytes, mimeType);
      await _player.setAudioSource(AudioSource.uri(uri));
      await _player.play();
      return const Result.ok(null);
    } on Object catch (error) {
      await _releaseInMemorySource();
      _emit(PlaybackStatus.failed);
      return Result<void>.err(UnexpectedFailure(error));
    }
  }

  @override
  Future<Result<void>> playUrl(Uri url) async {
    if (_disposed) {
      return const Result<void>.err(UnexpectedFailure('disposed'));
    }
    await _releaseInMemorySource();
    try {
      _emit(PlaybackStatus.loading);
      await _player.setAudioSource(AudioSource.uri(url));
      await _player.play();
      return const Result.ok(null);
    } on Object catch (error) {
      _emit(PlaybackStatus.failed);
      return Result<void>.err(UnexpectedFailure(error));
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await _releaseInMemorySource();
    _emit(PlaybackStatus.idle);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _playerStateSubscription.cancel();
    await _releaseInMemorySource();
    await _player.dispose();
    await _statusController.close();
  }

  Future<void> _releaseInMemorySource() async {
    final source = _inMemorySource;
    _inMemorySource = null;
    await source?.release();
  }

  void _emit(PlaybackStatus next) {
    if (next == PlaybackStatus.completed) {
      unawaited(_releaseInMemorySource());
    }
    if (!_statusController.isClosed) _statusController.add(next);
  }
}

/// Maps a `just_audio` [PlayerState] to [PlaybackStatus] — pure, so it is
/// testable without a real [AudioPlayer]/device (see
/// `just_audio_speech_player_test.dart`).
PlaybackStatus mapPlayerState(PlayerState state) =>
    switch (state.processingState) {
      ProcessingState.idle => PlaybackStatus.idle,
      ProcessingState.loading ||
      ProcessingState.buffering => PlaybackStatus.loading,
      ProcessingState.ready =>
        state.playing ? PlaybackStatus.playing : PlaybackStatus.loading,
      ProcessingState.completed => PlaybackStatus.completed,
    };
