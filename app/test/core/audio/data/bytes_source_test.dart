import 'dart:io';
import 'dart:typed_data';

import 'package:flui/core/audio/data/bytes_source.dart';
import 'package:flui/core/audio/data/bytes_source_io.dart';
import 'package:flutter_test/flutter_test.dart';

// [BlobUrlLifecycle] is pure create-once/revoke-once bookkeeping shared by
// `WebBlobAudioSource` (web) — kept free of `dart:js_interop`/`package:web`
// so it is testable here on the VM, unlike the browser calls it guards
// (design part-3 §3, U3 spike: web blob URLs must be revoked or they leak).
//
// [TempFileAudioSource] is the Android/iOS counterpart: a real `dart:io`
// temp file whose directory is injected, so these tests never depend on
// `path_provider`'s platform channel.
void main() {
  group('BlobUrlLifecycle', () {
    test('starts allowing create, not revoke', () {
      final lifecycle = BlobUrlLifecycle();

      expect(lifecycle.shouldCreate, isTrue);
      expect(lifecycle.shouldRevoke, isFalse);
    });

    test('after markCreated, revoke is allowed and create is not', () {
      final lifecycle = BlobUrlLifecycle()..markCreated();

      expect(lifecycle.shouldCreate, isFalse);
      expect(lifecycle.shouldRevoke, isTrue);
    });

    test('after markRevoked, revoke is no longer allowed (idempotent)', () {
      final lifecycle = BlobUrlLifecycle()
        ..markCreated()
        ..markRevoked();

      expect(lifecycle.shouldRevoke, isFalse);

      // A second markRevoked() must not throw or flip anything back.
      lifecycle.markRevoked();
      expect(lifecycle.shouldRevoke, isFalse);
    });
  });

  group('TempFileAudioSource', () {
    late Directory tempRoot;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('speech_player_test_');
    });

    tearDown(() async {
      if (tempRoot.existsSync()) await tempRoot.delete(recursive: true);
    });

    test(
      'prepare writes bytes to a new file under the injected directory',
      () async {
        final source = TempFileAudioSource(
          temporaryDirectory: () async => tempRoot,
        );
        final bytes = Uint8List.fromList([1, 2, 3, 4]);

        final uri = await source.prepare(bytes, 'audio/wav');
        final file = File.fromUri(uri);

        expect(file.existsSync(), isTrue);
        expect(await file.readAsBytes(), bytes);
        expect(file.parent.path, tempRoot.path);
        expect(file.path.endsWith('.wav'), isTrue);
      },
    );

    test('two prepared sources never collide on the same file name', () async {
      final sourceA = TempFileAudioSource(
        temporaryDirectory: () async => tempRoot,
      );
      final sourceB = TempFileAudioSource(
        temporaryDirectory: () async => tempRoot,
      );

      final uriA = await sourceA.prepare(Uint8List.fromList([1]), 'audio/wav');
      final uriB = await sourceB.prepare(Uint8List.fromList([2]), 'audio/wav');

      expect(uriA, isNot(uriB));
      expect(File.fromUri(uriA).existsSync(), isTrue);
      expect(File.fromUri(uriB).existsSync(), isTrue);
    });

    test('release deletes the prepared file', () async {
      final source = TempFileAudioSource(
        temporaryDirectory: () async => tempRoot,
      );
      final uri = await source.prepare(Uint8List.fromList([5, 6]), 'audio/wav');
      final file = File.fromUri(uri);
      expect(file.existsSync(), isTrue);

      await source.release();

      expect(file.existsSync(), isFalse);
    });

    test('release before prepare is a safe no-op', () async {
      final source = TempFileAudioSource(
        temporaryDirectory: () async => tempRoot,
      );

      await source.release();
      await source.release();
      // No exception thrown — the assertion is that we reach this line.
      expect(tempRoot.listSync(), isEmpty);
    });

    test('release is idempotent after a successful prepare+release', () async {
      final source = TempFileAudioSource(
        temporaryDirectory: () async => tempRoot,
      );
      await source.prepare(Uint8List.fromList([7]), 'audio/wav');

      await source.release();
      await source.release();

      expect(tempRoot.listSync(), isEmpty);
    });

    test(
      'a second prepare releases the first file before writing a new one',
      () async {
        final source = TempFileAudioSource(
          temporaryDirectory: () async => tempRoot,
        );
        final firstUri = await source.prepare(
          Uint8List.fromList([1]),
          'audio/wav',
        );
        final secondUri = await source.prepare(
          Uint8List.fromList([2]),
          'audio/wav',
        );

        expect(File.fromUri(firstUri).existsSync(), isFalse);
        expect(File.fromUri(secondUri).existsSync(), isTrue);
      },
    );
  });
}
