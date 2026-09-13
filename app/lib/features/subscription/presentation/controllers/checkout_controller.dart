import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'checkout_controller.freezed.dart';
part 'checkout_controller.g.dart';

enum CheckoutStatus { idle, creating, redirecting, alreadySubscribed, failed }

@freezed
abstract class CheckoutState with _$CheckoutState {
  const factory({
    @Default(CheckoutStatus.idle) CheckoutStatus status,
    String? planId,
    Failure? failure,
  }) = _CheckoutState;

  const new _();

  bool get isBusy =>
      status == CheckoutStatus.creating || status == CheckoutStatus.redirecting;
}

/// Paywall CTA: create the Whop checkout and open it.
@riverpod
class CheckoutController extends _$CheckoutController {
  @override
  CheckoutState build() => const CheckoutState();

  Future<void> start(String planId) async {
    if (state.isBusy) return;
    state = CheckoutState(status: CheckoutStatus.creating, planId: planId);

    final result = await ref
        .read(subscriptionRepositoryProvider)
        .createCheckout(planId: planId);
    if (!ref.mounted) return;

    switch (result) {
      case Ok(value: final purchaseUrl):
        state = state.copyWith(status: CheckoutStatus.redirecting);
        final opened = await ref
            .read(checkoutLauncherProvider)
            .open(purchaseUrl);
        if (!ref.mounted || opened) return;
        state = CheckoutState(
          status: CheckoutStatus.failed,
          planId: planId,
          failure: const SubscriptionFailure(
            SubscriptionErrorCode.couldNotOpenCheckout,
          ),
        );
      case Err(
        failure: SubscriptionFailure(
          code: SubscriptionErrorCode.alreadySubscribed,
        ),
      ):
        state = CheckoutState(
          status: CheckoutStatus.alreadySubscribed,
          planId: planId,
        );
        // The router leaves the paywall once access is known.
        final userId = ref.read(authUserProvider).value?.id;
        if (userId != null) {
          await ref
              .read(accessStatusControllerProvider(userId).notifier)
              .refresh();
        }
      case Err(:final failure):
        state = CheckoutState(
          status: CheckoutStatus.failed,
          planId: planId,
          failure: failure,
        );
    }
  }
}
