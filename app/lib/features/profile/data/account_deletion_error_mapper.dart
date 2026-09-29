import 'package:flui/core/error/failure.dart';

/// Maps `account-delete`'s machine-readable `error.code` to a typed
/// [AccountDeletionFailure] (U22e; codes per `apply-progress/u22b`).
/// Unknown or missing codes map to [AccountDeletionErrorCode.unknown].
AccountDeletionFailure mapAccountDeletionErrorCode(String? code) {
  final mapped = switch (code) {
    'billing_unavailable' ||
    'entitlement_unavailable' => AccountDeletionErrorCode.billingUnavailable,
    'whop_membership_not_found' ||
    'membership_id_missing' => AccountDeletionErrorCode.membershipNotFound,
    'storage_cleanup_failed' ||
    'account_deletion_failed' => AccountDeletionErrorCode.deletionFailed,
    _ => AccountDeletionErrorCode.unknown,
  };
  return AccountDeletionFailure(mapped);
}

/// Reads the machine-readable `error.code` out of a decoded `{error: {code,
/// message}}` response body, or null when the body does not match that shape.
String? readAccountDeletionErrorCode(Object? body) {
  final error = body is Map ? body['error'] : null;
  final code = error is Map ? error['code'] : null;
  return code is String ? code : null;
}
