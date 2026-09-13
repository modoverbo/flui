import 'dart:async';

import 'package:flui/core/error/failure.dart';
import 'package:flui/features/auth/data/auth_error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  Failure map(Object error) => mapAuthError(error);

  test('maps Supabase auth error codes', () {
    expect(
      map(
        const AuthApiException(
          'x',
          statusCode: '400',
          code: 'invalid_credentials',
        ),
      ),
      const AuthFailure(AuthErrorCode.invalidCredentials),
    );
    expect(
      map(
        const AuthApiException(
          'x',
          statusCode: '422',
          code: 'user_already_exists',
        ),
      ),
      const AuthFailure(AuthErrorCode.emailAlreadyInUse),
    );
    expect(
      map(const AuthApiException('x', statusCode: '422', code: 'email_exists')),
      const AuthFailure(AuthErrorCode.emailAlreadyInUse),
    );
    expect(
      map(
        const AuthApiException(
          'x',
          statusCode: '400',
          code: 'email_not_confirmed',
        ),
      ),
      const AuthFailure(AuthErrorCode.emailNotConfirmed),
    );
    expect(
      map(
        const AuthApiException(
          'x',
          statusCode: '429',
          code: 'over_email_send_rate_limit',
        ),
      ),
      const AuthFailure(AuthErrorCode.rateLimited),
    );
    expect(
      map(
        const AuthApiException('x', statusCode: '422', code: 'signup_disabled'),
      ),
      const AuthFailure(AuthErrorCode.signUpDisabled),
    );
  });

  test('weak password exceptions map to weakPassword', () {
    expect(
      map(
        AuthWeakPasswordException(
          message: 'weak',
          statusCode: '422',
          reasons: const ['length'],
        ),
      ),
      const AuthFailure(AuthErrorCode.weakPassword),
    );
  });

  test('HTTP 429 without a code is rate limited', () {
    expect(
      map(const AuthApiException('Too many', statusCode: '429')),
      const AuthFailure(AuthErrorCode.rateLimited),
    );
  });

  test('unknown auth errors keep the auth kind', () {
    expect(
      map(
        const AuthApiException(
          'x',
          statusCode: '500',
          code: 'unexpected_failure',
        ),
      ),
      const AuthFailure(AuthErrorCode.unknown),
    );
  });

  test('transport errors are network failures', () {
    expect(map(AuthRetryableFetchException()), const NetworkFailure());
    expect(map(http.ClientException('offline')), const NetworkFailure());
    expect(map(TimeoutException('slow')), const NetworkFailure());
  });

  test('anything else is unexpected', () {
    final error = StateError('bug');
    expect(map(error), UnexpectedFailure(error));
  });
}
