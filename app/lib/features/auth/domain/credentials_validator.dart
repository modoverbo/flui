enum EmailError { empty, invalid }

enum PasswordError { empty, tooShort }

enum NameError { empty, tooLong }

/// Client-side checks that mirror Supabase Auth and the `profiles` table.
abstract final class CredentialsValidator {
  /// `supabase/config.toml` → `[auth] minimum_password_length`.
  static const minPasswordLength = 8;

  /// `profiles.display_name` check constraint.
  static const maxDisplayNameLength = 80;

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static EmailError? email(String value) {
    final email = value.trim();
    if (email.isEmpty) return EmailError.empty;
    if (!_emailPattern.hasMatch(email)) return EmailError.invalid;
    return null;
  }

  /// Rules for a password being created.
  static PasswordError? newPassword(String value) {
    if (value.isEmpty) return PasswordError.empty;
    if (value.length < minPasswordLength) return PasswordError.tooShort;
    return null;
  }

  /// Rules for signing in: the server decides whether it matches.
  static PasswordError? existingPassword(String value) =>
      value.isEmpty ? PasswordError.empty : null;

  static NameError? displayName(String value) {
    final name = value.trim();
    if (name.isEmpty) return NameError.empty;
    if (name.length > maxDisplayNameLength) return NameError.tooLong;
    return null;
  }
}
