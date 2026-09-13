import 'dart:async';

import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/features/auth/domain/app_user.dart';
import 'package:flui/features/auth/domain/auth_repository.dart';
import 'package:flui/features/auth/domain/sign_up_outcome.dart';

/// In-memory auth for `BACKEND=fake` and tests. No network.
///
/// Any valid email and password signs in; a registered email must use its
/// password.
final class FakeAuthRepository implements AuthRepository {
  new({
    AppUser? initialUser,
    this.latency = Duration.zero,
    this.requireEmailConfirmation = false,
  }) : _current = initialUser;

  final Duration latency;
  final bool requireEmailConfirmation;

  final _accounts = <String, ({String password, AppUser user})>{};
  final _changes = StreamController<AppUser?>.broadcast();
  final List<String> passwordResetEmails = [];
  AppUser? _current;

  var _nextId = 1;

  /// Returned once by the next call, then cleared.
  Failure? nextFailure;

  @override
  AppUser? get currentUser => _current;

  @override
  Stream<AppUser?> authStateChanges() => Stream.multi((controller) {
    controller.add(_current);
    final subscription = _changes.stream.listen(controller.add);
    controller.onCancel = subscription.cancel;
  });

  @override
  Future<Result<SignUpOutcome>> signUp({
    required String displayName,
    required String email,
    required String password,
  }) async {
    await _simulateLatency();
    if (_takeFailure() case final failure?) return Result.err(failure);

    final normalized = email.trim().toLowerCase();
    if (_accounts.containsKey(normalized)) {
      return const Result.err(AuthFailure(AuthErrorCode.emailAlreadyInUse));
    }
    final user = AppUser(
      id: 'fake-user-${_nextId++}',
      email: normalized,
      displayName: displayName.trim(),
    );
    _accounts[normalized] = (password: password, user: user);

    if (requireEmailConfirmation) {
      return Result.ok(SignUpOutcome.confirmationRequired(normalized));
    }
    _setCurrent(user);
    return Result.ok(SignUpOutcome.signedUp(user));
  }

  @override
  Future<Result<AppUser>> signIn({
    required String email,
    required String password,
  }) async {
    await _simulateLatency();
    if (_takeFailure() case final failure?) return Result.err(failure);

    final normalized = email.trim().toLowerCase();
    final account = _accounts[normalized];
    if (account != null && account.password != password) {
      return const Result.err(AuthFailure(AuthErrorCode.invalidCredentials));
    }
    final user =
        account?.user ??
        AppUser(id: 'fake-user-${_nextId++}', email: normalized);
    _accounts[normalized] ??= (password: password, user: user);
    _setCurrent(user);
    return Result.ok(user);
  }

  @override
  Future<Result<void>> sendPasswordReset({required String email}) async {
    await _simulateLatency();
    if (_takeFailure() case final failure?) return Result.err(failure);
    passwordResetEmails.add(email.trim().toLowerCase());
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> signOut() async {
    await _simulateLatency();
    if (_takeFailure() case final failure?) return Result.err(failure);
    _setCurrent(null);
    return const Result.ok(null);
  }

  Future<void> dispose() => _changes.close();

  void _setCurrent(AppUser? user) {
    _current = user;
    _changes.add(user);
  }

  Failure? _takeFailure() {
    final failure = nextFailure;
    nextFailure = null;
    return failure;
  }

  Future<void> _simulateLatency() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }
}
