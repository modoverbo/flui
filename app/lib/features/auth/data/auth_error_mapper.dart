import 'dart:async';

import 'package:flui/core/error/failure.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps errors thrown by Supabase Auth to typed failures.
///
/// Codes: https://supabase.com/docs/guides/auth/debugging/error-codes
Failure mapAuthError(Object error) {
  if (error is AuthRetryableFetchException ||
      error is http.ClientException ||
      error is TimeoutException) {
    return const NetworkFailure();
  }
  if (error is! AuthException) return UnexpectedFailure(error);

  final code = switch (error.code) {
    'invalid_credentials' => AuthErrorCode.invalidCredentials,
    'user_already_exists' || 'email_exists' => AuthErrorCode.emailAlreadyInUse,
    'weak_password' => AuthErrorCode.weakPassword,
    'email_not_confirmed' => AuthErrorCode.emailNotConfirmed,
    'over_request_rate_limit' ||
    'over_email_send_rate_limit' => AuthErrorCode.rateLimited,
    'signup_disabled' ||
    'email_provider_disabled' => AuthErrorCode.signUpDisabled,
    _ when error.statusCode == '429' => AuthErrorCode.rateLimited,
    _ => AuthErrorCode.unknown,
  };
  return AuthFailure(code);
}
