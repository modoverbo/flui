import 'package:flui/features/subscription/domain/access_status.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'access_status_dto.freezed.dart';
part 'access_status_dto.g.dart';

/// JSON returned by `public.my_access()`.
@freezed
abstract class AccessStatusDto with _$AccessStatusDto {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory({
    required bool hasAccess,
    String? entitlementStatus,
    DateTime? currentPeriodEnd,
    DateTime? trialEndsAt,
  }) = _AccessStatusDto;

  factory fromJson(Map<String, dynamic> json) =>
      _$AccessStatusDtoFromJson(json);

  const new _();

  AccessStatus toDomain() => AccessStatus(
    hasAccess: hasAccess,
    entitlementStatus: switch (entitlementStatus) {
      'trialing' => EntitlementStatus.trialing,
      'active' => EntitlementStatus.active,
      'past_due' => EntitlementStatus.pastDue,
      'canceled' => EntitlementStatus.canceled,
      'expired' => EntitlementStatus.expired,
      _ => null,
    },
    currentPeriodEnd: currentPeriodEnd,
    trialEndsAt: trialEndsAt,
  );
}
