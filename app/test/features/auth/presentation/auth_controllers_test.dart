import 'package:flui/core/error/failure.dart';
import 'package:flui/features/auth/data/fake_auth_repository.dart';
import 'package:flui/features/auth/domain/auth_status.dart';
import 'package:flui/features/auth/domain/credentials_validator.dart';
import 'package:flui/features/auth/presentation/controllers/auth_form_state.dart';
import 'package:flui/features/auth/presentation/controllers/password_reset_controller.dart';
import 'package:flui/features/auth/presentation/controllers/sign_in_controller.dart';
import 'package:flui/features/auth/presentation/controllers/sign_out_controller.dart';
import 'package:flui/features/auth/presentation/controllers/sign_up_controller.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_container.dart';

void main() {
  late FakeAuthRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeAuthRepository();
    container = createTestContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
  });

  tearDown(() => repository.dispose());

  /// Keeps an auto-dispose controller alive while a test awaits it.
  void keepAlive(ProviderListenable<Object?> provider) =>
      container.listen(provider, (_, _) {});

  group('authStatusProvider', () {
    test('is signed out without a session and follows sign in', () async {
      keepAlive(authStatusProvider);
      await container.read(authUserProvider.future);
      expect(container.read(authStatusProvider), AuthStatus.signedOut);

      await repository.signIn(email: 'ana@correo.com', password: 'secreta1');
      await pumpEventQueue();

      expect(container.read(authStatusProvider), AuthStatus.signedIn);
      expect(container.read(authUserProvider).value?.email, 'ana@correo.com');
    });

    test('is unknown while the session is being restored', () {
      expect(container.read(authStatusProvider), AuthStatus.unknown);
    });
  });

  group('SignInController', () {
    test('validates fields before calling the repository', () async {
      keepAlive(signInControllerProvider);

      await container
          .read(signInControllerProvider.notifier)
          .submit(email: 'ana', password: '');

      final state = container.read(signInControllerProvider);
      expect(state.emailError, EmailError.invalid);
      expect(state.passwordError, PasswordError.empty);
      expect(state.isSubmitting, isFalse);
      expect(repository.currentUser, isNull);
    });

    test('signs in with trimmed email', () async {
      keepAlive(signInControllerProvider);

      await container
          .read(signInControllerProvider.notifier)
          .submit(email: ' ana@correo.com ', password: 'secreta1');

      final state = container.read(signInControllerProvider);
      expect(state, const AuthFormState(isDone: true));
      expect(repository.currentUser?.email, 'ana@correo.com');
    });

    test('exposes submitting while the request runs', () async {
      keepAlive(signInControllerProvider);
      final states = <AuthFormState>[];
      container.listen(signInControllerProvider, (_, next) => states.add(next));

      await container
          .read(signInControllerProvider.notifier)
          .submit(email: 'ana@correo.com', password: 'secreta1');

      expect(states.first.isSubmitting, isTrue);
      expect(states.last.isSubmitting, isFalse);
    });

    test('keeps the failure when the repository fails', () async {
      keepAlive(signInControllerProvider);
      repository.nextFailure = const AuthFailure(
        AuthErrorCode.invalidCredentials,
      );

      await container
          .read(signInControllerProvider.notifier)
          .submit(email: 'ana@correo.com', password: 'secreta1');

      final state = container.read(signInControllerProvider);
      expect(
        state.failure,
        const AuthFailure(AuthErrorCode.invalidCredentials),
      );
      expect(state.isDone, isFalse);
    });

    test('a new submit clears the previous failure', () async {
      keepAlive(signInControllerProvider);
      repository.nextFailure = const NetworkFailure();
      final controller = container.read(signInControllerProvider.notifier);

      await controller.submit(email: 'ana@correo.com', password: 'secreta1');
      await controller.submit(email: 'ana@correo.com', password: 'secreta1');

      expect(container.read(signInControllerProvider).failure, isNull);
    });
  });

  group('SignUpController', () {
    test('validates name, email and a new password', () async {
      keepAlive(signUpControllerProvider);

      await container
          .read(signUpControllerProvider.notifier)
          .submit(name: ' ', email: '', password: '1234');

      final state = container.read(signUpControllerProvider);
      expect(state.nameError, NameError.empty);
      expect(state.emailError, EmailError.empty);
      expect(state.passwordError, PasswordError.tooShort);
      expect(repository.currentUser, isNull);
    });

    test('creates the account and signs in', () async {
      keepAlive(signUpControllerProvider);

      await container
          .read(signUpControllerProvider.notifier)
          .submit(name: 'Ana', email: 'ana@correo.com', password: 'secreta1');

      expect(container.read(signUpControllerProvider).isDone, isTrue);
      expect(repository.currentUser?.displayName, 'Ana');
    });

    test('reports when email confirmation is required', () async {
      repository = FakeAuthRepository(requireEmailConfirmation: true);
      container = createTestContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      keepAlive(signUpControllerProvider);

      await container
          .read(signUpControllerProvider.notifier)
          .submit(name: 'Ana', email: 'ana@correo.com', password: 'secreta1');

      final state = container.read(signUpControllerProvider);
      expect(state.confirmationEmail, 'ana@correo.com');
      expect(state.isDone, isTrue);
    });

    test('keeps email-in-use failures', () async {
      keepAlive(signUpControllerProvider);
      repository.nextFailure = const AuthFailure(
        AuthErrorCode.emailAlreadyInUse,
      );

      await container
          .read(signUpControllerProvider.notifier)
          .submit(name: 'Ana', email: 'ana@correo.com', password: 'secreta1');

      expect(
        container.read(signUpControllerProvider).failure,
        const AuthFailure(AuthErrorCode.emailAlreadyInUse),
      );
    });
  });

  group('PasswordResetController', () {
    test('validates the email', () async {
      keepAlive(passwordResetControllerProvider);

      await container
          .read(passwordResetControllerProvider.notifier)
          .submit(email: 'ana@');

      expect(
        container.read(passwordResetControllerProvider).emailError,
        EmailError.invalid,
      );
      expect(repository.passwordResetEmails, isEmpty);
    });

    test('sends the reset link', () async {
      keepAlive(passwordResetControllerProvider);

      await container
          .read(passwordResetControllerProvider.notifier)
          .submit(email: 'ana@correo.com');

      expect(container.read(passwordResetControllerProvider).isDone, isTrue);
      expect(repository.passwordResetEmails, ['ana@correo.com']);
    });
  });

  group('SignOutController', () {
    test('signs out', () async {
      await repository.signIn(email: 'ana@correo.com', password: 'secreta1');
      keepAlive(signOutControllerProvider);

      await container.read(signOutControllerProvider.notifier).signOut();

      expect(repository.currentUser, isNull);
      expect(container.read(signOutControllerProvider), isFalse);
    });
  });
}
