import 'dart:async';

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/core/id/id_providers.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/features/speaking/domain/speech_transcript.dart';
import 'package:flui/features/speaking/presentation/providers/speaking_providers.dart';
import 'package:flui/features/training/domain/attempt_comparison.dart';
import 'package:flui/features/training/domain/attempt_kind.dart';
import 'package:flui/features/training/domain/challenge.dart';
import 'package:flui/features/training/domain/feedback.dart';
import 'package:flui/features/training/domain/feedback_composer.dart';
import 'package:flui/features/training/domain/milestone_policy.dart';
import 'package:flui/features/training/domain/observation.dart';
import 'package:flui/features/training/domain/observation_mapper.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/speaking_attempt.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:flui/features/training/domain/training_loop.dart';
import 'package:flui/features/training/domain/voice_metrics.dart';
import 'package:flui/features/training/domain/voice_metrics_calculator.dart';
import 'package:flui/features/training/presentation/providers/training_providers.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'training_loop_controller.g.dart';

/// Everything one training-loop session needs to run, independent of who
/// started it: diagnosis, HOY, ENTRENAR, PALABRAS spoken-use (design §10,
/// §19.9 U13a). Immutable and `const`-constructible so equal requests key
/// the same [TrainingLoopController] family instance.
@immutable
final class LoopRequest {
  const new({
    required this.context,
    required this.sessionId,
    required this.script,
    this.challengeId,
    this.challengeIds = const <String>[],
    this.targetWordIds = const <String>[],
    this.startSlot,
  });

  final TrainingContext context;
  final String sessionId;
  final LoopScript script;

  /// The single challenge answered by every speak step, for every context
  /// except [TrainingContext.diagnosis].
  final String? challengeId;

  /// One challenge id per diagnosis slot (1-indexed via [challengeIdFor]),
  /// used only when [context] is [TrainingContext.diagnosis].
  final List<String> challengeIds;

  final List<String> targetWordIds;

  /// Resumes a paused diagnosis at this slot (U14c, D38); otherwise the
  /// script's own start slot applies.
  final int? startSlot;

  /// The challenge id answering [slot] (diagnosis) or [challengeId]
  /// (everything else). `null` when nothing resolves — a caller error for
  /// diagnosis (missing/out-of-range slot), or simply no challenge attached
  /// for a context that never carries one.
  String? challengeIdFor(int? slot) {
    if (context != TrainingContext.diagnosis) return challengeId;
    if (slot == null || slot < 1 || slot > challengeIds.length) return null;
    return challengeIds[slot - 1];
  }

  @override
  bool operator ==(Object other) =>
      other is LoopRequest &&
      other.context == context &&
      other.sessionId == sessionId &&
      other.script == script &&
      other.challengeId == challengeId &&
      _listEquals(other.challengeIds, challengeIds) &&
      _listEquals(other.targetWordIds, targetWordIds) &&
      other.startSlot == startSlot;

  @override
  int get hashCode => Object.hash(
    context,
    sessionId,
    script,
    challengeId,
    Object.hashAll(challengeIds),
    Object.hashAll(targetWordIds),
    startSlot,
  );
}

bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// What [TrainingLoopController] exposes to its consumers: the loop's own
/// [TrainingLoopState] plus the presentation-facing results a completed
/// speak step produced. [feedback]/[comparison] are sticky — they are never
/// cleared just because the phase moved on, so an `accessRequired` view can
/// still show the previously completed step's feedback (design part-3
/// `ai-cost-gating`: "already-completed steps stay visible/persisted").
@immutable
final class TrainingLoopControllerState {
  const new({required this.loop, this.feedback, this.comparison});

  final TrainingLoopState loop;
  final Feedback? feedback;
  final AttemptComparison? comparison;

  TrainingLoopControllerState _withLoop(TrainingLoopState loop) =>
      TrainingLoopControllerState(
        loop: loop,
        feedback: feedback,
        comparison: comparison,
      );

  TrainingLoopControllerState _withFeedback(Feedback value) =>
      TrainingLoopControllerState(
        loop: loop,
        feedback: value,
        comparison: comparison,
      );

  TrainingLoopControllerState _withComparison(AttemptComparison value) =>
      TrainingLoopControllerState(
        loop: loop,
        feedback: feedback,
        comparison: value,
      );
}

