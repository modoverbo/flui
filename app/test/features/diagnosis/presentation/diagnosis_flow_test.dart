import 'dart:typed_data';

import 'package:flui/app/router/app_router.dart';
import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/audio/audio_providers.dart';
import 'package:flui/core/audio/speech_recorder.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/mic/mic_providers.dart';
import 'package:flui/core/mic/presentation/mic_button.dart';
import 'package:flui/features/auth/domain/app_user.dart';
import 'package:flui/features/daily/presentation/providers/daily_providers.dart';
import 'package:flui/features/diagnosis/data/fake_skill_profile_repository.dart';
import 'package:flui/features/diagnosis/domain/skill_profile_repository.dart';
import 'package:flui/features/diagnosis/presentation/diagnosis_result_page.dart';
import 'package:flui/features/diagnosis/presentation/providers/diagnosis_providers.dart';
import 'package:flui/features/speaking/data/fake_speech_analysis_repository.dart';
import 'package:flui/features/speaking/presentation/providers/speaking_providers.dart';
import 'package:flui/features/subscription/domain/access_status.dart';
import 'package:flui/features/training/domain/attempt_kind.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/skill_profile.dart';
import 'package:flui/features/training/domain/speaking_attempt.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:flui/features/training/domain/voice_metrics.dart';
import 'package:flui/features/training/presentation/behavior_code_copy.dart';
import 'package:flui/features/training/presentation/controllers/loop_mic_target.dart';
import 'package:flui/shared/widgets/empty_state.dart';
import 'package:flui/shared/widgets/flui_button.dart';
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
  // A duration long enough that VoiceMetricsCalculator's words-per-minute
  // reading (now wired into every attempt's observations, see
  // MeasuredObservations) lands in the steady 100-170 wpm band for this
  // fixture's ~20-word transcripts — 700ms would compute a physically
  // impossible ~1000+ wpm, which is a recorder-fake artifact, not a real
  // measured signal.
  harness.clock.advance(const Duration(seconds: 9));
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
        // Top area: this fixture's odd-numbered attempts' transcript is
        // filler-dense ("eh", "pues", "o sea"), so `filler_heavy` (measured,
        // never AI-judged) is the real top opportunity across 2 of 3
        // attempts — rendered as its own behavior sentence, not the bare
        // area label.
        expect(find.text(l10nEs.behaviorFillerHeavy), findsOneWidget);
        // Second area: the fake AI analyzer never reports a thinking/
        // language observation, so thinking wins the tie-break with a null
        // behavior (honest gap) and falls back to its bare area label.
        expect(find.text(l10nEs.diagnosisAreaThinking), findsOneWidget);
        // Strength: every attempt's pace measured steady, surfaced as the
        // one strength outside the top/second areas.
        expect(find.text(l10nEs.behaviorSteadyPace), findsOneWidget);

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

  group('Diagnosis mic notices (real path)', () {
    testWidgets(
      'a take released too early surfaces the mic notice on the live page '
      '(/diagnosis/live sits outside the shell, so it hosts its own '
      'MicNoticeHost) and never advances the slot',
      (tester) async {
        final recorder = _FakeSpeechRecorder();
        final harness = AppHarness(
          signedInAs: _ana,
          access: _trialing,
          overrides: [
            speechRecorderFactoryProvider.overrideWithValue(() => recorder),
          ],
        );
        await harness.pumpApp(
          tester,
          initialLocation: AppRoutes.diagnosisLive,
          arrange: (h) => h.planToday(),
        );

        // Tap to start, tap to stop with the clock frozen: below the mic's
        // minimum take length.
        for (var tap = 0; tap < 2; tap++) {
          final gesture = await tester.startGesture(
            tester.getCenter(find.byType(MicButton)),
          );
          for (var i = 0; i < 3; i++) {
            await tester.pump();
          }
          await gesture.up();
          for (var i = 0; i < 3; i++) {
            await tester.pump();
          }
        }
        // Not `pumpAndSettle`: it would outlast the snackbar's own timer.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.textContaining('Fue muy corto y no lo enviamos'),
          findsOneWidget,
        );
        expect(_location(harness), AppRoutes.diagnosisLive);
        expect(
          find.text(l10nEs.diagnosisSlotLabel(1, 3).toUpperCase()),
          findsOneWidget,
        );
      },
    );
  });

  group('Diagnosis pause/resume (U14c, real path)', () {
    testWidgets(
      'pausing after slot 1 lands on the intro with resume copy, the gate '
      'still requires diagnosis without trapping the user in a redirect '
      'loop, and resuming continues the SAME session at slot 2 so the '
      "final profile uses exactly the current run's 3 attempts",
      (tester) async {
        final recorder = _FakeSpeechRecorder();
        final harness = AppHarness(
          signedInAs: _ana,
          access: _trialing,
          overrides: [
            speechRecorderFactoryProvider.overrideWithValue(() => recorder),
          ],
        );
        await harness.pumpApp(
          tester,
          initialLocation: AppRoutes.diagnosisLive,
          arrange: (h) => h.planToday(),
        );

        // Slot 1: while a capture is in flight, "Continuar después" must be
        // disabled — a take mid-capture must never be lost (D39).
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(MicButton)),
        );
        for (var i = 0; i < 3; i++) {
          await tester.pump();
        }
        final pauseButtonDuringCapture = tester.widget<FluiButton>(
          find.ancestor(
            of: find.text(l10nEs.diagnosisPauseAction),
            matching: find.byType(FluiButton),
          ),
        );
        expect(pauseButtonDuringCapture.onPressed, isNull);
        harness.clock.advance(const Duration(milliseconds: 700));
        await gesture.up();
        await tester.pumpAndSettle();

        // Now idle on slot 2's focus phase: "Continuar después" is enabled.
        expect(
          find.text(l10nEs.diagnosisSlotLabel(2, 3).toUpperCase()),
          findsOneWidget,
        );
        await tester.tap(find.text(l10nEs.diagnosisPauseAction));
        await tester.pumpAndSettle();

        expect(_location(harness), AppRoutes.diagnosis);
        expect(
          find.text(l10nEs.diagnosisIntroResumeProgress(1, 3)),
          findsOneWidget,
        );
        expect(find.text(l10nEs.diagnosisIntroContinue), findsOneWidget);
        expect(find.text(l10nEs.diagnosisIntroStart), findsNothing);

        // The gate keeps blocking every other path — no redirect loop that
        // traps the user, just an honest bounce back to the intro.
        harness.container.read(goRouterProvider).go(AppRoutes.today);
        await tester.pumpAndSettle();
        expect(_location(harness), AppRoutes.diagnosis);

        // Resuming continues at slot 2, on the SAME session as slot 1.
        await tester.ensureVisible(find.text(l10nEs.diagnosisIntroContinue));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10nEs.diagnosisIntroContinue));
        await tester.pumpAndSettle();
        expect(_location(harness), AppRoutes.diagnosisLive);
        expect(
          find.text(l10nEs.diagnosisSlotLabel(2, 3).toUpperCase()),
          findsOneWidget,
        );

        await _recordOneSlot(tester, harness);
        await _recordOneSlot(tester, harness);

        expect(_location(harness), AppRoutes.diagnosisResult);
        final diagnosisAttempts = harness
            .speakingAttempts
            .attemptsForCurrentUser
            .where((a) => a.context == TrainingContext.diagnosis)
            .toList();
        // Exactly 3 rows total, all sharing one session id — pause/resume
        // never fragments the run across 2 sessions (D38).
        expect(diagnosisAttempts, hasLength(3));
        expect(diagnosisAttempts.map((a) => a.sessionId).toSet(), hasLength(1));
      },
    );
  });

  group('Diagnosis stale rows and retake (U14c, real path)', () {
    testWidgets("a closed baseline's rows never leak into a later retake's "
        'profile — the retake starts fresh at slot 1 and the finished '
        "profile is computed from exactly the retake's own 3 attempts", (
      tester,
    ) async {
      final recorder = _FakeSpeechRecorder();
      const baselineSessionId = 'baseline-session';
      final harness = AppHarness(
        signedInAs: _ana,
        access: _trialing,
        overrides: [
          speechRecorderFactoryProvider.overrideWithValue(() => recorder),
        ],
      );
      // Seeds a CLOSED baseline (3 stale rows + a matching profile) before
      // the widget tree ever mounts — the gate is `completed` from the
      // start, exactly like a real user who diagnosed long ago.
      await harness.pumpApp(
        tester,
        arrange: (h) async {
          await h.planToday();
          final challenges = await h.container.read(
            diagnosisChallengesProvider.future,
          );
          for (final challenge in challenges) {
            await h.speakingAttempts.insert(
              SpeakingAttempt(
                id: 'baseline-${challenge.id}',
                sessionId: baselineSessionId,
                context: TrainingContext.diagnosis,
                kind: AttemptKind.first,
                localDate: LocalDate.fromDateTime(h.clock.now()),
                transcript: 'Respuesta de la evaluación inicial.',
                duration: const Duration(seconds: 20),
                metrics: const VoiceMetrics(
                  longPauses: 0,
                  usefulPauses: 0,
                  fillerCount: 0,
                ),
                audio: const AudioRetention.none(),
                challengeId: challenge.id,
              ),
            );
          }
          h.skillProfiles.seedProfile(
            SkillProfileRecord(
              id: baselineSessionId,
              kind: SkillProfileKind.baseline,
              // `FakeSkillProfileRepository`'s retake cooldown is measured
              // against real wall-clock time (`DateTime.now`), not the
              // harness's `FixedClock` — seeded 31 real days in the past so
              // the retake below is never rejected as too-soon.
              diagnosedAt: DateTime.now().subtract(const Duration(days: 31)),
              profile: const SkillProfile(
                topArea: SkillArea.thinking,
                secondArea: SkillArea.language,
                strengths: <BehaviorCode>[],
                evidence: <DiagnosisEvidence>[],
              ),
            ),
          );
        },
      );

      // The gate is already `completed` — the diagnosis routes are simply
      // unreachable via redirect; a direct visit stays on the intro.
      harness.container.read(goRouterProvider).go(AppRoutes.diagnosis);
      await tester.pumpAndSettle();
      expect(_location(harness), AppRoutes.diagnosis);
      expect(find.text(l10nEs.diagnosisIntroStart), findsOneWidget);
      expect(find.text(l10nEs.diagnosisIntroContinue), findsNothing);

      await tester.ensureVisible(find.text(l10nEs.diagnosisIntroStart));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10nEs.diagnosisIntroStart));
      await tester.pumpAndSettle();
      expect(
        find.text(l10nEs.diagnosisSlotLabel(1, 3).toUpperCase()),
        findsOneWidget,
      );
      for (var slot = 1; slot <= 3; slot++) {
        await _recordOneSlot(tester, harness);
      }
      expect(_location(harness), AppRoutes.diagnosisResult);

      // The retake closed with its OWN session, never the baseline's —
      // and `latestDiagnosisAttempts()` (feeding the profile) returns
      // exactly the retake's 3 rows, never the baseline's stale ones.
      final all = harness.speakingAttempts.attemptsForCurrentUser.toList();
      expect(all, hasLength(6));
      final retakeRows =
          (await harness.speakingAttempts.latestDiagnosisAttempts())
              .valueOrNull!;
      expect(retakeRows, hasLength(3));
      expect(
        retakeRows.map((a) => a.sessionId).toSet(),
        isNot(contains(baselineSessionId)),
      );
    });
  });

  group('PROGRESO paused-retake entry (U14c, real path)', () {
    testWidgets(
      'tapping "Continuar reevaluación" resumes the SAME paused retake at '
      'its next unanswered slot',
      (tester) async {
        final recorder = _FakeSpeechRecorder();
        const baselineSessionId = 'baseline-session';
        const retakeSessionId = 'retake-session';
        final harness = AppHarness(
          signedInAs: _ana,
          access: _trialing,
          overrides: [
            speechRecorderFactoryProvider.overrideWithValue(() => recorder),
          ],
        );
        // A closed baseline PLUS a retake already paused after slot 1 —
        // the gate is `completed` (baseline closed it), so PROGRESO is
        // directly reachable without the mandatory-diagnosis redirect.
        await harness.pumpApp(
          tester,
          arrange: (h) async {
            await h.planToday();
            final challenges = await h.container.read(
              diagnosisChallengesProvider.future,
            );
            for (final challenge in challenges) {
              await h.speakingAttempts.insert(
                SpeakingAttempt(
                  id: 'baseline-${challenge.id}',
                  sessionId: baselineSessionId,
                  context: TrainingContext.diagnosis,
                  kind: AttemptKind.first,
                  localDate: LocalDate.fromDateTime(h.clock.now()),
                  transcript: 'Respuesta de la evaluación inicial.',
                  duration: const Duration(seconds: 20),
                  metrics: const VoiceMetrics(
                    longPauses: 0,
                    usefulPauses: 0,
                    fillerCount: 0,
                  ),
                  audio: const AudioRetention.none(),
                  challengeId: challenge.id,
                ),
              );
            }
            h.skillProfiles.seedProfile(
              SkillProfileRecord(
                id: baselineSessionId,
                kind: SkillProfileKind.baseline,
                diagnosedAt: DateTime.now().subtract(const Duration(days: 31)),
                profile: const SkillProfile(
                  topArea: SkillArea.thinking,
                  secondArea: SkillArea.language,
                  strengths: <BehaviorCode>[],
                  evidence: <DiagnosisEvidence>[],
                ),
              ),
            );
            // The retake was started and paused right after slot 1.
            await h.speakingAttempts.insert(
              SpeakingAttempt(
                id: 'retake-slot1',
                sessionId: retakeSessionId,
                context: TrainingContext.diagnosis,
                kind: AttemptKind.first,
                localDate: LocalDate.fromDateTime(h.clock.now()),
                transcript: 'Respuesta de la reevaluación, paso 1.',
                duration: const Duration(seconds: 20),
                metrics: const VoiceMetrics(
                  longPauses: 0,
                  usefulPauses: 0,
                  fillerCount: 0,
                ),
                audio: const AudioRetention.none(),
                challengeId: challenges.first.id,
              ),
            );
          },
          initialLocation: AppRoutes.progress,
        );

        expect(_location(harness), AppRoutes.progress);
        expect(find.text(l10nEs.progressDiagnosisResumeAction), findsOneWidget);

        await tester.ensureVisible(
          find.text(l10nEs.progressDiagnosisResumeAction),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10nEs.progressDiagnosisResumeAction));
        await tester.pumpAndSettle();

        expect(_location(harness), '${AppRoutes.diagnosisLive}?retake=1');
        expect(
          find.text(l10nEs.diagnosisSlotLabel(2, 3).toUpperCase()),
          findsOneWidget,
        );

        await _recordOneSlot(tester, harness);
        await _recordOneSlot(tester, harness);

        expect(_location(harness), AppRoutes.diagnosisResult);
        final retakeRows =
            (await harness.speakingAttempts.latestDiagnosisAttempts())
                .valueOrNull!;
        expect(retakeRows, hasLength(3));
        expect(retakeRows.map((a) => a.sessionId).toSet(), {retakeSessionId});
      },
    );
  });

  group('Diagnosis profile save failure never traps the user '
      '(fix/diagnosis-profile-save)', () {
    testWidgets('resuming a session with all 3 slots answered but no saved '
        'profile: a failed save leaves "Continuar después" usable, and '
        're-entering retries the save, which succeeds once the backend '
        'accepts it', (tester) async {
      const sessionId = 'stuck-session';
      final harness = AppHarness(signedInAs: _ana, access: _trialing);
      await harness.pumpApp(
        tester,
        initialLocation: AppRoutes.diagnosisLive,
        arrange: (h) async {
          await h.planToday();
          final challenges = await h.container.read(
            diagnosisChallengesProvider.future,
          );
          for (final challenge in challenges) {
            await h.speakingAttempts.insert(
              SpeakingAttempt(
                id: 'stuck-${challenge.id}',
                sessionId: sessionId,
                context: TrainingContext.diagnosis,
                kind: AttemptKind.first,
                localDate: LocalDate.fromDateTime(h.clock.now()),
                transcript: 'Respuesta de la evaluación.',
                duration: const Duration(seconds: 20),
                metrics: const VoiceMetrics(
                  longPauses: 0,
                  usefulPauses: 0,
                  fillerCount: 0,
                ),
                audio: const AudioRetention.none(),
                challengeId: challenge.id,
              ),
            );
          }
          // Mirrors the production bug: every attempt to save the
          // computed profile fails the same way (there, a real DB
          // constraint on an all-opportunity profile; here, any
          // failure the repository returns) until the test flips it
          // back off, simulating the DB accepting it on a later try.
          h.skillProfiles.failSaves = true;
        },
      );

      expect(find.text(l10nEs.diagnosisSaveFailedMessage), findsOneWidget);
      await tester.ensureVisible(find.text(l10nEs.diagnosisPauseAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10nEs.diagnosisPauseAction));
      await tester.pumpAndSettle();

      expect(_location(harness), AppRoutes.diagnosis);
      expect(find.text(l10nEs.diagnosisIntroContinue), findsOneWidget);

      // The backend now accepts the save — re-entering retries it
      // automatically (D38) and this time it succeeds.
      harness.skillProfiles.failSaves = false;
      await tester.ensureVisible(find.text(l10nEs.diagnosisIntroContinue));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10nEs.diagnosisIntroContinue));
      await tester.pumpAndSettle();

      expect(_location(harness), AppRoutes.diagnosisResult);
    });

    testWidgets('a failed save at the end of the live loop leaves "Continuar '
        'después" usable again once nothing is in flight, and retrying '
        'succeeds', (tester) async {
      final recorder = _FakeSpeechRecorder();
      final harness = AppHarness(
        signedInAs: _ana,
        access: _trialing,
        overrides: [
          speechRecorderFactoryProvider.overrideWithValue(() => recorder),
        ],
      );
      await harness.pumpApp(
        tester,
        initialLocation: AppRoutes.diagnosisLive,
        arrange: (h) => h.planToday(),
      );

      await _recordOneSlot(tester, harness);
      await _recordOneSlot(tester, harness);
      harness.skillProfiles.failSaves = true;
      await _recordOneSlot(tester, harness);

      // Still on the live screen (the save failed), but never
      // trapped: pausing is enabled again now that the failed save
      // stopped, and retrying is offered.
      expect(_location(harness), AppRoutes.diagnosisLive);
      expect(find.text(l10nEs.diagnosisSaveFailedMessage), findsOneWidget);
      final pauseButton = tester.widget<FluiButton>(
        find.ancestor(
          of: find.text(l10nEs.diagnosisPauseAction),
          matching: find.byType(FluiButton),
        ),
      );
      expect(pauseButton.onPressed, isNotNull);

      // The backend now accepts the save — retrying succeeds.
      harness.skillProfiles.failSaves = false;
      await tester.tap(find.text(l10nEs.diagnosisRetryAction));
      await tester.pumpAndSettle();

      expect(_location(harness), AppRoutes.diagnosisResult);
    });
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

    testWidgets('renders the honest gaps of an all-opportunity diagnosis '
        '(fix/diagnosis-profile-save): a null second behavior falls back to '
        'the area label, and an empty strengths list renders no strengths '
        'section at all — never a crash, never a fabricated line', (
      tester,
    ) async {
      final repository = FakeSkillProfileRepository(currentUserId: () => 'u1')
        ..seedProfile(
          SkillProfileRecord(
            id: 's1',
            kind: SkillProfileKind.baseline,
            diagnosedAt: DateTime(2026, 9, 14),
            profile: const SkillProfile(
              topArea: SkillArea.thinking,
              secondArea: SkillArea.voice,
              topBehavior: BehaviorCode.noClearStructure,
              strengths: [],
              evidence: [],
            ),
          ),
        );
      await tester.pumpFlui(
        const DiagnosisResultPage(),
        overrides: [
          currentUserIdProvider.overrideWithValue('u1'),
          skillProfileRepositoryProvider.overrideWithValue(repository),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text(l10nEs.diagnosisResultTitle), findsOneWidget);
      // The top behavior renders as usual; the second area has no
      // behavior at all (zero opportunities anywhere), so it falls back
      // to the plain area label instead of fabricating one.
      expect(
        find.text(behaviorCodeLine(l10nEs, BehaviorCode.noClearStructure)),
        findsOneWidget,
      );
      expect(find.text(skillAreaLine(l10nEs, SkillArea.voice)), findsOneWidget);
      // No strengths were observed anywhere: the whole section is
      // omitted, never rendered empty or fabricated.
      expect(find.text(l10nEs.diagnosisResultStrengthsLabel), findsNothing);
    });
  });
}
