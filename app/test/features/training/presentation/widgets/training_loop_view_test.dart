import 'dart:async';
import 'dart:typed_data';

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/audio/speech_recorder.dart';
import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/core/l10n/gen/app_localizations.dart';
import 'package:flui/core/mic/mic_controller.dart';
import 'package:flui/core/mic/mic_providers.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/core/mic/mic_target_registry.dart';
import 'package:flui/core/theme/flui_theme.dart';
import 'package:flui/core/theme/flui_type_scale.dart';
import 'package:flui/features/speaking/data/fake_speech_analysis_repository.dart';
import 'package:flui/features/speaking/presentation/providers/speaking_providers.dart';
import 'package:flui/features/training/data/fake_attempt_audio_store.dart';
import 'package:flui/features/training/data/fake_audio_consent_repository.dart';
import 'package:flui/features/training/data/fake_challenge_repository.dart';
import 'package:flui/features/training/data/fake_speaking_attempt_repository.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/challenge.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/speaking_attempt.dart';
import 'package:flui/features/training/domain/speaking_attempt_repository.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:flui/features/training/domain/training_loop.dart';
import 'package:flui/features/training/presentation/controllers/training_loop_controller.dart';
import 'package:flui/features/training/presentation/providers/training_providers.dart';
import 'package:flui/features/training/presentation/widgets/training_loop_view.dart';
import 'package:flui/shared/widgets/audio_reactive_bubble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// A ready-to-record [MicTarget] test double, used only by the isolated
/// [MicController] the permission-denied test builds — unrelated to this
/// view's own `LoopMicTarget` registration.
final class _FakeMicTarget implements MicTarget {
  const new();

  @override
  MicPrompt get prompt => const MicPrompt(actionLabel: 'Grabar');

  @override
  Duration get maxDuration => const Duration(seconds: 30);

  @override
  MicAvailability get availability => const MicReady();

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Future<MicDelivery> deliver(RecordedAudio audio) async => const MicAccepted();
}

final class _FakeSpeechRecorder implements SpeechRecorder {
  new({this.permission = true});

  final bool permission;

  @override
  Stream<double> get amplitude => const Stream.empty();

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<void> start() async {}

  @override
  Future<Uint8List> stop() async => Uint8List.fromList(const [1, 2, 3]);

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}

/// An insert that fails every call until [succeedAfter] more, then
/// succeeds — lets a test drive the "not saved" retryable state and prove
/// `retrySave()` recovers from it (mirrors
/// `training_loop_controller_test.dart`'s own `_FlakyAttemptRepository`).
final class _FlakyAttemptRepository implements SpeakingAttemptRepository {
  new({this.succeedAfter = 0});

  int succeedAfter;
  final inserted = <SpeakingAttempt>[];

  @override
  Future<Result<SpeakingAttempt>> insert(SpeakingAttempt attempt) async {
    if (succeedAfter > 0) {
      succeedAfter--;
      return const Result.err(NetworkFailure());
    }
    inserted.add(attempt);
    return Result.ok(attempt);
  }
}

const _challenge = Challenge(
  id: 'c1',
  slug: 'organize-morning',
  purpose: ChallengePurpose.training,
  skill: Skill.thinking,
  difficulty: 1,
  prompt: 'Cuéntame cómo organizas tu mañana.',
  focus: 'Estructura tu respuesta con apertura y cierre.',
  focusBehaviors: <BehaviorCode>[],
  transferPrompts: <String>['Cuéntame cómo aplicarías esto mañana.'],
  targetDuration: Duration(seconds: 30),
  sortOrder: 1,
);

const _request = LoopRequest(
  context: TrainingContext.daily,
  sessionId: 's1',
  script: LoopScript.full(),
  challengeId: 'c1',
);

RecordedAudio _audio() => RecordedAudio(
  bytes: Uint8List.fromList(List<int>.filled(10, 1)),
  mimeType: 'audio/wav',
  duration: const Duration(seconds: 12),
  levelsDbfs: const [-30, -28, -32],
);

/// The Spanish strings this view renders, read from the real ARB output —
/// assertions never hardcode a duplicate copy of the copy under test.
final AppLocalizations _l10n = lookupAppLocalizations(const Locale('es'));

/// `FluiLabel` renders its text in caps (typography only, per its own
/// doc comment — the ARB copy itself stays sentence case), so a finder for
/// a `FluiLabel`-rendered string must match the rendered caps, exactly
/// like this repo's own `fluiField` helper does for form labels.
Finder fluiLabel(String text) => find.text(FluiTypeScale.labelText(text));

