import 'package:flui/core/error/result.dart';
import 'package:flui/features/auth/domain/credentials_validator.dart';
import 'package:flui/features/auth/domain/sign_up_outcome.dart';
import 'package:flui/features/auth/presentation/controllers/auth_form_state.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sign_up_controller.g.dart';

@riverpod
class SignUpController extends _$SignUpController {
  @override
  AuthFormState build() => const AuthFormState();

  Future<void> submit({
    required String name,
    required String email,
    required String password,
  }) async {
    if (state.isSubmitting) return;
    final validation = AuthFormState(
      nameError: CredentialsValidator.displayName(name),
      emailError: CredentialsValidator.email(email),
      passwordError: CredentialsValidator.newPassword(password),
    );
    if (validation.hasFieldErrors) {
      state = validation;
      return;
    }

    state = const AuthFormState(isSubmitting: true);
    final result = await ref
        .read(authRepositoryProvider)
        .signUp(
          displayName: name.trim(),
          email: email.trim(),
          password: password,
        );
    if (!ref.mounted) return;

    state = switch (result) {
      Ok(value: SignedUp()) => const AuthFormState(isDone: true),
      Ok(value: ConfirmationRequired(:final email)) => AuthFormState(
        isDone: true,
        confirmationEmail: email,
      ),
      Err(:final failure) => AuthFormState(failure: failure),
    };
  }
}
