import 'package:flui/core/error/result.dart';
import 'package:flui/features/auth/domain/credentials_validator.dart';
import 'package:flui/features/auth/presentation/controllers/auth_form_state.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'password_reset_controller.g.dart';

@riverpod
class PasswordResetController extends _$PasswordResetController {
  @override
  AuthFormState build() => const AuthFormState();

  Future<void> submit({required String email}) async {
    if (state.isSubmitting) return;
    final emailError = CredentialsValidator.email(email);
    if (emailError != null) {
      state = AuthFormState(emailError: emailError);
      return;
    }

    state = const AuthFormState(isSubmitting: true);
    final result = await ref
        .read(authRepositoryProvider)
        .sendPasswordReset(email: email.trim());
    if (!ref.mounted) return;

    state = switch (result) {
      Ok() => const AuthFormState(isDone: true),
      Err(:final failure) => AuthFormState(failure: failure),
    };
  }
}
