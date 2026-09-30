import 'dart:typed_data';

import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/audio/audio_providers.dart';
import 'package:flui/core/audio/data/fake_speech_player.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/auth/domain/app_user.dart';
import 'package:flui/features/diagnosis/domain/skill_profile_repository.dart';
import 'package:flui/features/subscription/domain/access_status.dart';
import 'package:flui/features/training/data/fake_attempt_audio_store.dart';
import 'package:flui/features/training/domain/attempt_kind.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/observation.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/skill_profile.dart';
import 'package:flui/features/training/domain/speaking_attempt.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:flui/features/training/domain/voice_metrics.dart';
import 'package:flui/features/training/presentation/providers/training_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

const _ana = AppUser(id: 'u1', email: 'ana@correo.com', displayName: 'Ana');
const _trialing = AccessStatus(
  hasAccess: true,
  entitlementStatus: EntitlementStatus.trialing,
);
const _metrics = VoiceMetrics(longPauses: 0, usefulPauses: 0, fillerCount: 0);

/// Registers this flow's `testWidgets` case — called once from the single
/// `integration_test/app_test.dart` entry point, matching every other flow
/// in this bundle.
void registerProgressPlaybackTests() {
  testWidgets(
    'record milestone -> view then-vs-now playback on PROGRESO (U18b, '
    'runtime harness)',
    (tester) async {
      await runProgressPlaybackFlow(tester);
    },
  );
}

/// A user with a diagnosis baseline (stored audio) and one weekly milestone
/// (stored audio) opens PROGRESO directly: the then-vs-now pair renders and
/// "Escuchar antes" plays through the (fake) player end to end.
Future<void> runProgressPlaybackFlow(WidgetTester tester) async {
  final fakePlayer = FakeSpeechPlayer();
  final harness = AppHarness(
    signedInAs: _ana,
    access: _trialing,
    overrides: [
      speechPlayerFactoryProvider.overrideWithValue(() => fakePlayer),
    ],
  );

  await harness.pumpApp(
    tester,
    initialLocation: AppRoutes.progress,
    arrange: (harness) async {
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
      await harness.speakingAttempts.insert(
        SpeakingAttempt(
          id: 'baseline-1',
          sessionId: 'baseline',
          context: TrainingContext.diagnosis,
          kind: AttemptKind.first,
          localDate: LocalDate(2026, 8, 1),
          transcript: 'Respuesta de la evaluación inicial.',
          duration: const Duration(seconds: 20),
          metrics: _metrics,
          audio: const AudioRetention.stored(
            path: 'u1/baseline-1.wav',
            mime: 'audio/wav',
          ),
          observations: const [
            Observation(
              code: BehaviorCode.mainPointLate,
              source: ObservationSource.ai,
            ),
            Observation(
              code: BehaviorCode.mainPointLate,
              source: ObservationSource.ai,
            ),
          ],
        ),
      );
      await harness.speakingAttempts.insert(
        SpeakingAttempt(
          id: 'milestone-1',
          sessionId: 'daily-1',
          context: TrainingContext.daily,
          kind: AttemptKind.first,
          localDate: LocalDate(2026, 9, 7),
          transcript: 'Hablé sobre mi semana en el trabajo.',
          duration: const Duration(seconds: 25),
          metrics: _metrics,
          audio: const AudioRetention.stored(
            path: 'u1/milestone-1.wav',
            mime: 'audio/wav',
          ),
          milestoneWeek: LocalDate(2026, 9, 7),
        ),
      );
      final audioStore = harness.container.read(
        attemptAudioStoreProvider,
      ) as FakeAttemptAudioStore;
      await audioStore.upload(
        attemptId: 'baseline-1',
        bytes: Uint8List.fromList([1, 2, 3]),
        mimeType: 'audio/wav',
      );
      await audioStore.upload(
        attemptId: 'milestone-1',
        bytes: Uint8List.fromList([4, 5, 6]),
        mimeType: 'audio/wav',
      );
    },
  );

  expect(find.text('TU EVOLUCIÓN'), findsOneWidget);
  expect(find.text('Escuchar antes'), findsOneWidget);
  expect(find.text('Escuchar ahora'), findsOneWidget);

  await tester.tap(find.text('Escuchar antes'));
  await tester.pump();
  await tester.pump();
  expect(find.text('Detener'), findsOneWidget);

  fakePlayer.completeNow();
  await tester.pump();
}
