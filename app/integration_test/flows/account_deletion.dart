import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/config/feature_flags.dart';
import 'package:flui/core/l10n/gen/app_localizations.dart';
import 'package:flui/features/auth/domain/app_user.dart';
import 'package:flui/features/diagnosis/domain/skill_profile_repository.dart';
import 'package:flui/features/subscription/domain/access_status.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/skill_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

const _ana = AppUser(id: 'u1', email: 'ana@correo.com', displayName: 'Ana');
const _trialing = AccessStatus(
  hasAccess: true,
  entitlementStatus: EntitlementStatus.trialing,
);
final AppLocalizations _l10n = lookupAppLocalizations(const Locale('es'));

/// Registers this flow's `testWidgets` case — called once from the single
/// `integration_test/app_test.dart` entry point, matching every other flow
/// in this bundle.
void registerAccountDeletionTests() {
  testWidgets('delete my account from PROGRESO -> signs out and lands on the '
      'signed-out screen (U22e, runtime harness)', (tester) async {
    await runAccountDeletionFlow(tester);
  });
}

/// A signed-in, entitled user opens PROGRESO, confirms account deletion
/// through both dialogs, and the app really navigates away (through the
/// live router) once the account is gone — not just a mocked sign-out.
Future<void> runAccountDeletionFlow(WidgetTester tester) async {
  final harness = AppHarness(
    signedInAs: _ana,
    access: _trialing,
    overrides: [speakingGymEnabledProvider.overrideWithValue(true)],
  );

  await harness.pumpApp(
    tester,
    initialLocation: AppRoutes.progress,
    arrange: (harness) {
      // A completed diagnosis baseline satisfies the mandatory-diagnosis
      // gate so `/progress` renders directly, same as `progress_playback`.
      harness.skillProfiles.seedProfile(
        SkillProfileRecord(
          id: 'baseline',
          kind: SkillProfileKind.baseline,
          diagnosedAt: DateTime(2026, 8, 2),
          profile: const SkillProfile(
            topArea: SkillArea.thinking,
            secondArea: SkillArea.language,
            strengths: [BehaviorCode.preciseWord],
            evidence: [],
          ),
        ),
      );
    },
  );

  final deleteButton = find.text(_l10n.accountDeletionAction);
  await tester.ensureVisible(deleteButton);
  await tester.tap(deleteButton);
  await tester.pumpAndSettle();
  await tester.tap(find.text(_l10n.accountDeletionContinueAction));
  await tester.pumpAndSettle();
  await tester.tap(find.text(_l10n.accountDeletionFinalConfirmAction));
  await tester.pumpAndSettle();

  expect(harness.accountDeletion.callCount, 1);
  // The router reacts to the (now null) auth state, same as plain sign out,
  // and lands on the public welcome/signed-out screen.
  expect(find.text(_l10n.welcomeStart), findsOneWidget);
}
