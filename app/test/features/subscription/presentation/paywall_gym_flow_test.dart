import 'package:flui/app/router/app_router.dart';
import 'package:flui/app/router/app_routes.dart';
import 'package:flui/features/auth/domain/app_user.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/skill_profile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../integration_test/support/app_harness.dart';
import '../../../helpers/pump_app.dart';

const _ana = AppUser(
  id: 'ignored',
  email: 'ana@correo.com',
  displayName: 'Ana',
);

String _location(AppHarness harness) => harness.container
    .read(goRouterProvider)
    .routerDelegate
    .currentConfiguration
    .uri
    .toString();

void main() {
  group('Paywall (U14b, real path)', () {
    testWidgets(
      'a new signed-in user with no access sees the static paywall copy, '
      'never a retired onboarding screen, starts the trial, and is routed '
      'straight into the mandatory diagnosis',
      (tester) async {
        final harness = AppHarness(signedInAs: _ana);
        await harness.pumpApp(tester, initialLocation: AppRoutes.paywall);

        // Page 1: no skill profile exists yet (diagnosis has not run) —
        // static, profile-independent copy, never the retired onboarding
        // echo.
        expect(_location(harness), AppRoutes.paywall);
        expect(find.text(l10nEs.paywallPlanGymGeneric), findsOneWidget);

        await tester.tap(find.text(l10nEs.paywallNext));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10nEs.paywallNext));
        await tester.pumpAndSettle();
        expect(find.text(l10nEs.paywallChooseTitle), findsOneWidget);

        // Starts the trial: the recommended plan is already selected by
        // default, so the CTA alone is enough (paywall_page_test.dart's
        // own established pattern).
        await tester.tap(find.text(l10nEs.paywallCta));
        await tester.pump();
        await tester.pumpAndSettle();

        // The trial starts the entitlement; the mandatory diagnosis gate
        // (U14a) then forces the very next screen — never /today, never a
        // retired onboarding screen (there is none left to show a
        // signed-in user).
        expect(_location(harness), AppRoutes.diagnosis);
        expect(find.text(l10nEs.diagnosisIntroTitle), findsOneWidget);
        expect(harness.subscriptions.checkoutRequests, isNotEmpty);
      },
    );

    testWidgets(
      'a reactivation view (existing profile, lapsed entitlement) echoes '
      'the top-opportunity area instead of the static copy',
      (tester) async {
        final harness = AppHarness(signedInAs: _ana);
        await harness.pumpApp(
          tester,
          initialLocation: AppRoutes.paywall,
          arrange: (h) => h.skillProfiles.save(
            sessionId: 'diag-1',
            profile: const SkillProfile(
              topArea: SkillArea.thinking,
              secondArea: SkillArea.language,
              strengths: [],
              evidence: [],
            ),
          ),
        );

        expect(
          find.text(l10nEs.paywallPlanGymEcho(l10nEs.diagnosisAreaThinking)),
          findsOneWidget,
        );
        expect(find.text(l10nEs.paywallPlanGymGeneric), findsNothing);
      },
    );
  });
}
