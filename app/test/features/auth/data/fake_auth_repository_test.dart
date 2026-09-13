import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/features/auth/data/fake_auth_repository.dart';
import 'package:flui/features/auth/domain/app_user.dart';
import 'package:flui/features/auth/domain/sign_up_outcome.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeAuthRepository repository;

  setUp(() => repository = FakeAuthRepository());
  tearDown(() => repository.dispose());

  test('starts signed out and emits the current user first', () async {
    expect(repository.currentUser, isNull);
    await expectLater(repository.authStateChanges(), emits(isNull));
  });

  test('sign up signs the user in with the display name', () async {
    final result = await repository.signUp(
      displayName: ' Ana ',
      email: 'Ana@Correo.com',
      password: 'secreta123',
    );

    final outcome = result.valueOrNull! as SignedUp;
    expect(outcome.user.displayName, 'Ana');
    expect(outcome.user.email, 'ana@correo.com');
    expect(repository.currentUser, outcome.user);
  });

  test('sign up can require email confirmation', () async {
    repository = FakeAuthRepository(requireEmailConfirmation: true);

    final result = await repository.signUp(
      displayName: 'Ana',
      email: 'ana@correo.com',
      password: 'secreta123',
    );

    expect(result.valueOrNull, const ConfirmationRequired('ana@correo.com'));
    expect(repository.currentUser, isNull);
  });

  test('sign up with a registered email fails', () async {
    await repository.signUp(
      displayName: 'Ana',
      email: 'ana@correo.com',
      password: 'secreta123',
    );
    await repository.signOut();

    final result = await repository.signUp(
      displayName: 'Otra',
      email: 'ana@correo.com',
      password: 'otraclave1',
    );

    expect(
      result.failureOrNull,
      const AuthFailure(AuthErrorCode.emailAlreadyInUse),
    );
  });

  test('sign in accepts any valid email and password', () async {
    final result = await repository.signIn(
      email: 'nuevo@correo.com',
      password: 'loquesea1',
    );

    expect(result.valueOrNull?.email, 'nuevo@correo.com');
    expect(repository.currentUser?.email, 'nuevo@correo.com');
  });

  test('sign in with a wrong password for a registered email fails', () async {
    await repository.signUp(
      displayName: 'Ana',
      email: 'ana@correo.com',
      password: 'secreta123',
    );
    await repository.signOut();

    final result = await repository.signIn(
      email: 'ana@correo.com',
      password: 'otra-clave',
    );

    expect(
      result.failureOrNull,
      const AuthFailure(AuthErrorCode.invalidCredentials),
    );
    expect(repository.currentUser, isNull);
  });

  test('sign in keeps the registered display name', () async {
    await repository.signUp(
      displayName: 'Ana',
      email: 'ana@correo.com',
      password: 'secreta123',
    );
    await repository.signOut();

    final result = await repository.signIn(
      email: 'ana@correo.com',
      password: 'secreta123',
    );

    expect(result.valueOrNull?.displayName, 'Ana');
  });

  test('auth state stream follows sign in and sign out', () async {
    final states = <AppUser?>[];
    final subscription = repository.authStateChanges().listen(states.add);

    await repository.signIn(email: 'ana@correo.com', password: 'secreta123');
    await repository.signOut();
    await pumpEventQueue();

    expect(states.map((user) => user?.email), [null, 'ana@correo.com', null]);
    await subscription.cancel();
  });

  test('password reset records the email', () async {
    final result = await repository.sendPasswordReset(email: 'ana@correo.com');

    expect(result, isA<Ok<void>>());
    expect(repository.passwordResetEmails, ['ana@correo.com']);
  });

  test('a scheduled failure is returned once', () async {
    repository.nextFailure = const NetworkFailure();

    final first = await repository.signIn(
      email: 'ana@correo.com',
      password: 'secreta123',
    );
    final second = await repository.signIn(
      email: 'ana@correo.com',
      password: 'secreta123',
    );

    expect(first.failureOrNull, const NetworkFailure());
    expect(second.isOk, isTrue);
  });
}
