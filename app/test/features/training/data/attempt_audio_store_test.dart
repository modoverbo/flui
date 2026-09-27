import 'dart:convert';
import 'dart:typed_data';

import 'package:flui/core/error/failure.dart';
import 'package:flui/features/training/data/fake_attempt_audio_store.dart';
import 'package:flui/features/training/data/supabase_attempt_audio_store.dart';
import 'package:flui/features/training/domain/attempt_audio_store.dart';
import 'package:flui/features/training/domain/speaking_attempt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../../helpers/supabase_recorder.dart';

final _bytes = Uint8List.fromList([1, 2, 3]);

void main() {
  group('extensionForAudioMime', () {
    test('maps every bucket-allowed mime type', () {
      expect(extensionForAudioMime('audio/wav'), 'wav');
      expect(extensionForAudioMime('audio/webm'), 'webm');
      expect(extensionForAudioMime('audio/ogg'), 'ogg');
      expect(extensionForAudioMime('audio/mp4'), 'mp4');
    });

    test('is null for an unsupported mime type', () {
      expect(extensionForAudioMime('audio/aac'), isNull);
    });
  });

  group('FakeAttemptAudioStore', () {
    test('upload success marks the attempt stored', () async {
      final store = FakeAttemptAudioStore(currentUserId: () => 'u1');

      await store.upload(attemptId: 'a1', bytes: _bytes, mimeType: 'audio/wav');

      expect(
        store.statusOf('a1'),
        const AudioRetention.stored(path: 'u1/a1.wav', mime: 'audio/wav'),
      );
    });

    test('upload failure marks the attempt failed without throwing', () async {
      final store = FakeAttemptAudioStore(currentUserId: () => 'u1')
        ..nextFailure = const NetworkFailure();

      await store.upload(attemptId: 'a1', bytes: _bytes, mimeType: 'audio/wav');

      expect(store.statusOf('a1'), const AudioRetention.failed());
    });

    test('an unsupported mime type marks the attempt failed', () async {
      final store = FakeAttemptAudioStore(currentUserId: () => 'u1');

      await store.upload(attemptId: 'a1', bytes: _bytes, mimeType: 'audio/aac');

      expect(store.statusOf('a1'), const AudioRetention.failed());
    });

    test('deletion is idempotent and marks the attempt deleted', () async {
      final store = FakeAttemptAudioStore(currentUserId: () => 'u1');
      await store.upload(attemptId: 'a1', bytes: _bytes, mimeType: 'audio/wav');

      final first = await store.delete(attemptId: 'a1', path: 'u1/a1.wav');
      final second = await store.delete(attemptId: 'a1', path: 'u1/a1.wav');

      expect(first.isOk, isTrue);
      expect(second.isOk, isTrue);
      expect(store.statusOf('a1'), const AudioRetention.deleted());
    });
  });

  group('SupabaseAttemptAudioStore', () {
    test('upload writes the object then marks the row stored', () async {
      final recorder = SupabaseRecorder(
        respond: (request) {
          if (request.url.path.startsWith('/storage/v1/object/')) {
            return {'Key': 'speaking-audio/u1/a1.wav'};
          }
          return null;
        },
      );
      addTearDown(recorder.dispose);

      await SupabaseAttemptAudioStore(
        recorder.client,
        currentUserId: () => 'u1',
      ).upload(attemptId: 'a1', bytes: _bytes, mimeType: 'audio/wav');

      expect(recorder.requests, hasLength(2));
      final uploadRequest = recorder.requests.first;
      expect(uploadRequest.method, 'POST');
      expect(
        uploadRequest.url.path,
        '/storage/v1/object/speaking-audio/u1/a1.wav',
      );
      final updateRequest = recorder.requests.last;
      expect(updateRequest.url.path, '/rest/v1/speaking_attempts');
      final body = recorder.bodyOf(updateRequest)! as Map<String, Object?>;
      expect(body['audio_status'], 'stored');
      expect(body['audio_path'], 'u1/a1.wav');
      expect(body['audio_mime'], 'audio/wav');
    });

    test('a storage failure marks the row failed without throwing', () async {
      final recorder = SupabaseRecorder(
        respond: (request) {
          if (request.url.path.startsWith('/storage/v1/object/')) {
            throw http.ClientException('offline');
          }
          return null;
        },
      );
      addTearDown(recorder.dispose);

      await SupabaseAttemptAudioStore(
        recorder.client,
        currentUserId: () => 'u1',
      ).upload(attemptId: 'a1', bytes: _bytes, mimeType: 'audio/wav');

      expect(recorder.requests, hasLength(2));
      final body =
          recorder.bodyOf(recorder.requests.last)! as Map<String, Object?>;
      expect(body['audio_status'], 'failed');
    });

    test('delete removes the object then marks the row deleted', () async {
      final recorder = SupabaseRecorder(
        respond: (request) {
          if (request.url.path == '/storage/v1/object/speaking-audio') {
            return <Object?>[];
          }
          return null;
        },
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseAttemptAudioStore(
        recorder.client,
        currentUserId: () => 'u1',
      ).delete(attemptId: 'a1', path: 'u1/a1.wav');

      expect(result.isOk, isTrue);
      final removeRequest = recorder.requests.first;
      expect(removeRequest.method, 'DELETE');
      expect(jsonDecode(removeRequest.body), {
        'prefixes': ['u1/a1.wav'],
      });
      final updateRequest = recorder.requests.last;
      expect(updateRequest.url.path, '/rest/v1/speaking_attempts');
      final body = recorder.bodyOf(updateRequest)! as Map<String, Object?>;
      expect(body['audio_status'], 'deleted');
    });

    test('maps a storage transport error to a network failure', () async {
      final recorder = SupabaseRecorder(
        respond: (_) => throw http.ClientException('offline'),
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseAttemptAudioStore(
        recorder.client,
        currentUserId: () => 'u1',
      ).delete(attemptId: 'a1', path: 'u1/a1.wav');

      expect(result.failureOrNull, const NetworkFailure());
    });
  });
}
