import 'dart:typed_data';

import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/audio/audio_providers.dart';
import 'package:flui/core/audio/speech_recorder.dart';
import 'package:flui/core/config/feature_flags.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/mic/presentation/mic_button.dart';
import 'package:flui/features/auth/domain/app_user.dart';
import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:flui/features/diagnosis/domain/skill_profile_repository.dart';
import 'package:flui/features/subscription/domain/access_status.dart';
import 'package:flui/features/themes/data/fake/seed_themes.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/skill_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/app_harness.dart';

const _ana = AppUser(id: 'u1', email: 'ana@correo.com', displayName: 'Ana');
const _trialing = AccessStatus(
  hasAccess: true,
  entitlementStatus: EntitlementStatus.trialing,
);

/// A controllable fake recorder, ported from `app_router_test.dart`'s own
/// (mirrors `mic_button_test.dart`'s): permission-granted, finishes
/// instantly, no real platform channel.
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

final _seededProfile = SkillProfileRecord(
  id: 'seed-diagnosis',
  kind: SkillProfileKind.baseline,
  diagnosedAt: DateTime(2026, 9),
  profile: const SkillProfile(
    topArea: SkillArea.thinking,
    secondArea: SkillArea.language,
    strengths: <BehaviorCode>[],
    evidence: <DiagnosisEvidence>[],
  ),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Full spoken Úsala flow (design D34-D37, U17b): form recall (mismatch
  /// -> hint, then a matching spoken answer accepts), then production
  /// (a valid spoken sentence reaches the self-check), and a blocked mic
  /// offering "Continuar sin hablar". Zero `speaking_attempts` rows are
  /// ever written (D37 regression guard) and the transcribe call count
  /// matches exactly the number of recordings made (no quota spent on a
  /// resolved/inactive step).
  testWidgets(
    '/session spoken Úsala: mismatch hint, matching accept, production '
    'self-check, blocked skip, zero speaking_attempts rows',
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
      final perspicaz = seedWordsWithThemes.firstWhere(
        (w) => w.lemma == 'perspicaz',
      );

      await harness.pumpApp(
        tester,
        initialLocation: AppRoutes.session,
        arrange: (h) async {
          h.skillProfiles.seedProfile(_seededProfile);
          await h.dailySessions.saveSession(
            DailySession(
              localDate: h.clock.localToday(),
              minutes: 10,
              plannedWordIds: [perspicaz.id],
            ),
          );
        },
      );

      Future<void> tapText(String text) async {
        final finder = find.text(text);
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      Future<void> record() async {
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

      // Descubre -> Mira -> Elige (correct).
      expect(find.text('TU PALABRA DE HOY'), findsOneWidget);
      await tapText('Ver en contexto');
      await tapText('Continuar');
      await tapText('perspicaz');
      await tapText('Confirmar');
      await tapText('Continuar');

      // Form recall: the shell mic is the only affordance now, no field.
      expect(find.text('Ahora dilo tú.'), findsOneWidget);
      expect(find.text('Comprobar'), findsNothing);
      expect(find.byType(MicButton), findsOneWidget);

      // A mismatch shows the next hint, no state persisted.
      harness.speech.nextTranscribeText = 'un gato';
      await record();
      expect(find.text('Tiene 3 sílabas.'), findsOneWidget);
      expect(harness.speech.transcribeCalls, 1);

      // A matching spoken answer accepts and shows the heard text.
      harness.speech.nextTranscribeText = 'perspicaz';
      await record();
      expect(find.text('¡Eso es!'), findsOneWidget);
      expect(find.text('Escuché: «perspicaz»'), findsOneWidget);
      expect(harness.speech.transcribeCalls, 2);
      await tapText('Continuar');

      // Mira again: the scenes held back, then production.
      expect(find.text('Mira cómo suena'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Siguiente'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Siguiente'));
      await tester.pumpAndSettle();
      await tapText('Continuar');

      // Production: a valid spoken sentence reaches the self-check phase.
      expect(find.text('Úsala'), findsOneWidget);
      expect(find.text('Comprobar'), findsNothing);
      harness.speech.nextTranscribeText =
          'Carla hizo una pregunta muy perspicaz en la reunión.';
      await record();
      expect(find.text('¿Suena natural?'), findsOneWidget);
      // The self-check phase (unchanged by U17b) shows the accepted
      // sentence via HighlightedText, not the writing-phase "Escuché:"
      // display — proving the spoken transcript actually reached
      // ProductionFlow.submit and was accepted, not merely recorded.
      expect(
        find.textContaining('Carla hizo una pregunta muy perspicaz'),
        findsOneWidget,
      );
      expect(harness.speech.transcribeCalls, 3);

      // Exactly 3 recordings were made, exactly 3 transcribe calls — and
      // zero `speaking_attempts` rows: word exercises never persist a
      // history row (D37), unlike every other spoken surface in this app.
      expect(harness.speakingAttempts.attemptsForCurrentUser, isEmpty);

      for (final item in [
        'Dice lo que quiero decir',
        'La diría en voz alta sin sonar raro',
        'La palabra encaja, no está forzada',
      ]) {
        await tapText(item);
      }
      await tapText('Sí, suena natural');

      // End-of-session check (typed cloze, unaffected by U17b), then the
      // summary — form_recall_done/production_done both landed via the
      // spoken path.
      await tapText('perspicaz');
      await tapText('Confirmar');
      await tapText('Continuar');
      expect(find.text('Una palabra más en tu repertorio.'), findsOneWidget);
      expect(harness.speakingAttempts.attemptsForCurrentUser, isEmpty);
    },
  );

  /// A blocked mic (daily quota latched) offers "Continuar sin hablar" —
  /// the step resurfaces later rather than being silently skipped, and no
  /// hint/progress is consumed.
  testWidgets(
    '/session spoken Úsala: a blocked mic offers "Continuar sin hablar"',
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
      final perspicaz = seedWordsWithThemes.firstWhere(
        (w) => w.lemma == 'perspicaz',
      );

      await harness.pumpApp(
        tester,
        initialLocation: AppRoutes.session,
        arrange: (h) async {
          h.skillProfiles.seedProfile(_seededProfile);
          await h.dailySessions.saveSession(
            DailySession(
              localDate: h.clock.localToday(),
              minutes: 10,
              plannedWordIds: [perspicaz.id],
            ),
          );
        },
      );

      Future<void> tapText(String text) async {
        final finder = find.text(text);
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tapText('Ver en contexto');
      await tapText('Continuar');
      await tapText('perspicaz');
      await tapText('Confirmar');
      await tapText('Continuar');
      expect(find.text('Ahora dilo tú.'), findsOneWidget);

      // Latches the daily quota block via one rejected recording — the
      // controller's own idle state immediately reflects the latch
      // (`MicIdle(block: _quotaBlock)`), so `SpokenAnswerControls` shows
      // "Continuar sin hablar" without any further mic interaction.
      harness.speech.nextFailure = const SpeechAnalysisFailure(
        SpeechAnalysisErrorCode.dailyLimitReached,
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(MicButton)),
      );
      for (var i = 0; i < 3; i++) {
        await tester.pump();
      }
      harness.clock.advance(const Duration(milliseconds: 700));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('Continuar sin hablar'), findsOneWidget);
      await tapText('Continuar sin hablar');

      // The step resurfaces later: form_recall_done/production_done never
      // persisted, so a fresh session on the same word offers it again.
      expect(find.text('Ahora dilo tú.'), findsNothing);
      expect(harness.speakingAttempts.attemptsForCurrentUser, isEmpty);
    },
  );
}