extension _PumpTrainingLoop on WidgetTester {
  /// Pumps [child] against an ALREADY-CONSTRUCTED [container] (not a fresh
  /// one `ProviderScope` would create) so a test can drive the training
  /// loop controller's notifier directly and observe this widget react.
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
  late FakeSpeechAnalysisRepository speech;
  late FakeSpeakingAttemptRepository attempts;
  late FakeAttemptAudioStore audioStore;
  late FakeAudioConsentRepository consent;
  late ProviderContainer container;

  Future<void> buildContainer({
    SpeakingAttemptRepository? attemptRepository,
    MicController? micController,
  }) async {
    speech = FakeSpeechAnalysisRepository(latency: Duration.zero);
    attempts = FakeSpeakingAttemptRepository(currentUserId: () => 'u1');
    audioStore = FakeAttemptAudioStore(currentUserId: () => 'u1');
    consent = FakeAudioConsentRepository(currentUserId: () => 'u1');
    await consent.write(granted: true);

    container = ProviderContainer(
      overrides: [
        speechAnalysisRepositoryProvider.overrideWithValue(speech),
        speakingAttemptRepositoryProvider.overrideWithValue(
          attemptRepository ?? attempts,
        ),
        attemptAudioStoreProvider.overrideWithValue(audioStore),
        audioConsentRepositoryProvider.overrideWithValue(consent),
        challengeRepositoryProvider.overrideWithValue(
          FakeChallengeRepository(challenges: const [_challenge]),
        ),
        clockProvider.overrideWithValue(FixedClock(DateTime(2026, 9, 28))),
        // Every test overrides this directly — the real provider needs a
        // signed-in session/access-gate/recorder-factory graph this widget
        // test never builds (mirrors this repo's other repository-port
        // providers, which likewise throw until overridden).
        micControllerProvider.overrideWithValue(micController),
      ],
    );
    addTearDown(container.dispose);
  }

  TrainingLoopController controller() =>
      container.read(trainingLoopControllerProvider(_request).notifier);

  group('TrainingLoopView — no view-owned record/permission/timer widget', () {
    testWidgets(
      'renders every AudioReactiveBubble with no tap/stop affordance of '
      'its own (only the shell mic drives capture)',
      (tester) async {
        final micController = MicController(
          recorderFactory: _FakeSpeechRecorder.new,
          registry: MicTargetRegistry()
            ..register(const _FakeMicTarget(), layer: MicLayer.branch),
          clock: const SystemClock(),
        )..setAccessGranted(true);
        addTearDown(micController.dispose);
        await buildContainer(micController: micController);
        await tester.pumpWithContainer(
          const TrainingLoopView(request: _request),
          container,
        );

        expect(find.textContaining('Mantén pulsado'), findsNothing);
        final bubbles = tester.widgetList<AudioReactiveBubble>(
          find.byType(AudioReactiveBubble),
        );
        expect(bubbles, isNotEmpty);
        for (final bubble in bubbles) {
          expect(bubble.onTap, isNull);
          expect(bubble.onStop, isNull);
        }
      },
    );
  });

  group('TrainingLoopView — feedback/comparison/summary have no numbers', () {
    testWidgets('feedback, comparison and summary render zero digits', (
      tester,
    ) async {
      await buildContainer();
      await tester.pumpWithContainer(
        const TrainingLoopView(request: _request),
        container,
      );

      await controller().submit(_audio());
      await tester.pump();
      _expectNoDigitsRendered(tester);
      expect(fluiLabel(_l10n.loopFeedbackLabel), findsOneWidget);

      await controller().submit(_audio());
      await tester.pump();
      _expectNoDigitsRendered(tester);
      expect(fluiLabel(_l10n.loopComparisonLabel), findsOneWidget);

      await controller().submit(_audio());
      await tester.pump();
      _expectNoDigitsRendered(tester);
      expect(fluiLabel(_l10n.loopSummaryTitle), findsOneWidget);
    });
  });

  group('TrainingLoopView — accessRequired keeps the prior step visible', () {
    testWidgets('shows the completed feedback content plus a Reactivar CTA', (
      tester,
    ) async {
      await buildContainer();
      await tester.pumpWithContainer(
        const TrainingLoopView(request: _request),
        container,
      );

      await controller().submit(_audio());
      await tester.pump();
      expect(fluiLabel(_l10n.loopFeedbackLabel), findsOneWidget);

      speech.nextFailure = const SpeechAnalysisFailure(
        SpeechAnalysisErrorCode.accessRequired,
      );
      await controller().submit(_audio());
      await tester.pump();

      expect(fluiLabel(_l10n.loopFeedbackLabel), findsOneWidget);
      expect(find.text(_l10n.loopAccessRequiredMessage), findsOneWidget);
      expect(find.text(_l10n.loopReactivateAction), findsOneWidget);
    });
  });

