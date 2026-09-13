import 'package:flui/core/error/failure.dart';
import 'package:flui/features/auth/domain/credentials_validator.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_form_state.freezed.dart';

/// State shared by the sign-in, sign-up and password reset forms.
@freezed
abstract class AuthFormState with _$AuthFormState {
  const factory({
    @Default(false) bool isSubmitting,
    NameError? nameError,
    EmailError? emailError,
    PasswordError? passwordError,
    Failure? failure,

    /// The request succeeded.
    @Default(false) bool isDone,

    /// Set when sign-up needs the user to confirm this email first.
    String? confirmationEmail,
  }) = _AuthFormState;

  const new _();

  bool get hasFieldErrors =>
      nameError != null || emailError != null || passwordError != null;
}
