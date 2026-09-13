import 'package:flui/core/error/result.dart';
import 'package:flui/features/auth/domain/credentials_validator.dart';
import 'package:flui/features/auth/presentation/controllers/auth_form_state.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sign_in_controller.g.dart';

@riverpod
class SignInController extends _$SignInController {
  @override
  AuthFormState build() => const AuthFormState();

  Future<void> submit({required String email, required String password}) async {
    if (state.isSubmitting) return;
    final validation = AuthFormState(
      emailError: CredentialsValidator.email(email),
      passwordError: CredentialsValidator.existingPassword(password),
    );
    if (validation.hasFieldErrors) {
      state = validation;
      return;
    }

    state = const AuthFormState(isSubmitting: true);
    final result = await ref
        .read(authRepositoryProvider)
        .signIn(email: email.trim(), password: password);
    if (!ref.mounted) return;

    state = switch (result) {
      Ok() => const AuthFormState(isDone: true),
      Err(:final failure) => AuthFormState(failure: failure),
    };
  }
}
