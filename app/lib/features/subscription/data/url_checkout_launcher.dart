import 'package:flui/features/subscription/domain/checkout_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

typedef LaunchUrl = Future<bool> Function(
  Uri url, {
  LaunchMode mode,
  String? webOnlyWindowName,
});

/// Opens the Whop hosted checkout: same tab on web (Whop redirects back to
/// `/checkout/return`), external browser on mobile.
final class UrlCheckoutLauncher implements CheckoutLauncher {
  const new({this.isWeb = kIsWeb, this.launch = launchUrl});

  final bool isWeb;
  final LaunchUrl launch;

  @override
  Future<bool> open(Uri purchaseUrl) {
    if (purchaseUrl.scheme != 'https') return Future.value(false);
    return isWeb
        ? launch(purchaseUrl, webOnlyWindowName: '_self')
        : launch(purchaseUrl, mode: LaunchMode.externalApplication);
  }
}
