import 'package:flui/features/subscription/data/fake_subscription_repository.dart';
import 'package:flui/features/subscription/domain/checkout_launcher.dart';

/// Pretends the user completed the hosted checkout, then comes back to the
/// app's return route through [onReturn] (no page reload, no network).
final class FakeCheckoutLauncher implements CheckoutLauncher {
  new({required this.subscriptions, required this.onReturn});

  final FakeSubscriptionRepository subscriptions;
  final void Function() onReturn;
  final List<Uri> openedUrls = [];

  @override
  Future<bool> open(Uri purchaseUrl) async {
    openedUrls.add(purchaseUrl);
    subscriptions.completeCheckout();
    onReturn();
    return true;
  }
}
