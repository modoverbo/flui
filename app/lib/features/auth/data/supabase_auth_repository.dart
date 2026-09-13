import 'package:flui/core/error/result.dart';
import 'package:flui/features/auth/data/auth_error_mapper.dart';
import 'package:flui/features/auth/domain/app_user.dart';
import 'package:flui/features/auth/domain/auth_repository.dart';
import 'package:flui/features/auth/domain/sign_up_outcome.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// TODO(auth): add Google sign-in and a "new password" screen for the
// password recovery link (not part of Phase A).

/// Email and password auth through Supabase Auth.
final class SupabaseAuthRepository implements AuthRepository {
  new(this._auth, {this.appUrl});

  final GoTrueClient _auth;

  /// Where Supabase email links (confirmation, recovery) send the user.
  final Uri? appUrl;

  @override
  AppUser? get currentUser => switch (_auth.currentUser) {
    final user? => appUserFromSupabase(user),
    null => null,
  };

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield currentUser;
    // `onAuthStateChange` replays past events to new listeners. Mapping every
    // event to the *current* user avoids flickering through stale states.
    yield* _auth.onAuthStateChange.map((_) => currentUser).distinct();
  }

  @override
  Future<Result<SignUpOutcome>> signUp({
    required String displayName,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signUp(
        email: email,
        password: password,
        // Read by the `on_auth_user_created` trigger to fill `profiles`.
        data: {'display_name': displayName},
        emailRedirectTo: appUrl?.toString(),
      );
      final user = response.user;
      if (user == null) return Result.err(mapAuthError(StateError('no user')));
      return Result.ok(
        response.session == null
            ? SignUpOutcome.confirmationRequired(email)
            : SignUpOutcome.signedUp(appUserFromSupabase(user)),
      );
    } on Object catch (error) {
      return Result.err(mapAuthError(error));
    }
  }

  @override
  Future<Result<AppUser>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null) return Result.err(mapAuthError(StateError('no user')));
      return Result.ok(appUserFromSupabase(user));
    } on Object catch (error) {
      return Result.err(mapAuthError(error));
    }
  }

  @override
  Future<Result<void>> sendPasswordReset({required String email}) async {
    try {
      await _auth.resetPasswordForEmail(email, redirectTo: appUrl?.toString());
      return const Result.ok(null);
    } on Object catch (error) {
      return Result.err(mapAuthError(error));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _auth.signOut();
      return const Result.ok(null);
    } on Object catch (error) {
      return Result.err(mapAuthError(error));
    }
  }
}

AppUser appUserFromSupabase(User user) {
  final rawName = user.userMetadata?['display_name'];
  final name = rawName is String ? rawName.trim() : '';
  return AppUser(
    id: user.id,
    email: user.email ?? '',
    displayName: name.isEmpty ? null : name,
  );
}
