import 'package:flui/core/error/failure.dart';
import 'package:flui/core/supabase/data_error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

export 'package:flui/core/supabase/data_error_mapper.dart' show mapDataError;

/// Maps `whop-checkout` Edge Function errors (`{error: {code, message}}`).
Failure mapCheckoutError(Object error) {
  if (error is FunctionsFetchException) return const NetworkFailure();
  if (error is! FunctionException) return mapDataError(error);

  final code = switch (error.details) {
    {'error': {'code': final String code}} => code,
    _ => null,
  };
  final kind = switch ((error.status, code)) {
    (_, 'already_subscribed') ||
    (409, _) => SubscriptionErrorCode.alreadySubscribed,
    (_, 'unknown_plan') || (404, _) => SubscriptionErrorCode.unknownPlan,
    (_, 'unauthorized') || (401, _) => SubscriptionErrorCode.unauthorized,
    (final status, _) when status >= 500 =>
      SubscriptionErrorCode.checkoutUnavailable,
    _ => SubscriptionErrorCode.unknown,
  };
  return SubscriptionFailure(kind);
}
