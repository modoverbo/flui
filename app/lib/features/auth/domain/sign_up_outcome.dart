import 'package:flui/features/auth/domain/app_user.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sign_up_outcome.freezed.dart';

@freezed
sealed class SignUpOutcome with _$SignUpOutcome {
  /// The account exists and the user is signed in.
  const factory signedUp(AppUser user) = SignedUp;

  /// The project requires email confirmation before the first sign-in.
  const factory confirmationRequired(String email) = ConfirmationRequired;
}
