import 'package:flui/features/auth/data/supabase_auth_repository.dart';
import 'package:flui/features/auth/domain/app_user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  User user(
    Map<String, dynamic>? metadata, {
    String? email = 'ana@correo.com',
  }) {
    return User(
      id: 'user-1',
      appMetadata: const {},
      userMetadata: metadata,
      aud: 'authenticated',
      email: email,
      createdAt: '2026-09-13T10:00:00Z',
    );
  }

  test('maps id, email and display_name metadata', () {
    expect(
      appUserFromSupabase(user({'display_name': 'Ana'})),
      const AppUser(id: 'user-1', email: 'ana@correo.com', displayName: 'Ana'),
    );
  });

  test('blank or missing display_name becomes null', () {
    expect(
      appUserFromSupabase(user({'display_name': '  '})).displayName,
      isNull,
    );
    expect(appUserFromSupabase(user(null)).displayName, isNull);
    expect(appUserFromSupabase(user({'display_name': 42})).displayName, isNull);
  });

  test('missing email becomes an empty string', () {
    expect(appUserFromSupabase(user(null, email: null)).email, '');
  });
}
