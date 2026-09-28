import 'dart:io';

import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/l10n/gen/app_localizations.dart';
import 'package:flui/core/mic/mic_providers.dart';
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
import 'package:flui/features/training/domain/training_context.dart';
import 'package:flui/features/training/domain/training_mode.dart';
import 'package:flui/features/training/presentation/providers/training_providers.dart';
import 'package:flui/features/training/presentation/training_lab_page.dart';
import 'package:flui/features/training/presentation/widgets/training_loop_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../helpers/pump_router.dart';

Challenge _challenge({
  required String id,
  required TrainingMode mode,
  required int sortOrder,
}) => Challenge(
  id: id,
  slug: 'mode-${mode.name}-$sortOrder',
  purpose: ChallengePurpose.training,
  skill: Skill.thinking,
  mode: mode,
  difficulty: 1,
  prompt: 'Prompt $id',
  focus: 'Focus $id',
  focusBehaviors: const <BehaviorCode>[],
  transferPrompts: ['Transfer $id'],
  targetDuration: const Duration(seconds: 30),
  sortOrder: sortOrder,
);

extension _PumpWithContainer on WidgetTester {
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
  group('TrainingLabPage — 4 mode cards, no page-owned mic logic', () {
    testWidgets('renders every training mode and navigates to its route', (
      tester,
    ) async {
      await pumpRoutedPage(
        tester,
        location: AppRoutes.train,
        page: const TrainingLabPage(),
        otherRoutes: [
          for (final mode in TrainingMode.values) AppRoutes.trainMode(mode),
        ],
      );

      expect(find.text('Piensa y habla'), findsOneWidget);
      expect(find.text('Habla con precisión'), findsOneWidget);
      expect(find.text('Domina tu voz'), findsOneWidget);
      expect(find.text('Situaciones reales'), findsOneWidget);

      await tester.tap(find.text('Habla con precisión'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'route:${AppRoutes.trainMode(TrainingMode.speakWithPrecision)}',
        ),
        findsOneWidget,
      );
    });

    test('page source has no permission/hold-timer/race logic and registers '
        'no lab-specific fallback mic target of its own', () {
      final source = File(
        'lib/features/training/presentation/training_lab_page.dart',
      ).readAsStringSync();

      for (final forbidden in [
        'HoldToRecord',
        'requestPermission',
        'Timer(',
        'MicTargetRegistry',
        'MicTarget ',
        '.register(',
        'ExplainedFallbackTarget',
      ]) {
        expect(
          source.contains(forbidden),
          isFalse,
          reason:
              'training_lab_page.dart unexpectedly references '
              '"$forbidden" — the page must own no mic/permission/timer '
              'logic and register no lab-specific fallback target '
              '(decision #450.3, U16 acceptance).',
        );
      }
    });
  });

  group('TrainingLabModePage — starts the shared loop with context=lab', () {
    late ProviderContainer container;

    Future<void> buildContainer(List<Challenge> challenges) async {
      final consent = FakeAudioConsentRepository(currentUserId: () => 'u1');
      await consent.write(granted: true);
      container = ProviderContainer(
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
          micControllerProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);
    }

    testWidgets(
      'picks the lowest-sortOrder published challenge for the mode and '
      'hands off to TrainingLoopView with context=lab',
      (tester) async {
        await buildContainer([
          _challenge(
            id: 'high',
            mode: TrainingMode.masterYourVoice,
            sortOrder: 5,
          ),
          _challenge(
            id: 'low',
            mode: TrainingMode.masterYourVoice,
            sortOrder: 1,
          ),
          _challenge(
            id: 'other-mode',
            mode: TrainingMode.thinkAndSpeak,
            sortOrder: 0,
          ),
        ]);

        await tester.pumpWithContainer(
          const TrainingLabModePage(mode: TrainingMode.masterYourVoice),
          container,
        );
        await tester.pump();
        await tester.pump();

        final view = tester.widget<TrainingLoopView>(
          find.byType(TrainingLoopView),
        );
        expect(view.request.context, TrainingContext.lab);
        expect(view.request.challengeId, 'low');
      },
    );

    testWidgets('shows an unavailable message for an empty catalog', (
      tester,
    ) async {
      await buildContainer(const []);

      await tester.pumpWithContainer(
        const TrainingLabModePage(mode: TrainingMode.realSituations),
        container,
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(TrainingLoopView), findsNothing);
      expect(find.text('Sin retos disponibles'), findsOneWidget);
    });
  });
}
