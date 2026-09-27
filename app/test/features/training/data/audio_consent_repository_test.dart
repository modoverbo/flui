import 'package:flui/core/error/failure.dart';
import 'package:flui/features/training/data/fake_audio_consent_repository.dart';
import 'package:flui/features/training/data/supabase_audio_consent_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../../helpers/supabase_recorder.dart';

void main() {
  group('FakeAudioConsentRepository', () {
    test('reads null when consent was never asked', () async {
      final repository = FakeAudioConsentRepository(currentUserId: () => 'u1');

      final result = await repository.read();

      expect(result.valueOrNull, isNull);
    });

    test('write then read round-trips the granted value', () async {
      final repository = FakeAudioConsentRepository(currentUserId: () => 'u1');

      await repository.write(granted: true);
      final result = await repository.read();

      expect(result.valueOrNull, isTrue);
    });

    test('a revocation overwrites a prior grant', () async {
      final repository = FakeAudioConsentRepository(currentUserId: () => 'u1');
      await repository.write(granted: true);

      await repository.write(granted: false);
      final result = await repository.read();

      expect(result.valueOrNull, isFalse);
    });

    test('fails without a signed-in user', () async {
      final repository = FakeAudioConsentRepository(currentUserId: () => null);

      expect((await repository.read()).isOk, isFalse);
      expect((await repository.write(granted: true)).isOk, isFalse);
    });
  });

  group('SupabaseAudioConsentRepository', () {
    test('reads the current consent value', () async {
      final recorder = SupabaseRecorder(
        respond: (_) => {'audio_retention_consent': true},
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseAudioConsentRepository(
        recorder.client,
        currentUserId: () => 'u1',
      ).read();

      expect(result.valueOrNull, isTrue);
      expect(recorder.last.url.path, '/rest/v1/profiles');
      expect(recorder.last.url.queryParameters['id'], 'eq.u1');
    });

    test('writes the granted value to the own profile row', () async {
      final recorder = SupabaseRecorder(respond: (_) => null);
      addTearDown(recorder.dispose);

      final result = await SupabaseAudioConsentRepository(
        recorder.client,
        currentUserId: () => 'u1',
      ).write(granted: false);

      expect(result.isOk, isTrue);
      final body = recorder.bodyOf(recorder.last)! as Map<String, Object?>;
      expect(body['audio_retention_consent'], isFalse);
      expect(recorder.last.url.queryParameters['id'], 'eq.u1');
    });

    test('maps transport errors to a network failure', () async {
      final recorder = SupabaseRecorder(
        respond: (_) => throw http.ClientException('offline'),
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseAudioConsentRepository(
        recorder.client,
        currentUserId: () => 'u1',
      ).read();

      expect(result.failureOrNull, const NetworkFailure());
    });
  });
}
