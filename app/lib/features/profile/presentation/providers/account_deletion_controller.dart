import 'package:flui/core/error/result.dart';
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
@riverpod
class AccountDeletionController extends _$AccountDeletionController {
  @override
  bool build() => false; // true while a deletion is in flight.

  Future<Result<void>?> delete() async {
    if (state) return null;
    state = true;
    final result = await ref
        .read(accountDeletionRepositoryProvider)
        .deleteAccount();
    if (ref.mounted) state = false;
    return result;
  }
}
