import 'package:flui/features/subscription/data/url_checkout_launcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  final url = Uri.parse('https://whop.com/checkout/abc');

  late List<(Uri, LaunchMode, String?)> calls;

  Future<bool> fakeLaunch(
    Uri url, {
    LaunchMode mode = LaunchMode.platformDefault,
    String? webOnlyWindowName,
  }) async {
    calls.add((url, mode, webOnlyWindowName));
    return true;
  }

  setUp(() => calls = []);

  test('on web opens the checkout in the same tab', () async {
    final launcher = UrlCheckoutLauncher(isWeb: true, launch: fakeLaunch);

    expect(await launcher.open(url), isTrue);
    expect(calls, [(url, LaunchMode.platformDefault, '_self')]);
  });

  test('on mobile opens the external browser', () async {
    final launcher = UrlCheckoutLauncher(isWeb: false, launch: fakeLaunch);

    await launcher.open(url);

    expect(calls, [(url, LaunchMode.externalApplication, null)]);
  });

  test('refuses non-https checkout urls', () async {
    final launcher = UrlCheckoutLauncher(isWeb: true, launch: fakeLaunch);

    expect(await launcher.open(Uri.parse('javascript:alert(1)')), isFalse);
    expect(calls, isEmpty);
  });
}
