import 'package:flui/core/error/result.dart';
import 'package:flui/features/auth/domain/app_user.dart';
import 'package:flui/features/auth/domain/sign_up_outcome.dart';

abstract interface class AuthRepository {
  AppUser? get currentUser;

  /// Emits the current user immediately, then every change.
  Stream<AppUser?> authStateChanges();

  Future<Result<SignUpOutcome>> signUp({
    required String displayName,
    required String email,
    required String password,
  });

  Future<Result<AppUser>> signIn({
    required String email,
    required String password,
  });

  Future<Result<void>> sendPasswordReset({required String email});

  Future<Result<void>> signOut();
}
