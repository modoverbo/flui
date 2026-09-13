import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';

/// The signed-in person. `displayName` comes from the signup metadata
/// (`display_name`), which the `on_auth_user_created` trigger copies into
/// `profiles`.
@freezed
abstract class AppUser with _$AppUser {
  const factory({
    required String id,
    required String email,
    String? displayName,
  }) = _AppUser;
}
