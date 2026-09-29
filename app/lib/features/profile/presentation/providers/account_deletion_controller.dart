import 'package:flui/core/error/result.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/profile/presentation/providers/profile_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'account_deletion_controller.g.dart';

/// Deletes the signed-in user's own account (U22e, decision #434) — a
/// deliberately confirmed action, never retried automatically.
///
/// `state` is `true` while a deletion is in flight, driving the confirm
/// button's `isLoading`. [delete] itself also guards against a second call
/// landing before that rebuild is observed (a genuine race on a fast double
/// tap): it returns `null` in that case, meaning "ignored, nothing new
/// happened" — the caller should show nothing rather than a second result.
///
/// Signing out on success happens HERE, not in the calling widget
/// (orchestrator review finding): the caller (`_AccountDeletionCard`) can
/// unmount mid-request — a tab switch, a `pop`, any navigation — while the
/// server has already deleted the account. If sign-out depended on the
/// widget's `context.mounted`, the app would keep a local session for a
/// user that no longer exists (a zombie session until the next token
/// refresh fails). Reading both repositories BEFORE the `await` (rather
/// than after, or via `ref.keepAlive()`) means the rest of this method
/// never touches `ref` again except the already-guarded `ref.mounted`
/// check, so it stays safe even if THIS provider itself gets disposed
/// while the request is in flight — no `ref` use after dispose, no need to
/// keep this autoDispose provider (or `SignOutController`, itself also
/// autoDispose and not otherwise pinned here) alive artificially.
@riverpod
class AccountDeletionController extends _$AccountDeletionController {
  @override
  bool build() => false; // true while a deletion is in flight.

  Future<Result<void>?> delete() async {
    if (state) return null;
    state = true;
    final repository = ref.read(accountDeletionRepositoryProvider);
    final authRepository = ref.read(authRepositoryProvider);
    final result = await repository.deleteAccount();
    if (result case Ok()) await authRepository.signOut();
    if (ref.mounted) state = false;
    return result;
  }
}
