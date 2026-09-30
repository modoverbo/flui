import 'package:flui/app/router/app_router.dart';
import 'package:flui/app/router/app_routes.dart';
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

  testWidgets(
    'switching tabs while a deletion is in flight still signs out once it '
    'completes (orchestrator review finding, runtime harness)',
    (tester) async {
      await runAccountDeletionTabSwitchFlow(tester);
    },
  );
}

/// A signed-in, entitled user opens PROGRESO, confirms account deletion
/// through both dialogs, and the app really navigates away (through the
/// live router) once the account is gone — not just a mocked sign-out.
Future<void> runAccountDeletionFlow(WidgetTester tester) async {
  final harness = AppHarness(signedInAs: _ana, access: _trialing);

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

/// Orchestrator review finding on `ddd94bd`: sign-out on success must not
/// depend on the PROGRESO page staying mounted/visible. This confirms
/// deletion, switches away to the HOY tab BEFORE the (artificially slow)
/// fake resolves, and only then lets it resolve — the app must still end up
/// signed out once it does, not leave a local session for a deleted user.
Future<void> runAccountDeletionTabSwitchFlow(WidgetTester tester) async {
  final harness = AppHarness(signedInAs: _ana, access: _trialing);

  await harness.pumpApp(
    tester,
    initialLocation: AppRoutes.progress,
    arrange: (harness) {
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
  // Latency ONLY on the account-deletion fake; every other fake in the
  // harness stays instant.
  harness.accountDeletion.latency = const Duration(milliseconds: 300);

  final deleteButton = find.text(_l10n.accountDeletionAction);
  await tester.ensureVisible(deleteButton);
  await tester.tap(deleteButton);
  await tester.pumpAndSettle();
  await tester.tap(find.text(_l10n.accountDeletionContinueAction));
  await tester.pumpAndSettle();
  await tester.tap(find.text(_l10n.accountDeletionFinalConfirmAction));
  // No `pumpAndSettle` here: the deletion request is now in flight (the
  // fake is still delayed). Switch tabs while it is still running.
  await tester.pump();

  // NOTE (empirically verified against this app's real shell, not assumed):
  // switching to another BOTTOM-BAR TAB does NOT unmount `ProgressPage` --
  // the shell deliberately keeps every branch alive in an `IndexedStack`
  // (design D29, "IndexedStack kept", so tab state survives switching), so
  // `context.mounted` stays `true` and cannot reproduce the reported bug
  // that way in THIS codebase. The real reproduction is navigating to a
  // ROOT-navigator route that replaces the shell (design §11: diagnosis
  // stays on the root navigator, outside every branch) -- reached here the
  // same way the real retake entry does it.
  harness.container
      .read(goRouterProvider)
      .go('${AppRoutes.diagnosisLive}?retake=1');
  await tester.pump();

  // `integration_test` runs on the REAL Flutter engine, not a `FakeAsync`
  // zone: `pumpAndSettle` only waits for pending FRAMES, not an unrelated
  // background `Future.delayed`. Once nothing watches
  // `accountDeletionControllerProvider` any more (the page that did is
  // gone), its resolution schedules no frame at all -- so this must wait
  // in REAL wall-clock time, past the fake's artificial delay, before the
  // next pump can observe the result.
  await Future<void>.delayed(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();

  expect(harness.accountDeletion.callCount, 1);
  expect(harness.auth.currentUser, isNull);
}
