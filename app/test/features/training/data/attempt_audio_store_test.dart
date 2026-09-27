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

    // Regression guards (decision: orphan cleanup is server-side, U21, never
    // client compensation — see engram sdd/flui-eloquence-gym-refactor
    // decision-orphan-audio-cleanup). Every case below FAILS if upload()
    // ever issues a storage remove/delete request: an independent verifier
    // proved the previous client-side compensation deleted correctly stored
    // recordings (a retried upload on an already-'stored' attempt is
    // rejected by the server, and the compensation then removed the good
    // object; a 'stored' row update can succeed server-side while the
    // client sees an error, and the compensation deleted the good object
    // while the row kept pointing at nothing).
    test(
      'upload throwing over the network never issues a storage remove',
      () async {
        final recorder = SupabaseRecorder(
          respond: (request) {
            if (request.url.path.startsWith('/storage/v1/object/')) {
              throw http.ClientException('offline');
            }
            return null; // the 'failed' row update succeeds
          },
        );
        addTearDown(recorder.dispose);

        await SupabaseAttemptAudioStore(
          recorder.client,
          currentUserId: () => 'u1',
        ).upload(attemptId: 'a1', bytes: _bytes, mimeType: 'audio/wav');

        // The failing upload POST and the 'failed' row update are observed;
        // no DELETE request is ever issued.
        expect(recorder.requests, hasLength(2));
        expect(recorder.requests.any((r) => r.method == 'DELETE'), isFalse);
        final body =
            recorder.bodyOf(recorder.requests.last)! as Map<String, Object?>;
        expect(body['audio_status'], 'failed');
      },
    );

    test('an upload rejected with a conflict status never issues a storage '
        'remove', () async {
      final recorder = SupabaseRecorder(
        respond: (request) {
          if (request.url.path.startsWith('/storage/v1/object/')) {
            // A retried upload for an attempt already 'stored' is
            // rejected by the server (e.g. 409 Duplicate) — never a
            // thrown transport error.
            return http.Response(
              jsonEncode({
                'statusCode': '409',
                'error': 'Duplicate',
                'message': 'The resource already exists',
              }),
              409,
            );
          }
          return null; // the 'failed' row update attempt
        },
      );
      addTearDown(recorder.dispose);

      await SupabaseAttemptAudioStore(
        recorder.client,
        currentUserId: () => 'u1',
      ).upload(attemptId: 'a1', bytes: _bytes, mimeType: 'audio/wav');

      expect(recorder.requests, hasLength(2));
      expect(recorder.requests.any((r) => r.method == 'DELETE'), isFalse);
      expect(
        recorder.requests[0].url.path,
        '/storage/v1/object/speaking-audio/u1/a1.wav',
      );
      final body =
          recorder.bodyOf(recorder.requests.last)! as Map<String, Object?>;
      expect(body['audio_status'], 'failed');
    });

    test('a row-update failure after a successful upload never issues a '
        'storage remove, and a failed-status update is attempted', () async {
      final recorder = SupabaseRecorder(
        respond: (request) {
          if (request.url.path.startsWith('/storage/v1/object/')) {
            return {'Key': 'speaking-audio/u1/a1.wav'};
          }
          if (request.url.path == '/rest/v1/speaking_attempts') {
            // Both the 'stored' and the subsequent 'failed' update
            // attempts fail (e.g. the response is lost) — the object
            // stays in the bucket regardless; server-side reconciliation
            // (U21) owns cleanup, never the client.
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

      // upload POST, failed 'stored' update attempt, failed 'failed'
      // update attempt — no DELETE anywhere.
      expect(recorder.requests, hasLength(3));
      expect(recorder.requests.any((r) => r.method == 'DELETE'), isFalse);
      expect(
        recorder.requests[0].url.path,
        '/storage/v1/object/speaking-audio/u1/a1.wav',
      );
      expect(recorder.requests[1].url.path, '/rest/v1/speaking_attempts');
      final firstBody =
          recorder.bodyOf(recorder.requests[1])! as Map<String, Object?>;
      expect(firstBody['audio_status'], 'stored');
      expect(recorder.requests[2].url.path, '/rest/v1/speaking_attempts');
      final secondBody =
          recorder.bodyOf(recorder.requests[2])! as Map<String, Object?>;
      expect(secondBody['audio_status'], 'failed');
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