/// Drives one training-loop session (design §10, §19.2, §19.9 U13a).
///
/// Owns NO recording (D23/D25): a screen registers a `LoopMicTarget` wrapping
/// this controller, and the shell's single mic calls [submit] with audio it
/// already finished capturing. This controller analyzes it, maps
/// observations/metrics into [Feedback], compares attempt 1 vs 2, persists
/// every completed step immediately (D20 — resilient to a Whop checkout
/// redirect mid-session, R11), and fires the milestone audio upload
/// fire-and-forget through `AttemptAudioStore` (design part-3 §5).
@Riverpod(keepAlive: true)
class TrainingLoopController extends _$TrainingLoopController {
  late final LoopRequest _request;
  late final TrainingLoop _loop;
  RecordedAudio? _lastAudio;
  List<Challenge>? _catalog;
  List<Observation>? _firstObservations;
  VoiceMetrics? _firstMetrics;

  @override
  TrainingLoopControllerState build(LoopRequest request) {
    _request = request;
    _loop = TrainingLoop(request.script);
    return TrainingLoopControllerState(loop: _loop.state);
  }

  /// Resubmits the most recently delivered audio ("Reintentar" — design
  /// §19.8: keeps the first/repeat bytes for replay, never re-records).
  Future<MicDelivery> resubmit() {
    final audio = _lastAudio;
    if (audio == null) {
      return Future.value(
        const MicDeliveryFailed('No hay ninguna grabación para reintentar.'),
      );
    }
    return submit(audio);
  }

  /// Moves from a passive `feedback`/`comparison` view into the next speak
  /// step's focus card, without recording (an explicit "Continuar" tap —
  /// design §19.8). A no-op from any other phase: the mic itself also
  /// auto-advances on [submit] (design §19.2 "feedback -> ready(repeat)"),
  /// so a double-advance here would otherwise throw.
  void continueToNextStep() {
    if (_loop.state.phase != LoopPhase.feedback &&
        _loop.state.phase != LoopPhase.comparison) {
      return;
    }
    _loop.continueToNextStep();
    state = state._withLoop(_loop.state);
  }

  /// Analyzes [audio] for the current speak step and advances the loop.
  ///
  /// The mic itself is the sole trigger for the next step (design §19.2):
  /// calling this while still showing `feedback`/`comparison` advances the
  /// loop first, exactly as an explicit "Continuar" tap would.
  Future<MicDelivery> submit(RecordedAudio audio) async {
    if (_loop.state.phase == LoopPhase.feedback ||
        _loop.state.phase == LoopPhase.comparison) {
      _loop.continueToNextStep();
      state = state._withLoop(_loop.state);
    }

    final step = _loop.state.attemptStep;
    if (step == null) {
      return const MicDeliveryFailed('No hay ningún paso activo para grabar.');
    }
    _lastAudio = audio;
    final slot = _loop.state.slot;
    final challengeId = _request.challengeIdFor(slot);

    // Reflect the busy window synchronously, before any await, so a
    // concurrent mic read never observes a stale `focus`/`feedback` phase
    // while this attempt is in flight (design §19.2 "recording/analyzing ->
    // busy").
    _loop.startAnalyzing();
    state = state._withLoop(_loop.state);

    final challenge = await _challengeFor(challengeId);
    if (!ref.mounted) return const MicAccepted();

    final analyzed = await ref
        .read(speechAnalysisRepositoryProvider)
        .analyze(
          audio.bytes,
          mimeType: audio.mimeType,
          duration: audio.duration,
          challengeId: challengeId,
        );
    if (!ref.mounted) return const MicAccepted();

    return switch (analyzed) {
      Err(:final failure) => _onAnalysisFailure(failure),
      Ok(:final value) => await _onAnalysisSuccess(
        step: step,
        audio: audio,
        transcript: value,
        challenge: challenge,
      ),
    };
  }

  MicDelivery _onAnalysisFailure(Failure failure) {
    final code = failure is SpeechAnalysisFailure
        ? failure.code
        : SpeechAnalysisErrorCode.unknown;
    if (code == SpeechAnalysisErrorCode.accessRequired) {
      _loop.accessRequired();
      state = state._withLoop(_loop.state);
      return const MicAccessRequired();
    }
    if (code == SpeechAnalysisErrorCode.dailyLimitReached) {
      _loop.analysisFailed(code.name);
      state = state._withLoop(_loop.state);
      return const MicDailyLimitReached();
    }
    _loop.analysisFailed(code.name);
    state = state._withLoop(_loop.state);
    return MicDeliveryFailed(_messageFor(code));
  }

