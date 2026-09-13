import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Result', () {
    test('Ok exposes its value and no failure', () {
      const result = Result<int>.ok(42);

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, 42);
      expect(result.failureOrNull, isNull);
    });

    test('Err exposes its failure and no value', () {
      const failure = NetworkFailure();
      const result = Result<int>.err(failure);

      expect(result.isOk, isFalse);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, failure);
    });

    test('map transforms Ok values and keeps Err failures', () {
      const ok = Result<int>.ok(2);
      const err = Result<int>.err(UnexpectedFailure());

      expect(ok.map((value) => value * 10).valueOrNull, 20);
      expect(
        err.map((value) => value * 10).failureOrNull,
        isA<UnexpectedFailure>(),
      );
    });

    test('supports exhaustive pattern matching', () {
      String describe(Result<String> result) => switch (result) {
        Ok(:final value) => 'ok:$value',
        Err(:final failure) => 'err:${failure.runtimeType}',
      };

      expect(describe(const Result.ok('a')), 'ok:a');
      expect(
        describe(const Result.err(NetworkFailure())),
        'err:NetworkFailure',
      );
    });

    test('values with equal content are equal', () {
      expect(const Result<int>.ok(1), const Result<int>.ok(1));
      expect(
        const Result<int>.err(NetworkFailure()),
        const Result<int>.err(NetworkFailure()),
      );
      expect(const Result<int>.ok(1), isNot(const Result<int>.ok(2)));
    });
  });

  group('Failure', () {
    test('auth and subscription failures carry a typed code', () {
      const auth = AuthFailure(AuthErrorCode.invalidCredentials);
      const subscription = SubscriptionFailure(
        SubscriptionErrorCode.alreadySubscribed,
      );

      expect(auth.code, AuthErrorCode.invalidCredentials);
      expect(subscription.code, SubscriptionErrorCode.alreadySubscribed);
      expect(auth, const AuthFailure(AuthErrorCode.invalidCredentials));
    });

    test('config failure keeps a developer message', () {
      const failure = ConfigFailure('SUPABASE_URL is missing');

      expect(failure.message, 'SUPABASE_URL is missing');
      expect(failure.toString(), contains('SUPABASE_URL is missing'));
    });

    test('unexpected failure keeps the cause for logging', () {
      final cause = StateError('boom');
      final failure = UnexpectedFailure(cause);

      expect(failure.cause, cause);
    });
  });
}
