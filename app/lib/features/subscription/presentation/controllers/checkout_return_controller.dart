import 'dart:async';

import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/subscription/domain/access_poller.dart';
import 'package:flui/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'checkout_return_controller.g.dart';

enum CheckoutReturnState { activating, activated, timedOut }

/// Polls `my_access()` while `/checkout/return` is open.
///
/// Query parameters on the return URL are never trusted: only the webhook
/// can grant access.
@riverpod
class CheckoutReturnController extends _$CheckoutReturnController {
  var _generation = 0;

  @override
  CheckoutReturnState build() {
    ref.onDispose(() => _generation++);
    unawaited(Future.microtask(_poll));
    return CheckoutReturnState.activating;
  }

  void retry() {
    if (state == CheckoutReturnState.activating) return;
    state = CheckoutReturnState.activating;
    unawaited(_poll());
  }

  Future<void> _poll() async {
    if (!ref.mounted) return;
    final generation = ++_generation;
    bool isStale() => !ref.mounted || generation != _generation;

    final repository = ref.read(subscriptionRepositoryProvider);
    final outcome = await ref
        .read(accessPollerProvider)
        .waitForAccess(repository.fetchAccess, isCancelled: isStale);
    if (isStale()) return;

    switch (outcome) {
      case AccessActivated(:final status):
        state = CheckoutReturnState.activated;
        final userId = ref.read(authUserProvider).value?.id;
        if (userId != null) {
          ref
              .read(accessStatusControllerProvider(userId).notifier)
              .publish(status);
        }
      case AccessPollTimedOut():
        state = CheckoutReturnState.timedOut;
      case AccessPollCancelled():
        break;
    }
  }
}
