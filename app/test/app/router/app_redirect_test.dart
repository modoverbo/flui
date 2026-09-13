import 'package:flui/app/router/app_redirect.dart';
import 'package:flui/app/router/app_routes.dart';
import 'package:flui/features/auth/domain/auth_status.dart';
import 'package:flui/features/subscription/domain/access_gate.dart';
import 'package:flutter_test/flutter_test.dart';

typedef RedirectCase = (AuthStatus, AccessGate, String location, String?);

String splashFrom(String location) =>
    Uri(path: AppRoutes.splash, queryParameters: {'from': location}).toString();

void main() {
  const out = AuthStatus.signedOut;
  const inn = AuthStatus.signedIn;
  const restoring = AuthStatus.unknown;
  const granted = AccessGate.granted;
  const denied = AccessGate.denied;
  const loading = AccessGate.unknown;
  const failed = AccessGate.error;

  final cases = <RedirectCase>[
    // Restoring the session: wait on the splash, remember where to go.
    (restoring, loading, '/welcome', splashFrom('/welcome')),
    (restoring, loading, '/checkout/return', splashFrom('/checkout/return')),
    (restoring, granted, '/splash', null),
    (restoring, loading, splashFrom('/today'), null),

    // Signed out: only the public entry routes.
    (out, loading, '/welcome', null),
    (out, loading, '/intro', null),
    (out, loading, '/login', null),
    (out, loading, '/register', null),
    (out, loading, '/reset-password', null),
    (out, loading, '/', '/welcome'),
    (out, loading, '/today', '/welcome'),
    (out, loading, '/progress', '/welcome'),
    (out, loading, '/paywall', '/welcome'),
    (out, loading, '/today/time', '/welcome'),
    (out, loading, '/checkout/return', '/login'),
    (out, loading, '/splash', '/welcome'),
    (out, loading, splashFrom('/register'), '/register'),
    (out, loading, splashFrom('/checkout/return'), '/login'),

    // Signed in, access not known yet (or failed): splash with retry.
    (inn, loading, '/today', splashFrom('/today')),
    (inn, failed, '/paywall', splashFrom('/paywall')),
    (inn, loading, '/login', splashFrom('/login')),
    (inn, loading, splashFrom('/today'), null),
    (inn, failed, '/splash', null),

    // Signed in without access: paywall and checkout return only.
    (inn, denied, '/paywall', null),
    (inn, denied, '/checkout/return', null),
    (inn, denied, '/today', '/paywall'),
    (inn, denied, '/today/time', '/paywall'),
    (inn, denied, '/login', '/paywall'),
    (inn, denied, '/welcome', '/paywall'),
    (inn, denied, '/', '/paywall'),
    (inn, denied, splashFrom('/checkout/return'), '/checkout/return'),
    (inn, denied, splashFrom('/words'), '/paywall'),

    // Signed in with access: the app.
    (inn, granted, '/today', null),
    (inn, granted, '/today/time', null),
    (inn, granted, '/words', null),
    (inn, granted, '/practice', null),
    (inn, granted, '/reading', null),
    (inn, granted, '/progress', null),
    (inn, granted, '/', '/today'),
    (inn, granted, '/welcome', '/today'),
    (inn, granted, '/login', '/today'),
    (inn, granted, '/register', '/today'),
    (inn, granted, '/paywall', '/today'),
    (inn, granted, '/checkout/return', '/today/time'),
    (inn, granted, '/splash', '/today'),
    (inn, granted, splashFrom('/words'), '/words'),
    (inn, granted, splashFrom('/checkout/return'), '/today/time'),
    (inn, granted, splashFrom('/login'), '/today'),

    // Never follow `from` outside the app.
    (inn, granted, splashFrom('//evil.example'), '/today'),
    (inn, granted, splashFrom('https://evil.example/x'), '/today'),
    (inn, granted, splashFrom('/splash'), '/today'),
    (out, loading, splashFrom('//evil.example'), '/welcome'),
  ];

  group('appRedirect truth table', () {
    for (final (auth, access, location, expected) in cases) {
      test('$auth + $access at $location -> $expected', () {
        final result = appRedirect(
          auth: auth,
          access: access,
          location: Uri.parse(location),
        );

        expect(result, expected);
      });
    }
  });

  test('keeps query parameters of the remembered destination', () {
    final result = appRedirect(
      auth: inn,
      access: granted,
      location: Uri.parse(splashFrom('/words?filter=tuya')),
    );

    expect(result, '/words?filter=tuya');
  });
}
