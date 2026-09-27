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

AudioRetention _stateFor(String wireStatus) => switch (wireStatus) {
  'none' => const AudioRetention.none(),
  'pending' => const AudioRetention.pending(),
  'stored' => const AudioRetention.stored(path: 'u1/a1.wav', mime: 'audio/wav'),
  'failed' => const AudioRetention.failed(),
  'deleted' => const AudioRetention.deleted(),
  _ => throw ArgumentError(wireStatus),
};

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

  group('AudioRetention.isAllowedTransition (mirrors '
      'speaking_attempts_guard_audio)', () {
    // Exhaustive truth table over the guard trigger's 5 statuses (migration
    // 20260913120800_speaking_history.sql): pending->stored|failed,
    // failed->pending|stored, stored->deleted, same-status always a no-op,
    // none/deleted terminal, everything else rejected.
    const allowed = {
      'none->none',
      'pending->pending',
      'stored->stored',
      'failed->failed',
      'deleted->deleted',
      'pending->stored',
      'pending->failed',
      'failed->pending',
      'failed->stored',
      'stored->deleted',
    };
    const statuses = ['none', 'pending', 'stored', 'failed', 'deleted'];

    for (final from in statuses) {
      for (final to in statuses) {
        final key = '$from->$to';
        test(key, () {
          expect(
            AudioRetention.isAllowedTransition(_stateFor(from), _stateFor(to)),
            allowed.contains(key),
            reason: key,
          );
        });
      }
    }

    test('a row that was never written (null) is treated as none', () {
      expect(
        AudioRetention.isAllowedTransition(
          null,
          const AudioRetention.pending(),
        ),
        isFalse,
      );
      expect(
        AudioRetention.isAllowedTransition(null, const AudioRetention.none()),
        isTrue,
      );
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

    // Shared contract with SupabaseAttemptAudioStore's equivalent group
    // below (GAP C): a failed retry on an already-'stored' attempt must
    // never flip it to 'failed', mirroring the DB guard trigger rejecting
    // that exact transition server-side.
    test('a failed retry on an already-stored attempt does not flip it to '
        'failed (mirrors the DB guard trigger)', () async {
      final store = FakeAttemptAudioStore(currentUserId: () => 'u1');
      await store.upload(attemptId: 'a1', bytes: _bytes, mimeType: 'audio/wav');
      expect(store.statusOf('a1'), isA<AudioRetentionStored>());

      store.nextFailure = const NetworkFailure();
      await store.upload(attemptId: 'a1', bytes: _bytes, mimeType: 'audio/wav');

      expect(store.statusOf('a1'), isA<AudioRetentionStored>());
    });

    // Mirrors `speaking_audio_insert_own` (the STORAGE object-insert policy,
    // not the wider row-update guard trigger): an object insert is only
    // accepted while the row is 'pending', so a re-upload on an
    // already-'stored' attempt must never overwrite its path/mime, even
    // when the retry carries different bytes/mime type.
    test('a re-upload on an already-stored attempt does not change its path '
        "or mime (storage only accepts an insert while 'pending')", () async {
      final store = FakeAttemptAudioStore(currentUserId: () => 'u1');
      await store.upload(attemptId: 'a1', bytes: _bytes, mimeType: 'audio/wav');
      expect(
        store.statusOf('a1'),
        const AudioRetention.stored(path: 'u1/a1.wav', mime: 'audio/wav'),
      );

      await store.upload(
        attemptId: 'a1',
        bytes: _bytes,
        mimeType: 'audio/webm',
      );

      expect(
        store.statusOf('a1'),
        const AudioRetention.stored(path: 'u1/a1.wav', mime: 'audio/wav'),
      );
    });

    // Same storage-policy rule as above: a row that is already 'failed' is
    // also not 'pending', so a direct retry (without first re-arming the
    // row back to 'pending', per U13a.6) is rejected the same way a real
    // 403 rejects it — the attempt simply stays 'failed'.
    test('an upload on an already-failed attempt is rejected like the real '
        "403 and stays 'failed'", () async {
      final store = FakeAttemptAudioStore(currentUserId: () => 'u1')
        ..nextFailure = const NetworkFailure();
      await store.upload(attemptId: 'a1', bytes: _bytes, mimeType: 'audio/wav');
      expect(store.statusOf('a1'), const AudioRetention.failed());

      // No queued failure this time: a real retry would still be rejected
      // by speaking_audio_insert_own before ever reaching the network,
      // because the row is not 'pending'.
      await store.upload(attemptId: 'a1', bytes: _bytes, mimeType: 'audio/wav');

      expect(store.statusOf('a1'), const AudioRetention.failed());
    });

    test('deletion is idempotent and marks the attempt deleted', () async {
      final store = FakeAttemptAudioStore(currentUserId: () => 'u1');
      await store.upload(attemptId: 'a1', bytes: _bytes, mimeType: 'audio/wav');

      final first = await store.delete(attemptId: 'a1');
      final second = await store.delete(attemptId: 'a1');

      expect(first.isOk, isTrue);
      expect(second.isOk, isTrue);
      expect(store.statusOf('a1'), const AudioRetention.deleted());
    });

    // Shared contract with SupabaseAttemptAudioStore's equivalent group
    // below (GAP C): delete() on a non-stored, non-deleted attempt fails
    // like the real store, mirroring the guard trigger's `stored ->
    // deleted`-only rule. A 'pending' attempt's row was inserted but never
    // uploaded — the Fake has no way to record a literal
    // `AudioRetention.pending` value at rest (upload() only ever writes
    // 'stored'/'failed'), so this untracked/never-called-upload() state IS
    // that 'pending' case (see upload()'s own comment above).
    test('delete() on a pending attempt (never uploaded) fails and stays '
        'untracked', () async {
      final store = FakeAttemptAudioStore(currentUserId: () => 'u1');

      final result = await store.delete(attemptId: 'a1');

      expect(result.isOk, isFalse);
      expect(store.statusOf('a1'), isNull);
    });

    test("delete() on a failed attempt fails and keeps it 'failed'", () async {
      final store = FakeAttemptAudioStore(currentUserId: () => 'u1')
        ..nextFailure = const NetworkFailure();
      await store.upload(attemptId: 'a1', bytes: _bytes, mimeType: 'audio/wav');
      expect(store.statusOf('a1'), const AudioRetention.failed());

      final result = await store.delete(attemptId: 'a1');

      expect(result.isOk, isFalse);
      expect(store.statusOf('a1'), const AudioRetention.failed());
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
      await pumpEventQueue();

      expect(recorder.requests, hasLength(2));
      final uploadRequest = recorder.requests.first;
      expect(uploadRequest.method, 'POST');
      expect(
        uploadRequest.url.path,
        '/storage/v1/object/speaking-audio/u1/a1.wav',
      );
      // Never overwrite an existing object: retried/duplicate uploads must
      // be rejected by the server (and handled as a failure below), not
      // silently overwritten.
      expect(uploadRequest.headers['x-upsert'], 'false');
      final updateRequest = recorder.requests.last;
      expect(updateRequest.url.path, '/rest/v1/speaking_attempts');
      final body = recorder.bodyOf(updateRequest)! as Map<String, Object?>;
      expect(body['audio_status'], 'stored');
      expect(body['audio_path'], 'u1/a1.wav');
      expect(body['audio_mime'], 'audio/wav');
    });

    test("upload's early-return branch (no signed-in user) never issues a "
        'storage request', () async {
      final recorder = SupabaseRecorder(respond: (request) => null);
      addTearDown(recorder.dispose);

      await SupabaseAttemptAudioStore(
        recorder.client,
        currentUserId: () => null,
      ).upload(attemptId: 'a1', bytes: _bytes, mimeType: 'audio/wav');
      await pumpEventQueue();

      expect(
        recorder.requests.any(
          (r) => r.url.path.startsWith('/storage/v1/object/'),
        ),
        isFalse,
      );
      expect(recorder.requests, hasLength(1));
      final body =
          recorder.bodyOf(recorder.requests.single)! as Map<String, Object?>;
      expect(body['audio_status'], 'failed');
    });

    test("upload's early-return branch (unsupported mime type) never issues "
        'a storage request', () async {
      final recorder = SupabaseRecorder(respond: (request) => null);
      addTearDown(recorder.dispose);

      await SupabaseAttemptAudioStore(
        recorder.client,
        currentUserId: () => 'u1',
      ).upload(attemptId: 'a1', bytes: _bytes, mimeType: 'audio/aac');
      await pumpEventQueue();

      expect(
        recorder.requests.any(
          (r) => r.url.path.startsWith('/storage/v1/object/'),
        ),
        isFalse,
      );
      expect(recorder.requests, hasLength(1));
      final body =
          recorder.bodyOf(recorder.requests.single)! as Map<String, Object?>;
      expect(body['audio_status'], 'failed');
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
    // while the row kept pointing at nothing). `pumpEventQueue()` drains any
    // fire-and-forget (`unawaited`/`.ignore()`) remove call before each "no
    // DELETE" assertion, since a plain `await upload()` would not observe
    // one.
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
        await pumpEventQueue();

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
      await pumpEventQueue();

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

    test('an upload rejected because the attempt is no longer pending (RLS) '
        'never issues a storage remove', () async {
      final recorder = SupabaseRecorder(
        respond: (request) {
          if (request.url.path.startsWith('/storage/v1/object/')) {
            // speaking_audio_insert_own only allows an upload into a
            // 'pending' attempt — retrying an upload for an attempt
            // already 'stored' is rejected by RLS as 403, never a
            // thrown transport error.
            return http.Response(
              jsonEncode({
                'statusCode': '403',
                'error': 'Unauthorized',
                'message': 'new row violates row-level security policy',
              }),
              403,
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
      await pumpEventQueue();

      expect(recorder.requests, hasLength(2));
      expect(recorder.requests.any((r) => r.method == 'DELETE'), isFalse);
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
      await pumpEventQueue();

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

    test("a 'stored' row-update failure whose follow-up 'failed' update "
        'succeeds never issues a storage remove', () async {
      var storedUpdateAttempted = false;
      final recorder = SupabaseRecorder(
        respond: (request) {
          if (request.url.path.startsWith('/storage/v1/object/')) {
            return {'Key': 'speaking-audio/u1/a1.wav'};
          }
          if (request.url.path == '/rest/v1/speaking_attempts' &&
              !storedUpdateAttempted) {
            // Only the first row-update attempt (marking 'stored')
            // fails; the follow-up 'failed' update succeeds.
            storedUpdateAttempted = true;
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
      await pumpEventQueue();

      expect(recorder.requests, hasLength(3));
      expect(recorder.requests.any((r) => r.method == 'DELETE'), isFalse);
      final firstBody =
          recorder.bodyOf(recorder.requests[1])! as Map<String, Object?>;
      expect(firstBody['audio_status'], 'stored');
      final secondBody =
          recorder.bodyOf(recorder.requests[2])! as Map<String, Object?>;
      expect(secondBody['audio_status'], 'failed');
    });

    // The fixture's audio_path deliberately uses a DIFFERENT extension than
    // the `<uid>/<attemptId>.wav` shape a naive convention-based path would
    // guess, proving the removed path comes from the row's own audio_path
    // column, not reconstructed from attemptId/currentUserId.
    test('delete resolves the path from the row, updates the row, then '
        'removes the object', () async {
      final recorder = SupabaseRecorder(
        respond: (request) {
          if (request.method == 'GET' &&
              request.url.path == '/rest/v1/speaking_attempts') {
            return [
              {'audio_status': 'stored', 'audio_path': 'u1/a1.webm'},
            ];
          }
          if (request.method == 'PATCH' &&
              request.url.path == '/rest/v1/speaking_attempts') {
            return [
              {'id': 'a1', 'audio_status': 'deleted'},
            ];
          }
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
      ).delete(attemptId: 'a1');

      expect(result.isOk, isTrue);
      expect(recorder.requests, hasLength(3));
      expect(recorder.requests[0].method, 'GET');
      expect(recorder.requests[1].method, 'PATCH');
      // The update is guarded on the row's source status, closing the
      // TOCTOU race with a concurrent status change since the select above.
      expect(
        recorder.requests[1].url.queryParameters['audio_status'],
        'eq.stored',
      );
      final updateBody =
          recorder.bodyOf(recorder.requests[1])! as Map<String, Object?>;
      expect(updateBody['audio_status'], 'deleted');
      final removeRequest = recorder.requests[2];
      expect(removeRequest.method, 'DELETE');
      expect(jsonDecode(removeRequest.body), {
        'prefixes': ['u1/a1.webm'],
      });
    });

    // A stronger variant of the same proof: a path that doesn't even follow
    // the `<uid>/<attemptId>.<ext>` shape at all (e.g. a legacy/migrated
    // object) is still removed exactly as stored on the row — the store
    // never reconstructs a path from attemptId/currentUserId for delete().
    test("delete removes the object at the row's audio_path even when it "
        'does not follow the <uid>/<attemptId>.<ext> convention', () async {
      final recorder = SupabaseRecorder(
        respond: (request) {
          if (request.method == 'GET') {
            return [
              {
                'audio_status': 'stored',
                'audio_path': 'legacy/2020-06-01-migrated-recording.ogg',
              },
            ];
          }
          if (request.method == 'PATCH') {
            return [
              {'id': 'a1', 'audio_status': 'deleted'},
            ];
          }
          return <Object?>[];
        },
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseAttemptAudioStore(
        recorder.client,
        currentUserId: () => 'u1',
      ).delete(attemptId: 'a1');

      expect(result.isOk, isTrue);
      final removeRequest = recorder.requests.last;
      expect(removeRequest.method, 'DELETE');
      expect(jsonDecode(removeRequest.body), {
        'prefixes': ['legacy/2020-06-01-migrated-recording.ogg'],
      });
    });

    test('delete on an already-deleted attempt is idempotent (no write, no '
        'storage call)', () async {
      final recorder = SupabaseRecorder(
        respond: (request) {
          if (request.method == 'GET') {
            return [
              {'audio_status': 'deleted', 'audio_path': null},
            ];
          }
          return null;
        },
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseAttemptAudioStore(
        recorder.client,
        currentUserId: () => 'u1',
      ).delete(attemptId: 'a1');
      await pumpEventQueue();

      expect(result.isOk, isTrue);
      expect(recorder.requests, hasLength(1));
    });

    test('delete on a non-stored attempt fails without any write', () async {
      final recorder = SupabaseRecorder(
        respond: (request) {
          if (request.method == 'GET') {
            return [
              {'audio_status': 'pending', 'audio_path': null},
            ];
          }
          return null;
        },
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseAttemptAudioStore(
        recorder.client,
        currentUserId: () => 'u1',
      ).delete(attemptId: 'a1');
      await pumpEventQueue();

      expect(result.isOk, isFalse);
      expect(recorder.requests, hasLength(1));
    });

    test("delete on a 'failed' attempt fails without any write or storage "
        'call', () async {
      final recorder = SupabaseRecorder(
        respond: (request) {
          if (request.method == 'GET') {
            return [
              {'audio_status': 'failed', 'audio_path': null},
            ];
          }
          return null;
        },
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseAttemptAudioStore(
        recorder.client,
        currentUserId: () => 'u1',
      ).delete(attemptId: 'a1');
      await pumpEventQueue();

      expect(result.isOk, isFalse);
      expect(recorder.requests, hasLength(1));
      expect(recorder.requests.single.method, 'GET');
    });

    test('delete on an attempt whose row is not found fails', () async {
      final recorder = SupabaseRecorder(
        respond: (request) => request.method == 'GET' ? <Object?>[] : null,
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseAttemptAudioStore(
        recorder.client,
        currentUserId: () => 'u1',
      ).delete(attemptId: 'a1');
      await pumpEventQueue();

      expect(result.isOk, isFalse);
      expect(recorder.requests, hasLength(1));
    });

    test('a failed row update never removes the object', () async {
      final recorder = SupabaseRecorder(
        respond: (request) {
          if (request.method == 'GET') {
            return [
              {'audio_status': 'stored', 'audio_path': 'u1/a1.wav'},
            ];
          }
          if (request.method == 'PATCH') {
            throw http.ClientException('offline');
          }
          return null;
        },
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseAttemptAudioStore(
        recorder.client,
        currentUserId: () => 'u1',
      ).delete(attemptId: 'a1');
      await pumpEventQueue();

      expect(result.isOk, isFalse);
      expect(recorder.requests, hasLength(2));
      expect(recorder.requests.any((r) => r.method == 'DELETE'), isFalse);
    });

    test('an update matching zero rows (raced status change) never removes '
        'the object', () async {
      final recorder = SupabaseRecorder(
        respond: (request) {
          if (request.method == 'GET') {
            return [
              {'audio_status': 'stored', 'audio_path': 'u1/a1.wav'},
            ];
          }
          if (request.method == 'PATCH') {
            return <Object?>[]; // no row matched a concurrent change
          }
          return null;
        },
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseAttemptAudioStore(
        recorder.client,
        currentUserId: () => 'u1',
      ).delete(attemptId: 'a1');
      await pumpEventQueue();

      expect(result.isOk, isFalse);
      expect(recorder.requests, hasLength(2));
      expect(recorder.requests.any((r) => r.method == 'DELETE'), isFalse);
    });

    test('a failed object removal after a successful row update is still ok '
        '(reconciled server-side by the retention sweep)', () async {
      final recorder = SupabaseRecorder(
        respond: (request) {
          if (request.method == 'GET') {
            return [
              {'audio_status': 'stored', 'audio_path': 'u1/a1.wav'},
            ];
          }
          if (request.method == 'PATCH') {
            return [
              {'id': 'a1', 'audio_status': 'deleted'},
            ];
          }
          if (request.url.path == '/storage/v1/object/speaking-audio') {
            throw http.ClientException('offline');
          }
          return null;
        },
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseAttemptAudioStore(
        recorder.client,
        currentUserId: () => 'u1',
      ).delete(attemptId: 'a1');

      expect(result.isOk, isTrue);
      expect(recorder.requests, hasLength(3));
    });

    test('maps a transport error to a network failure', () async {
      final recorder = SupabaseRecorder(
        respond: (_) => throw http.ClientException('offline'),
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseAttemptAudioStore(
        recorder.client,
        currentUserId: () => 'u1',
      ).delete(attemptId: 'a1');

      expect(result.failureOrNull, const NetworkFailure());
    });
  });
}
