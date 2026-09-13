import 'package:flui/core/error/failure.dart';
import 'package:flui/core/l10n/failure_messages.dart';
import 'package:flui/core/l10n/formatters.dart';
import 'package:flui/core/l10n/gen/app_localizations_es.dart';
import 'package:flui/features/auth/domain/credentials_validator.dart';
import 'package:flui/features/auth/presentation/auth_copy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  final l10n = AppLocalizationsEs();

  setUpAll(() => initializeDateFormatting('es'));

  group('failureMessage', () {
    test('uses kind copy for every failure', () {
      expect(failureMessage(l10n, const NetworkFailure()), l10n.errorNetwork);
      expect(
        failureMessage(l10n, const UnexpectedFailure()),
        l10n.errorUnexpected,
      );
      expect(
        failureMessage(
          l10n,
          const AuthFailure(AuthErrorCode.invalidCredentials),
        ),
        l10n.authErrorInvalidCredentials,
      );
      expect(
        failureMessage(
          l10n,
          const AuthFailure(AuthErrorCode.emailAlreadyInUse),
        ),
        l10n.authErrorEmailInUse,
      );
      expect(
        failureMessage(
          l10n,
          const SubscriptionFailure(SubscriptionErrorCode.checkoutUnavailable),
        ),
        l10n.paywallCheckoutUnavailable,
      );
      expect(
        failureMessage(
          l10n,
          const SubscriptionFailure(SubscriptionErrorCode.couldNotOpenCheckout),
        ),
        l10n.paywallCheckoutError,
      );
    });

    test('never shows developer config messages to users', () {
      expect(
        failureMessage(l10n, const ConfigFailure('SUPABASE_URL missing')),
        l10n.errorUnexpected,
      );
    });

    test('avoids school and exam vocabulary', () {
      const banned = [
        'lección',
        'examen',
        'alumno',
        'profesor',
        'tarea',
        'calificación',
        'gramática',
        'memorización',
        'evaluación',
        'incorrect',
      ];
      final failures = <Failure>[
        const NetworkFailure(),
        const UnexpectedFailure(),
        for (final code in AuthErrorCode.values) AuthFailure(code),
        for (final code in SubscriptionErrorCode.values)
          SubscriptionFailure(code),
      ];
      for (final failure in failures) {
        final message = failureMessage(l10n, failure).toLowerCase();
        for (final word in banned) {
          expect(message, isNot(contains(word)), reason: '$failure');
        }
      }
    });
  });

  group('auth field copy', () {
    test('maps validation errors to brand voice messages', () {
      expect(emailErrorText(l10n, EmailError.empty), l10n.validationEmailEmpty);
      expect(
        emailErrorText(l10n, EmailError.invalid),
        l10n.validationEmailInvalid,
      );
      expect(
        passwordErrorText(l10n, PasswordError.tooShort),
        'Usa al menos 8 caracteres.',
      );
      expect(nameErrorText(l10n, NameError.empty), l10n.validationNameEmpty);
      expect(emailErrorText(l10n, null), isNull);
    });
  });

  group('formatters', () {
    test('prices show the currency without ambiguity', () {
      expect(formatPrice(999, 'USD'), r'US$ 9.99');
      expect(formatPrice(2499, 'USD'), r'US$ 24.99');
      expect(formatPrice(1000, 'EUR'), 'EUR 10.00');
    });

    test('long dates are written in Spanish', () {
      expect(formatLongDate(DateTime(2026, 9, 20)), '20 de septiembre');
    });

    test('long dates use the local calendar day of UTC timestamps', () {
      final utc = DateTime.utc(2026, 9, 20, 12);
      expect(formatLongDate(utc), formatLongDate(utc.toLocal()));
    });
  });
}
