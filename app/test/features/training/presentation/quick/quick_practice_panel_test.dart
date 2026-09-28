import 'dart:typed_data';

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/l10n/gen/app_localizations.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/core/theme/flui_theme.dart';
import 'package:flui/features/speaking/data/fake_speech_analysis_repository.dart';
import 'package:flui/features/speaking/presentation/providers/speaking_providers.dart';
import 'package:flui/features/training/data/fake_attempt_audio_store.dart';
import 'package:flui/features/training/data/fake_audio_consent_repository.dart';
import 'package:flui/features/training/data/fake_challenge_repository.dart';
import 'package:flui/features/training/data/fake_speaking_attempt_repository.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/challenge.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/presentation/controllers/training_loop_controller.dart';
import 'package:flui/features/training/presentation/providers/training_providers.dart';
import 'package:flui/features/training/presentation/quick/quick_practice_panel.dart';
import 'package:flui/features/training/presentation/quick/quick_practice_target.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _challenge = Challenge(
  id: 'c1',
  slug: 'organize-morning',
  purpose: ChallengePurpose.training,
  skill: Skill.thinking,
  difficulty: 1,
  prompt: 'Cuenta cómo organizas tu mañana.',
  cue: 'Piensa en tu primera hora del día.',
  focus: 'Estructura tu respuesta.',
  focusBehaviors: <BehaviorCode>[],
  transferPrompts: <String>['Aplica esto mañana.'],
  targetDuration: Duration(seconds: 20),
  sortOrder: 1,
);

RecordedAudio _audio() => RecordedAudio(
  bytes: Uint8List.fromList(List<int>.filled(10, 1)),
  mimeType: 'audio/wav',
  duration: const Duration(seconds: 12),
  levelsDbfs: const [-30, -28],
);

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('es'));

extension _PumpQuickPractice on WidgetTester {
  Future<void> pumpWithContainer(
    Widget child,
    ProviderContainer container,
  ) async {
    await pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: FluiTheme.light(),
          locale: const Locale('es'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Scaffold(body: child),
        ),
      ),
    );
    await pump();
  }
}

void main() {
  late ProviderContainer container;

  ProviderContainer build({List<Challenge> challenges = const [_challenge]}) {
    final consent = FakeAudioConsentRepository(currentUserId: () => 'u1');
    return ProviderContainer(
      overrides: [
        speechAnalysisRepositoryProvider.overrideWithValue(
          FakeSpeechAnalysisRepository(latency: Duration.zero),
        ),
        speakingAttemptRepositoryProvider.overrideWithValue(
          FakeSpeakingAttemptRepository(currentUserId: () => 'u1'),
        ),
        attemptAudioStoreProvider.overrideWithValue(
          FakeAttemptAudioStore(currentUserId: () => 'u1'),
        ),
        audioConsentRepositoryProvider.overrideWithValue(consent),
        challengeRepositoryProvider.overrideWithValue(
          FakeChallengeRepository(challenges: challenges),
        ),
        clockProvider.overrideWithValue(FixedClock(DateTime(2026, 9, 28))),
      ],
    );
  }

  setUp(() async {
    container = build();
    addTearDown(container.dispose);
    final consent = container.read(audioConsentRepositoryProvider);
    await consent.write(granted: true);
  });

  testWidgets('shows the prompt/cue during the think phase, no recording UI', (
    tester,
  ) async {
    final target = container.read(quickPracticeTargetProvider);
    await (target.availability as MicPrepare).onActivate();

    await tester.pumpWithContainer(
      QuickPracticePanel(
        request: target.currentRequest!,
        challenge: target.currentChallenge,
      ),
      container,
    );

    expect(find.text(_l10n.quickPracticeThinkingHeadline), findsOneWidget);
    expect(find.text(_challenge.prompt), findsOneWidget);
    expect(find.text(_challenge.cue!), findsOneWidget);
  });

  testWidgets('shows the ready hint after the think timer elapses', (
    tester,
  ) async {
    final target = container.read(quickPracticeTargetProvider);
    await (target.availability as MicPrepare).onActivate();

    await tester.pumpWithContainer(
      QuickPracticePanel(
        request: target.currentRequest!,
        challenge: target.currentChallenge,
      ),
      container,
    );
    await tester.pump(const Duration(seconds: 6));

    expect(find.text(_l10n.quickPracticeThinkingHeadline), findsNothing);
    expect(find.text(_l10n.quickPracticeReadyHint), findsOneWidget);
  });

  testWidgets('shows feedback once the loop reaches feedback phase', (
    tester,
  ) async {
    final target = container.read(quickPracticeTargetProvider);
    await (target.availability as MicPrepare).onActivate();
    final request = target.currentRequest!;

    await tester.pumpWithContainer(
      QuickPracticePanel(request: request, challenge: target.currentChallenge),
      container,
    );
    await container
        .read(trainingLoopControllerProvider(request).notifier)
        .submit(_audio());
    await tester.pump();

    expect(find.text(_l10n.quickPracticeFeedbackHeadline), findsOneWidget);
  });

  testWidgets('shows summary once the loop reaches summary phase', (
    tester,
  ) async {
    final target = container.read(quickPracticeTargetProvider);
    await (target.availability as MicPrepare).onActivate();
    final request = target.currentRequest!;

    await tester.pumpWithContainer(
      QuickPracticePanel(request: request, challenge: target.currentChallenge),
      container,
    );
    await container
        .read(trainingLoopControllerProvider(request).notifier)
        .submit(_audio());
    await tester.pump();
    expect(find.text(_l10n.quickPracticeFeedbackHeadline), findsOneWidget);

    await tester.tap(find.text(_l10n.loopContinueAction));
    await tester.pump();

    expect(find.text(_l10n.quickPracticeSummaryTitle), findsOneWidget);
  });

  testWidgets('shows the no-challenge message when challenge is null', (
    tester,
  ) async {
    final empty = build(challenges: const []);
    addTearDown(empty.dispose);
    await empty.read(audioConsentRepositoryProvider).write(granted: true);
    final target = empty.read(quickPracticeTargetProvider);
    await (target.availability as MicPrepare).onActivate();

    await tester.pumpWithContainer(
      QuickPracticePanel(
        request: target.currentRequest!,
        challenge: target.currentChallenge,
      ),
      empty,
    );

    expect(find.text(_l10n.quickPracticeNoChallengeMessage), findsOneWidget);
  });

  testWidgets('Cerrar dismisses the target — request cleared', (tester) async {
    final target = container.read(quickPracticeTargetProvider);
    await (target.availability as MicPrepare).onActivate();

    await tester.pumpWithContainer(
      QuickPracticePanel(
        request: target.currentRequest!,
        challenge: target.currentChallenge,
      ),
      container,
    );
    await tester.tap(find.text(_l10n.quickPracticeCloseAction));
    await tester.pump();

    expect(target.currentRequest, isNull);
  });
}
