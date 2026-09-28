import 'dart:typed_data';

import 'package:flui/app/router/app_router.dart';
import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/audio/audio_providers.dart';
import 'package:flui/core/audio/speech_recorder.dart';
import 'package:flui/core/config/feature_flags.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/mic/mic_providers.dart';
import 'package:flui/core/mic/presentation/mic_button.dart';
import 'package:flui/features/auth/domain/app_user.dart';
import 'package:flui/features/daily/presentation/providers/daily_providers.dart';
import 'package:flui/features/diagnosis/data/fake_skill_profile_repository.dart';
import 'package:flui/features/diagnosis/presentation/diagnosis_result_page.dart';
import 'package:flui/features/diagnosis/presentation/providers/diagnosis_providers.dart';
import 'package:flui/features/speaking/data/fake_speech_analysis_repository.dart';
import 'package:flui/features/speaking/presentation/providers/speaking_providers.dart';
import 'package:flui/features/subscription/domain/access_status.dart';
import 'package:flui/features/training/presentation/controllers/loop_mic_target.dart';
import 'package:flui/shared/widgets/empty_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../integration_test/support/app_harness.dart';
import '../../../helpers/pump_app.dart';

const _ana = AppUser(
  id: 'ignored',
  email: 'ana@correo.com',
  displayName: 'Ana',
);
const _trialing = AccessStatus(
  hasAccess: true,
  entitlementStatus: EntitlementStatus.trialing,
);

/// Ported from `app_router_test.dart`'s own — a permission-granted
/// recorder that finishes instantly, real enough for `HoldToRecord` to
/// drive a full pointer-down/up cycle through `MicController`.
final class _FakeSpeechRecorder implements SpeechRecorder {
  new();

  @override
  Stream<double> get amplitude => const Stream.empty();

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> start() async {}

  @override
  Future<Uint8List> stop() async => Uint8List.fromList(const [1, 2, 3]);

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}

String _location(AppHarness harness) => harness.container
    .read(goRouterProvider)
    .routerDelegate
    .currentConfiguration
    .uri
    .toString();

Future<void> _recordOneSlot(WidgetTester tester, AppHarness harness) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byType(MicButton)),
  );
  for (var i = 0; i < 3; i++) {
    await tester.pump();
  }
  harness.clock.advance(const Duration(milliseconds: 700));
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  group('Diagnosis flow (U14a, real path)', () {
    testWidgets(
      'an entitled user with no profile is redirected through intro -> '
      'live, completes all 3 slots via the root-layer MicDock (never the '
      'quick-practice fallback), and lands on the result with a real '
      'derived profile; afterwards the gate stops redirecting',
      (tester) async {
        final recorder = _FakeSpeechRecorder();
        final harness = AppHarness(
          signedInAs: _ana,
          access: _trialing,
          overrides: [
            speakingGymEnabledProvider.overrideWithValue(true),
            speechRecorderFactoryProvider.overrideWithValue(() => recorder),
          ],
        );
        await harness.pumpApp(tester, arrange: (h) => h.planToday());

        // Mandatory gate: a granted user with no profile is forced to the
        // diagnosis intro before anything else, never /today.
        expect(_location(harness), AppRoutes.diagnosis);
        expect(find.text(l10nEs.diagnosisIntroTitle), findsOneWidget);

        await tester.ensureVisible(find.text(l10nEs.diagnosisIntroStart));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10nEs.diagnosisIntroStart));
        await tester.pumpAndSettle();

        expect(_location(harness), AppRoutes.diagnosisLive);

        final registry = harness.container.read(micTargetRegistryProvider);
        for (var slot = 1; slot <= 3; slot++) {
          // Delivers to the diagnosis loop's own root-layer target, never
          // the shell's quick-practice fallback (D24: root beats branch).
          final (target, _) = registry.resolve();
          expect(target, isA<LoopMicTarget>());

          await _recordOneSlot(tester, harness);
        }

        // The loop finished, the profile was computed and saved, and the
        // app navigated to the result — never fabricated: it comes from
        // `latestDiagnosisAttempts()` + `DiagnosisProfiler`, both exercised
        // for real here, not stubbed.
        expect(_location(harness), AppRoutes.diagnosisResult);
        expect(find.text(l10nEs.diagnosisResultTitle), findsOneWidget);
        expect(find.text(l10nEs.diagnosisAreaThinking), findsOneWidget);
        expect(find.text(l10nEs.diagnosisAreaLanguage), findsOneWidget);

        // The gate now stops redirecting: /today is reachable afterward.
        harness.container.read(goRouterProvider).go(AppRoutes.today);
        await tester.pumpAndSettle();
        expect(_location(harness), AppRoutes.today);
      },
    );

    testWidgets(
      'an analysis failure on one slot never advances or fabricates a step '
      '— retrying the same slot recovers',
      (tester) async {
        final recorder = _FakeSpeechRecorder();
        final harness = AppHarness(
          signedInAs: _ana,
          access: _trialing,
          overrides: [
            speakingGymEnabledProvider.overrideWithValue(true),
            speechRecorderFactoryProvider.overrideWithValue(() => recorder),
          ],
        );
        await harness.pumpApp(
          tester,
          initialLocation: AppRoutes.diagnosisLive,
          arrange: (h) => h.planToday(),
        );

        (harness.container.read(
          speechAnalysisRepositoryProvider,
        ) as FakeSpeechAnalysisRepository).nextFailure = const NetworkFailure();
        await _recordOneSlot(tester, harness);

        // Still on the live screen, no fabricated profile, retry offered.
        expect(_location(harness), AppRoutes.diagnosisLive);
        expect(find.text(l10nEs.loopRetryAction), findsOneWidget);

        await tester.tap(find.text(l10nEs.loopRetryAction));
        await tester.pumpAndSettle();

        expect(_location(harness), AppRoutes.diagnosisLive);
        expect(find.text(l10nEs.loopRetryAction), findsNothing);
      },
    );
  });

  group('DiagnosisResultPage never fabricates a profile', () {
    testWidgets('shows an honest message, never a fabricated profile, when '
        'no profile has been saved yet', (tester) async {
      await tester.pumpFlui(
        const DiagnosisResultPage(),
        overrides: [
          currentUserIdProvider.overrideWithValue('u1'),
          skillProfileRepositoryProvider.overrideWithValue(
            FakeSkillProfileRepository(currentUserId: () => 'u1'),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text(l10nEs.diagnosisResultUnavailable), findsOneWidget);
      expect(find.text(l10nEs.diagnosisAreaThinking), findsNothing);
    });
  });
}
