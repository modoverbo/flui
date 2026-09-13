import 'package:freezed_annotation/freezed_annotation.dart';

part 'access_status.freezed.dart';

/// Mirrors `entitlements.status`.
enum EntitlementStatus { trialing, active, pastDue, canceled, expired }

/// Result of the `my_access()` RPC.
@freezed
abstract class AccessStatus with _$AccessStatus {
  const factory({
    required bool hasAccess,
    EntitlementStatus? entitlementStatus,
    DateTime? currentPeriodEnd,

    /// Only set while trialing: the first charge date.
    DateTime? trialEndsAt,
  }) = _AccessStatus;

  static const none = AccessStatus(hasAccess: false);
}
