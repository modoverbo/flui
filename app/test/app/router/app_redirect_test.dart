import 'package:flui/app/router/app_redirect.dart';
import 'package:flui/app/router/app_routes.dart';
import 'package:flui/features/auth/domain/auth_status.dart';
import 'package:flui/features/daily/domain/daily_gate.dart';
import 'package:flui/features/diagnosis/presentation/diagnosis_gate.dart';
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
    // Retired tabs: old links land where the feature lives now.
    (inn, granted, '/practice', '/today'),
    (inn, granted, '/reading', '/words'),
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
          daily: DailyGate.planned,
          location: Uri.parse(location),
        );

        expect(result, expected);
      });
    }
  });

  // Once per local day: without today's session the app asks for the time
  // budget first. Tu progreso stays reachable (account and sign out).
  final dailyCases = <(DailyGate, String location, String?)>[
    (DailyGate.needsBudget, '/today', '/today/time'),
    (DailyGate.needsBudget, '/', '/today/time'),
    (DailyGate.needsBudget, '/login', '/today/time'),
    (DailyGate.needsBudget, '/words', '/today/time'),
    (DailyGate.needsBudget, '/words/abc', '/today/time'),
    (DailyGate.needsBudget, '/practice', '/today'),
    (DailyGate.needsBudget, '/reading', '/words'),
    (DailyGate.needsBudget, '/session', '/today/time'),
    (DailyGate.needsBudget, '/checkout/return', '/today/time'),
    (DailyGate.needsBudget, splashFrom('/words'), '/today/time'),
    (DailyGate.needsBudget, '/today/time', null),
    (DailyGate.needsBudget, '/progress', null),
    (DailyGate.unknown, '/today', splashFrom('/today')),
    (DailyGate.unknown, '/session', splashFrom('/session')),
    (DailyGate.unknown, splashFrom('/today'), null),
    (DailyGate.unknown, '/today/time', null),
    (DailyGate.unknown, '/progress', null),
    (DailyGate.planned, '/session', null),
    (DailyGate.planned, '/session?mode=review', null),
    (DailyGate.planned, '/words/abc', null),
    (DailyGate.planned, '/today/time', null),
    (DailyGate.unavailable, '/today', null),
    (DailyGate.unavailable, splashFrom('/today'), '/today'),
  ];

  group('daily time budget guard', () {
    for (final (daily, location, expected) in dailyCases) {
      test('granted + $daily at $location -> $expected', () {
        expect(
          appRedirect(
            auth: inn,
            access: granted,
            daily: daily,
            location: Uri.parse(location),
          ),
          expected,
        );
      });
    }

    test('signed out and paywall rules win over the daily guard', () {
      expect(
        appRedirect(
          auth: out,
          access: loading,
          daily: DailyGate.needsBudget,
          location: Uri.parse('/today'),
        ),
        '/welcome',
      );
      expect(
        appRedirect(
          auth: inn,
          access: denied,
          daily: DailyGate.needsBudget,
          location: Uri.parse('/today'),
        ),
        '/paywall',
      );
    });
  });

  // DiagnosisGate x AccessGate.granted (design part-3 §11, D16). Every
  // existing case above (and every case not listed here) passes no
  // `diagnosis:` argument at all, defaulting to `DiagnosisGate.notRequired`
  // — proof that flag-off behaves byte-identically to the redirect table
  // above, with zero new branches ever evaluated.
  group('diagnosis gate (speakingGym on)', () {
    String? redirect(DiagnosisGate diagnosis, String location) => appRedirect(
      auth: inn,
      access: granted,
      daily: DailyGate.planned,
      location: Uri.parse(location),
      speakingGym: true,
      diagnosis: diagnosis,
    );

    test('required forces every non-diagnosis path to /diagnosis', () {
      expect(redirect(DiagnosisGate.required, '/today'), '/diagnosis');
      expect(redirect(DiagnosisGate.required, '/words'), '/diagnosis');
      expect(redirect(DiagnosisGate.required, '/paywall'), '/diagnosis');
    });

    test('required never redirects away from the diagnosis routes', () {
      expect(redirect(DiagnosisGate.required, '/diagnosis'), null);
      expect(redirect(DiagnosisGate.required, '/diagnosis/live'), null);
      expect(redirect(DiagnosisGate.required, '/diagnosis/result'), null);
    });

    test('checkout return goes to diagnosis when required, else the daily '
        'time budget', () {
      expect(
        redirect(DiagnosisGate.required, '/checkout/return'),
        '/diagnosis',
      );
      expect(
        redirect(DiagnosisGate.completed, '/checkout/return'),
        '/today/time',
      );
    });

    test('unknown/error wait, exactly like AccessGate', () {
      expect(redirect(DiagnosisGate.unknown, '/today'), splashFrom('/today'));
      expect(redirect(DiagnosisGate.error, '/today'), splashFrom('/today'));
    });

    test('completed leaves /diagnosis/live only with an explicit retake', () {
      expect(redirect(DiagnosisGate.completed, '/diagnosis/live'), '/today');
      expect(
        redirect(DiagnosisGate.completed, '/diagnosis/live?retake=1'),
        null,
      );
      // The intro page itself stays reachable without a redirect — it is
      // where a completed user finds the retake entry (U14c).
      expect(redirect(DiagnosisGate.completed, '/diagnosis'), null);
    });

    test('completed behaves exactly like notRequired everywhere else', () {
      expect(redirect(DiagnosisGate.completed, '/today'), null);
      expect(redirect(DiagnosisGate.completed, '/words'), null);
    });

    test('retired routes still win over a required diagnosis', () {
      expect(redirect(DiagnosisGate.required, '/practice'), '/today');
    });
  });

  test('keeps query parameters of the remembered destination', () {
    final result = appRedirect(
      auth: inn,
      access: granted,
      daily: DailyGate.planned,
      location: Uri.parse(splashFrom('/words?filter=tuya')),
    );

    expect(result, '/words?filter=tuya');
  });
}