  group('TrainingLoopView — analysisFailed retry hint', () {
    testWidgets('offers Reintentar for an ordinary failure code', (
      tester,
    ) async {
      await buildContainer();
      await tester.pumpWithContainer(
        const TrainingLoopView(request: _request),
        container,
      );

      speech.nextFailure = const SpeechAnalysisFailure(
        SpeechAnalysisErrorCode.rateLimited,
      );
      await controller().submit(_audio());
      await tester.pump();

      expect(find.text(_l10n.loopAnalysisFailedMessage), findsOneWidget);
      expect(find.text(_l10n.loopRetryAction), findsOneWidget);
    });

    testWidgets('offers no retry for dailyLimitReached', (tester) async {
      await buildContainer();
      await tester.pumpWithContainer(
        const TrainingLoopView(request: _request),
        container,
      );

      speech.nextFailure = const SpeechAnalysisFailure(
        SpeechAnalysisErrorCode.dailyLimitReached,
      );
      await controller().submit(_audio());
      await tester.pump();

      expect(find.text(_l10n.loopDailyLimitMessage), findsOneWidget);
      expect(find.text(_l10n.loopRetryAction), findsNothing);
    });

    testWidgets('a not-saved attempt offers Reintentar guardar, never presents '
        'feedback as saved, and retrySave recovers it', (tester) async {
      final flaky = _FlakyAttemptRepository(succeedAfter: 2);
      await buildContainer(attemptRepository: flaky);
      await tester.pumpWithContainer(
        const TrainingLoopView(request: _request),
        container,
      );

      await controller().submit(_audio());
      await tester.pump();

      expect(find.text(_l10n.loopNotSavedMessage), findsOneWidget);
      expect(find.text(_l10n.loopRetrySaveAction), findsOneWidget);
      expect(fluiLabel(_l10n.loopFeedbackLabel), findsNothing);
      expect(flaky.inserted, isEmpty);

      await tester.tap(find.text(_l10n.loopRetrySaveAction));
      await tester.pump();

      expect(flaky.inserted, hasLength(1));
      expect(find.text(_l10n.loopNotSavedMessage), findsNothing);
      expect(fluiLabel(_l10n.loopFeedbackLabel), findsOneWidget);
    });
  });

  group('TrainingLoopView — mic-driven status panel', () {
    testWidgets(
      'a permission-denied latch shows an actionable settings message '
      '(surfaced generically, not by a view-owned button)',
      (tester) async {
        final registry = MicTargetRegistry()
          ..register(const _FakeMicTarget(), layer: MicLayer.branch);
        final micController = MicController(
          recorderFactory: () => _FakeSpeechRecorder(permission: false),
          registry: registry,
          clock: const SystemClock(),
        )..setAccessGranted(true);
        addTearDown(micController.dispose);
        await buildContainer(micController: micController);

        await tester.pumpWithContainer(
          const TrainingLoopView(request: _request),
          container,
        );

        micController.pointerDown();
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Necesitamos acceso al micrófono'),
          findsOneWidget,
        );
        expect(find.text('Intentar de nuevo'), findsOneWidget);
      },
    );
  });
}

/// Scans every rendered [Text] for a numeric confidence/score pattern
/// (spec `training-engine`: "no numeric confidence value or universal/
/// aggregate score anywhere"). Skips the one line sourced from free-form
/// AI coaching copy (`loopRetryCueLabel: ...`): that text is the model's
/// own retry cue, which may legitimately mention a practical number (e.g.
/// "en 10 palabras") without it being a score — this repo's own
/// [FakeSpeechAnalysisRepository] fixture does exactly that.
void _expectNoDigitsRendered(WidgetTester tester) {
  final digitPattern = RegExp('[0-9]|%');
  final retryCuePrefix = '${_l10n.loopRetryCueLabel}:';
  for (final widget in tester.widgetList<Text>(find.byType(Text))) {
    final data = widget.data;
    if (data == null || data.startsWith(retryCuePrefix)) continue;
    expect(
      digitPattern.hasMatch(data),
      isFalse,
      reason: 'Found a numeric/percent character in rendered text: "$data"',
    );
  }
}
