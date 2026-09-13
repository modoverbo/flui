import 'package:flui/features/auth/domain/credentials_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('email', () {
    test('empty or blank is empty', () {
      expect(CredentialsValidator.email(''), EmailError.empty);
      expect(CredentialsValidator.email('   '), EmailError.empty);
    });

    test('incomplete addresses are invalid', () {
      for (final value in [
        'ana',
        'ana@',
        '@correo.com',
        'ana@correo',
        'a b@c.co',
      ]) {
        expect(
          CredentialsValidator.email(value),
          EmailError.invalid,
          reason: value,
        );
      }
    });

    test('valid addresses pass, surrounding spaces are ignored', () {
      expect(CredentialsValidator.email('ana@correo.com'), isNull);
      expect(
        CredentialsValidator.email('  ana.lopez+flui@correo.com.mx '),
        isNull,
      );
    });
  });

  group('password for sign-up', () {
    test('empty is empty', () {
      expect(CredentialsValidator.newPassword(''), PasswordError.empty);
    });

    test('fewer than 8 characters is too short', () {
      expect(
        CredentialsValidator.newPassword('1234567'),
        PasswordError.tooShort,
      );
    });

    test('8 characters or more passes (spaces count)', () {
      expect(CredentialsValidator.newPassword('12345678'), isNull);
      expect(CredentialsValidator.newPassword('una frase'), isNull);
    });
  });

  group('password for sign-in', () {
    test('only requires a value', () {
      expect(CredentialsValidator.existingPassword(''), PasswordError.empty);
      expect(CredentialsValidator.existingPassword('123'), isNull);
    });
  });

  group('display name', () {
    test('empty or blank is empty', () {
      expect(CredentialsValidator.displayName(' '), NameError.empty);
    });

    test('more than 80 characters after trimming is too long', () {
      expect(CredentialsValidator.displayName('a' * 81), NameError.tooLong);
      expect(CredentialsValidator.displayName(' ${'a' * 80} '), isNull);
    });
  });
}
