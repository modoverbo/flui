import 'package:flui/core/audio/data/just_audio_speech_player.dart';
import 'package:flui/core/audio/speech_player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

// `mapPlayerState` is the pure heart of `JustAudioSpeechPlayer`'s state
// wiring, extracted so it is testable without a real `AudioPlayer` (a real
// device/browser is out of scope for these unit tests, per U3).
void main() {
  test('idle processing state maps to idle', () {
    expect(
      mapPlayerState(PlayerState(false, ProcessingState.idle)),
      PlaybackStatus.idle,
    );
  });

  test('loading and buffering both map to loading', () {
    expect(
      mapPlayerState(PlayerState(false, ProcessingState.loading)),
      PlaybackStatus.loading,
    );
    expect(
      mapPlayerState(PlayerState(true, ProcessingState.buffering)),
      PlaybackStatus.loading,
    );
  });

  test('ready while playing maps to playing', () {
    expect(
      mapPlayerState(PlayerState(true, ProcessingState.ready)),
      PlaybackStatus.playing,
    );
  });

  test('ready while not yet playing maps to loading, not playing', () {
    expect(
      mapPlayerState(PlayerState(false, ProcessingState.ready)),
      PlaybackStatus.loading,
    );
  });

  test('completed maps to completed regardless of playing', () {
    expect(
      mapPlayerState(PlayerState(false, ProcessingState.completed)),
      PlaybackStatus.completed,
    );
    expect(
      mapPlayerState(PlayerState(true, ProcessingState.completed)),
      PlaybackStatus.completed,
    );
  });
}
