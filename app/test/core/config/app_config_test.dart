import 'package:flui/core/config/app_config.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig.parse', () {
    test('BACKEND=fake needs no Supabase keys', () {
      final result = AppConfig.parse(const {'BACKEND': 'fake'});

      final config = result.valueOrNull!;
      expect(config.backend, Backend.fake);
      expect(config.supabaseUrl, isNull);
      expect(config.supabaseAnonKey, isNull);
      expect(config.devBypassAuth, isFalse);
    });

    test('fake backend accepts an explicit local developer bypass', () {
      final result = AppConfig.parse(const {
        'BACKEND': 'fake',
        'DEV_BYPASS_AUTH': 'true',
      });

      expect(result.valueOrNull?.devBypassAuth, isTrue);
    });

    test('developer bypass cannot be enabled with Supabase', () {
      final result = AppConfig.parse(const {
        'BACKEND': 'supabase',
        'SUPABASE_URL': 'https://abc.supabase.co',
        'SUPABASE_ANON_KEY': 'anon-key',
        'DEV_BYPASS_AUTH': 'true',
      });

      expect(result, isA<Err<AppConfig>>());
      expect(
        (result.failureOrNull! as ConfigFailure).message,
        contains('DEV_BYPASS_AUTH'),
      );
    });

    test('developer bypass only accepts true or false', () {
      final result = AppConfig.parse(const {
        'BACKEND': 'fake',
        'DEV_BYPASS_AUTH': 'yes',
      });

      expect(result, isA<Err<AppConfig>>());
      expect(
        (result.failureOrNull! as ConfigFailure).message,
        contains('DEV_BYPASS_AUTH'),
      );
    });

    test('BACKEND=supabase reads url, anon key and app url', () {
      final result = AppConfig.parse(const {
        'BACKEND': 'supabase',
        'SUPABASE_URL': 'http://127.0.0.1:54421',
        'SUPABASE_ANON_KEY': 'anon-key',
        'APP_URL': 'http://localhost:3000',
      });

      final config = result.valueOrNull!;
      expect(config.backend, Backend.supabase);
      expect(config.supabaseUrl, Uri.parse('http://127.0.0.1:54421'));
      expect(config.supabaseAnonKey, 'anon-key');
      expect(config.appUrl, Uri.parse('http://localhost:3000'));
    });

    // The production build only defines the Supabase keys.
    test('missing BACKEND defaults to supabase', () {
      final result = AppConfig.parse(const {
        'SUPABASE_URL': 'https://abc.supabase.co',
        'SUPABASE_ANON_KEY': 'anon-key',
      });

      expect(result.valueOrNull?.backend, Backend.supabase);
      expect(result.valueOrNull?.appUrl, isNull);
    });

    test('values are trimmed and BACKEND is case-insensitive', () {
      final result = AppConfig.parse(const {'BACKEND': ' FAKE '});

      expect(result.valueOrNull?.backend, Backend.fake);
    });

    test('unknown BACKEND is a config failure', () {
      final result = AppConfig.parse(const {'BACKEND': 'firebase'});

      expect(result, isA<Err<AppConfig>>());
      expect(
        (result.failureOrNull! as ConfigFailure).message,
        contains('BACKEND'),
      );
    });

    test('supabase without SUPABASE_URL is a config failure', () {
      final result = AppConfig.parse(const {'SUPABASE_ANON_KEY': 'anon-key'});

      expect(
        (result.failureOrNull! as ConfigFailure).message,
        contains('SUPABASE_URL'),
      );
    });

    test('supabase without SUPABASE_ANON_KEY is a config failure', () {
      final result = AppConfig.parse(const {
        'SUPABASE_URL': 'https://abc.supabase.co',
      });

      expect(
        (result.failureOrNull! as ConfigFailure).message,
        contains('SUPABASE_ANON_KEY'),
      );
    });

    test('SUPABASE_URL must be an absolute http(s) url', () {
      final result = AppConfig.parse(const {
        'SUPABASE_URL': 'abc.supabase.co',
        'SUPABASE_ANON_KEY': 'anon-key',
      });

      expect(
        (result.failureOrNull! as ConfigFailure).message,
        contains('SUPABASE_URL'),
      );
    });

    test('an invalid APP_URL is a config failure', () {
      final result = AppConfig.parse(const {
        'BACKEND': 'fake',
        'APP_URL': 'not a url',
      });

      expect(
        (result.failureOrNull! as ConfigFailure).message,
        contains('APP_URL'),
      );
    });

    test('empty values are treated as missing', () {
      final result = AppConfig.parse(const {
        'BACKEND': '',
        'SUPABASE_URL': '',
        'SUPABASE_ANON_KEY': '',
        'APP_URL': '',
      });

      expect(
        (result.failureOrNull! as ConfigFailure).message,
        contains('SUPABASE_URL'),
      );
    });
  });
}
