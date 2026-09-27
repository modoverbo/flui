import 'dart:typed_data';

import 'package:flui/core/audio/data/fake_speech_player.dart';
import 'package:flui/core/audio/speech_player.dart';
import 'package:flui/core/error/result.dart';
import 'package:flutter_test/flutter_test.dart';

// Contract tests for `SpeechPlayer` (design part-3 §3, D4), driven through
// `FakeSpeechPlayer` — the same shape a `just_audio`-backed implementation
// must honor: play from in-memory bytes or a signed URL, report every
// state transition on `status`, and never leave the player stalled when
// there is nothing to play.
void main() {
  test(
    'playBytes with non-empty bytes goes idle -> loading -> playing',
    () async {
      final player = FakeSpeechPlayer();
      addTearDown(player.dispose);

      final expectation = expectLater(
        player.status,
        emitsInOrder([PlaybackStatus.loading, PlaybackStatus.playing]),
      );

      final result = await player.playBytes(
        Uint8List.fromList([1, 2, 3, 4]),
        mimeType: 'audio/wav',
      );

      await expectation;
      expect(result, isA<Ok<void>>());
    },
  );

  test('playBytes with empty bytes emits unavailable, never attempts '
      'playback', () async {
    final player = FakeSpeechPlayer();
    addTearDown(player.dispose);

    final expectation = expectLater(
      player.status,
      emitsInOrder([PlaybackStatus.unavailable]),
    );

    final result = await player.playBytes(Uint8List(0), mimeType: 'audio/wav');

    await expectation;
    expect(result, isA<Ok<void>>());
  });

  test('playUrl succeeds the same way as playBytes', () async {
    final player = FakeSpeechPlayer();
    addTearDown(player.dispose);

    final expectation = expectLater(
      player.status,
      emitsInOrder([PlaybackStatus.loading, PlaybackStatus.playing]),
    );

    final result = await player.playUrl(Uri.parse('https://example.com/a.wav'));

    await expectation;
    expect(result, isA<Ok<void>>());
  });

  test('failNext makes the next attempt reach failed and return Err', () async {
    final player = FakeSpeechPlayer()..failNext = true;
    addTearDown(player.dispose);

    final expectation = expectLater(
      player.status,
      emitsInOrder([PlaybackStatus.loading, PlaybackStatus.failed]),
    );

    final result = await player.playUrl(
      Uri.parse('https://example.com/missing.wav'),
    );

    await expectation;
    expect(result, isA<Err<void>>());
    // failNext resets after one attempt — a retry succeeds normally.
    expect(player.failNext, isFalse);
  });

  test('completeNow simulates natural playback end', () async {
    final player = FakeSpeechPlayer();
    addTearDown(player.dispose);

    final expectation = expectLater(
      player.status,
      emitsInOrder([
        PlaybackStatus.loading,
        PlaybackStatus.playing,
        PlaybackStatus.completed,
      ]),
    );

    await player.playBytes(Uint8List.fromList([9, 9]), mimeType: 'audio/wav');
    player.completeNow();

    await expectation;
  });

  test('stop returns to idle', () async {
    final player = FakeSpeechPlayer();
    addTearDown(player.dispose);

    await player.playBytes(Uint8List.fromList([1]), mimeType: 'audio/wav');

    final expectation = expectLater(
      player.status,
      emitsInOrder([PlaybackStatus.idle]),
    );

    await player.stop();
    await expectation;
  });

  test('dispose closes the status stream and further calls fail', () async {
    final player = FakeSpeechPlayer();

    await player.dispose();

    final expectation = expectLater(player.status, emitsDone);
    final result = await player.playUrl(Uri.parse('https://example.com/a'));

    expect(result, isA<Err<void>>());
    await expectation;
  });
}
