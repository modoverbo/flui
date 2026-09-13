import 'package:flui/core/l10n/gen/app_localizations.dart';
import 'package:flui/features/auth/domain/credentials_validator.dart';

String? emailErrorText(AppLocalizations l10n, EmailError? error) =>
    switch (error) {
      EmailError.empty => l10n.validationEmailEmpty,
      EmailError.invalid => l10n.validationEmailInvalid,
      null => null,
    };

String? passwordErrorText(AppLocalizations l10n, PasswordError? error) =>
    switch (error) {
      PasswordError.empty => l10n.validationPasswordEmpty,
      PasswordError.tooShort => l10n.validationPasswordTooShort,
      null => null,
    };

String? nameErrorText(AppLocalizations l10n, NameError? error) =>
    switch (error) {
      NameError.empty => l10n.validationNameEmpty,
      NameError.tooLong => l10n.validationNameTooLong,
      null => null,
    };
