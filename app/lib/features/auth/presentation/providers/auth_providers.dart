import 'package:flui/features/auth/domain/app_user.dart';
import 'package:flui/features/auth/domain/auth_repository.dart';
import 'package:flui/features/auth/domain/auth_status.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_providers.g.dart';

/// Overridden in `bootstrap.dart` (Supabase or fake) and in tests.
@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  throw UnimplementedError('authRepositoryProvider must be overridden.');
}

/// The signed-in user, or `null` when signed out.
@Riverpod(keepAlive: true)
Stream<AppUser?> authUser(Ref ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
}

@Riverpod(keepAlive: true)
AuthStatus authStatus(Ref ref) {
  return switch (ref.watch(authUserProvider)) {
    AsyncValue(hasValue: true, :final value) =>
      value == null ? AuthStatus.signedOut : AuthStatus.signedIn,
    AsyncError() => AuthStatus.signedOut,
    _ => AuthStatus.unknown,
  };
}