  Future<MicDelivery> _onAnalysisSuccess({
    required AttemptKind step,
    required RecordedAudio audio,
    required SpeechTranscript transcript,
    required Challenge? challenge,
  }) async {
    final metrics = const VoiceMetricsCalculator().calculate(
      transcript: transcript,
      levelsDbfs: audio.levelsDbfs,
    );
    final observations = const ObservationMapper().fromAnalysis([
      for (final observation in transcript.observations)
        RawObservation(
          skill: observation.skill,
          code: observation.code,
          polarity: observation.polarity,
          evidence: observation.evidence,
        ),
    ]);

    final consentGranted = await _consentGranted();
    if (!ref.mounted) return const MicAccepted();
    final localDate = ref.read(clockProvider).localToday();
    // The repository's own unique (user_id, milestone_week) constraint is
    // authoritative (design part-3 §5): a milestone already claimed this
    // week downgrades this insert automatically, so this controller never
    // needs to look one up itself.
    const hasMilestoneThisIsoWeek = false;
    final shouldRetain = const MilestonePolicy().shouldRetain(
      consentGranted: consentGranted,
      analysisSucceeded: true,
      context: _request.context,
      kind: step,
      duration: transcript.duration,
      hasMilestoneThisIsoWeek: hasMilestoneThisIsoWeek,
    );

    final attempt = SpeakingAttempt(
      id: ref.read(idGeneratorProvider).generate(),
      sessionId: _request.sessionId,
      context: _request.context,
      kind: step,
      localDate: localDate,
      transcript: transcript.text,
      duration: transcript.duration,
      metrics: metrics,
      audio: shouldRetain
          ? const AudioRetention.pending()
          : const AudioRetention.none(),
      observations: observations,
      targetWordIds: _request.targetWordIds,
      challengeId: challenge?.id,
      milestoneWeek: shouldRetain ? localDate.startOfIsoWeek : null,
    );

    final inserted = await ref
        .read(speakingAttemptRepositoryProvider)
        .insert(attempt);
    if (!ref.mounted) return const MicAccepted();
    final stored = inserted.valueOrNull ?? attempt;

    if (stored.audio is AudioRetentionPending) {
      // Fire-and-forget (design part-3 §5): training never waits on upload.
      unawaited(
        ref
            .read(attemptAudioStoreProvider)
            .upload(
              attemptId: stored.id,
              bytes: audio.bytes,
              mimeType: audio.mimeType,
            ),
      );
    }

    final feedback = challenge == null
        ? null
        : const FeedbackComposer().compose(
            observations: observations,
            challengeArea: _areaOf(challenge.skill),
            aiRetryCue: transcript.coaching?.retryCue,
          );

    if (step == AttemptKind.first) {
      _firstObservations = observations;
      _firstMetrics = metrics;
    }

    _loop.analysisSucceeded();
    var next = state._withLoop(_loop.state);
    if (feedback != null && _loop.state.phase == LoopPhase.feedback) {
      next = next._withFeedback(feedback);
    }
    if (_loop.state.phase == LoopPhase.comparison) {
      final firstObservations = _firstObservations;
      final firstMetrics = _firstMetrics;
      if (firstObservations != null && firstMetrics != null) {
        next = next._withComparison(
          AttemptComparison.between(
            firstObservations: firstObservations,
            repeatObservations: observations,
            firstMetrics: firstMetrics,
            repeatMetrics: metrics,
          ),
        );
      }
    }
    state = next;
    return const MicAccepted();
  }

  Future<bool> _consentGranted() async {
    final result = await ref.read(audioConsentRepositoryProvider).read();
    return result.valueOrNull ?? false;
  }

  Future<Challenge?> _challengeFor(String? id) async {
    if (id == null) return null;
    var catalog = _catalog;
    if (catalog == null) {
      final result = await ref.read(challengeRepositoryProvider).fetchCatalog();
      catalog = result.valueOrNull ?? const <Challenge>[];
      _catalog = catalog;
    }
    for (final challenge in catalog) {
      if (challenge.id == id) return challenge;
    }
    return null;
  }

  static SkillArea _areaOf(Skill skill) => switch (skill) {
    Skill.thinking => SkillArea.thinking,
    Skill.language => SkillArea.language,
    Skill.voice => SkillArea.voice,
  };

  static String _messageFor(SpeechAnalysisErrorCode code) => switch (code) {
    SpeechAnalysisErrorCode.rateLimited =>
      'Estamos ocupados. Inténtalo en unos segundos.',
    SpeechAnalysisErrorCode.noSpeech =>
      'No te escuchamos bien. Inténtalo otra vez.',
    SpeechAnalysisErrorCode.accessRequired ||
    SpeechAnalysisErrorCode.accessUnavailable ||
    SpeechAnalysisErrorCode.dailyLimitReached ||
    SpeechAnalysisErrorCode.unknown =>
      'No pudimos analizar tu grabación. Inténtalo de nuevo.',
  };
}
