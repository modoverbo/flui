import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/core/riverpod/ref_futures.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/daily/domain/session_flow.dart';
import 'package:flui/features/daily/domain/session_planner.dart';
import 'package:flui/features/daily/domain/session_step.dart';
import 'package:flui/features/daily/presentation/providers/learning_data_controller.dart';
import 'package:flui/features/speaking/presentation/providers/speaking_providers.dart';
import 'package:flui/features/vocabulary/domain/exercises/cloze_attempt_flow.dart';
import 'package:flui/features/vocabulary/domain/exercises/cloze_exercise.dart';
import 'package:flui/features/vocabulary/domain/exercises/exercise_attempt.dart';
import 'package:flui/features/vocabulary/domain/exercises/form_recall_check.dart';
import 'package:flui/features/vocabulary/domain/exercises/production_check.dart';
import 'package:flui/features/vocabulary/domain/form_recall_prompt.dart';
import 'package:flui/features/vocabulary/domain/grade.dart';
import 'package:flui/features/vocabulary/domain/mastery_policy.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/features/vocabulary/domain/word_progress.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';
import 'package:flui/features/vocabulary/presentation/providers/exercise_providers.dart';
import 'package:flui/features/vocabulary/presentation/providers/vocabulary_providers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_controller.freezed.dart';
part 'session_controller.g.dart';

enum SessionMode {
  /// Today's planned session (`daily_sessions`).
  daily,

  /// Every due review ("repaso extra").
  review,

  /// "Repaso libre": practice with words that are *not* due, offered when the
  /// planner has nothing to give. It records attempts, so the day counts, but
  /// it never touches the ladder — answering a word early must not push its
  /// real review away.
  free,
}

@freezed
abstract class SessionState with _$SessionState {
  const factory({
    required SessionMode mode,
    required LocalDate today,
    required SessionFlow flow,
    required Map<String, Word> words,

    /// Latest progress of the words in this session.
    required Map<String, WordProgress> progress,
    ClozeAttemptFlow? cloze,
    FormRecallCheck? formRecall,
    ProductionFlow? production,
    @Default(false) bool saving,
    Failure? failure,

    /// Words that reached "tuya" during this session.
    @Default(<String>[]) List<String> ownedWordIds,

    /// Clozes resolved in this session, and how many on the first try. The
    /// summary reports the session, not a lifetime average.
    @Default(0) int answeredCount,
    @Default(0) int firstTryCount,
    DateTime? stepStartedAt,
  }) = _SessionState;

  const new _();

  SessionStep? get step => flow.current;

  Word? get word {
    final step = this.step;
    return step == null ? null : words[step.wordId];
  }

  bool get isFinished => flow.isFinished;

  /// First-try share of this session, `null` before the first answer.
  int? get accuracyPercent =>
      answeredCount == 0 ? null : (firstTryCount * 100 / answeredCount).round();

  ClozeExercise? get exercise {
    final id = step?.exerciseId;
    if (id == null) return null;
    return word?.exercises.where((e) => e.id == id).firstOrNull;
  }

  FormRecallPrompt? get formRecallPrompt {
    final word = this.word;
    return step is FormRecallStep && word != null
        ? FormRecallPrompt.forWord(word)
        : null;
  }

  /// New words of this session that were introduced (for the summary).
  List<String> get summaryNewWordIds => [
    for (final step in flow.steps)
      if (step is DiscoverStep && progress.containsKey(step.wordId))
        step.wordId,
  ];

  /// Reviewed words of this session (for the summary).
  List<String> get summaryReviewWordIds => [
    for (final step in flow.steps.take(flow.index))
      if (step is ReviewClozeStep) step.wordId,
  ];
}

/// View model of the session runner (`/session`).
///
/// Every answer is saved as it happens (attempt first, then progress), so a
/// reload resumes from the persisted data (see [SessionFlow.build]). A failed
/// save keeps the user on the step with a retry.
@riverpod
class SessionController extends _$SessionController {
  List<Future<Result<void>> Function()> _pending = const [];
  Future<void> Function()? _afterSave;
  String? _userId;

  @override
  Future<SessionState> build(SessionMode mode) async {
    final user = await ref.readFuture(authUserProvider.future);
    final userId = _userId = user?.id;
    final words = await ref.readFuture(wordsByIdProvider.future);
    final data = userId == null
        ? const LearningData()
        : await ref.readFuture(learningDataControllerProvider(userId).future);
    final today = ref.read(clockProvider).localToday();

    final (reviewIds, newIds) = switch (mode) {
      SessionMode.daily => (
        data.sessionOn(today)?.reviewWordIds ?? const <String>[],
        data.sessionOn(today)?.plannedWordIds ?? const <String>[],
      ),
      SessionMode.review => (
        SessionPlanner.orderReviews(
          SessionPlanInputs.derive(
            catalog: words.values.toList(),
            progress: data.progress,
            today: today,
          ).dueReviews,
        ).map((review) => review.wordId).toList(),
        const <String>[],
      ),
      SessionMode.free => (
        _freeReviewIds(data, words, today),
        const <String>[],
      ),
    };
    final progress = {for (final row in data.progress) row.wordId: row};
    final flow = SessionFlow.build(
      reviewWordIds: reviewIds,
      newWordIds: newIds,
      words: words,
      progress: progress,
      attempts: data.attempts,
      today: today,
    );
    final initial = _enterStep(
      SessionState(
        mode: mode,
        today: today,
        flow: flow,
        words: words,
        progress: {
          for (final id in flow.wordIds)
            if (progress[id] != null) id: progress[id]!,
        },
      ),
    );
    // Everything was already done (for example, after a reload). An empty
    // plan counts too: the user showed up, and the gap is ours.
    if (flow.isFinished) await _completeDailySession(initial);
    return initial;
  }

  /// "Continuar" on the current step.
  Future<void> continueStep() async {
    final current = state.value;
    if (current == null || current.saving || current.isFinished) return;
    final step = current.step!;
    switch (step) {
      case DiscoverStep(:final wordId):
        if (current.progress.containsKey(wordId)) {
          await _advance(current.flow.completeStep());
          return;
        }
        final introduced = WordProgress.introduced(
          wordId: wordId,
          today: current.today,
        );
        await _save(
          [() => _learning.saveProgress(introduced)],
          apply: (s) =>
              s.copyWith(progress: {...s.progress, wordId: introduced}),
          then: () => _advance(state.requireValue.flow.completeStep()),
        );
      case ReadingsStep() || SeedingReadingStep():
        await _advance(current.flow.completeStep());
      case ReviewClozeStep() ||
          PracticeClozeStep() ||
          FinalCheckStep() ||
          RequeueClozeStep():
        final resolution = current.cloze?.resolution;
        if (resolution == null) return;
        await _advance(current.flow.completeCloze(resolution));
      case FormRecallStep():
        if (!(current.formRecall?.isResolved ?? false)) return;
        await _advance(current.flow.completeStep());
      case ProductionStep():
        if (!(current.production?.isAccepted ?? false)) return;
        await _advance(current.flow.completeStep());
    }
  }

  Future<void> answerCloze(String optionId) async {
    final current = state.value;
    final cloze = current?.cloze;
    final step = current?.step;
    if (current == null || cloze == null || step == null) return;
    if (cloze.isResolved || !cloze.isEnabled(optionId) || current.saving) {
      return;
    }
    final next = cloze.answer(optionId);
    final resolution = next.resolution;
    if (resolution == null) {
      _set(current.copyWith(cloze: next));
      return;
    }

    final now = ref.read(clockProvider).now();
    final started = current.stepStartedAt;
    final attempt = ExerciseAttempt(
      exerciseId: step.exerciseId!,
      wordId: step.wordId,
      attempts: resolution.attempts,
      revealed: resolution.revealed,
      grade: resolution.grade,
      localDate: current.today,
      durationMs: started == null
          ? null
          : now.difference(started).inMilliseconds,
      createdAt: now,
    );
    final before = current.progress[step.wordId];
    final after = before == null
        ? null
        : _progressAfterCloze(current, step, before, resolution.grade, now);

    _set(
      current.copyWith(
        cloze: next,
        answeredCount: current.answeredCount + 1,
        firstTryCount: current.firstTryCount + (attempt.firstTry ? 1 : 0),
      ),
    );
    await _save(
      [
        () => _learning.recordAttempt(attempt),
        if (after != null && after != before)
          () => _learning.saveProgress(after),
      ],
      apply: after == null
          ? null
          : (s) => s.copyWith(
              progress: {...s.progress, step.wordId: after},
              ownedWordIds:
                  after.state == WordState.tuya &&
                      before?.state != WordState.tuya
                  ? [...s.ownedWordIds, step.wordId]
                  : s.ownedWordIds,
            ),
    );
  }

  /// "Intentar de nuevo" after a "Casi." hint.
  void retryCloze() {
    final current = state.value;
    final cloze = current?.cloze;
    if (current == null || cloze == null) return;
    _set(current.copyWith(cloze: cloze.dismissFeedback()));
  }

  Future<void> takeFormRecallHint() =>
      _updateFormRecall((check) => check.takeHint());

  /// Transcribes [audio] (design D34-D36, U17b: `mode=transcribe`, no LLM,
  /// 1 quota unit) and matches it through [FormRecallCheck.submitHeard].
  ///
  /// Guarded at this domain primitive, not only by the mic target's own
  /// `availability` (the U17 review-finding pattern: a UI-level gate alone
  /// let a second path spend quota on a resolved/inactive step) — never
  /// transcribes when the current step is not [FormRecallStep], the check
  /// is already resolved, or a save is already in flight.
  Future<MicDelivery> answerFormRecallAloud(RecordedAudio audio) async {
    final current = state.value;
    final check = current?.formRecall;
    if (current == null ||
        check == null ||
        current.step is! FormRecallStep ||
        check.isResolved ||
        current.saving) {
      return const MicDeliveryFailed('No hay ningún paso activo para grabar.');
    }
    final transcribed = await ref
        .read(speechAnalysisRepositoryProvider)
        .transcribe(
          audio.bytes,
          mimeType: audio.mimeType,
          duration: audio.duration,
        );
    if (!ref.mounted) return const MicAccepted();
    return switch (transcribed) {
      Err(:final failure) => _micDeliveryForTranscribeFailure(failure),
      Ok(:final value) => await _onFormRecallHeard(value.text),
    };
  }

  Future<MicDelivery> _onFormRecallHeard(String transcript) async {
    await _updateFormRecall((check) => check.submitHeard(transcript));
    return const MicAccepted();
  }

  /// Ticks or unticks one item of the self-check rubric.
  void toggleProductionRubric(ProductionRubric item) {
    final current = state.value;
    final production = current?.production;
    if (current == null || production == null) return;
    _set(current.copyWith(production: production.toggle(item)));
  }

  /// "Quiero ajustarla".
  void reviseProduction() {
    final current = state.value;
    final production = current?.production;
    if (current == null || production == null) return;
    _set(current.copyWith(production: production.rejectNatural()));
  }

  /// "Sí, suena natural": saves `production_done` and moves on.
  Future<void> confirmProduction() async {
    final current = state.value;
    final production = current?.production;
    final step = current?.step;
    if (current == null || production == null || step == null) return;
    final accepted = production.confirmNatural();
    if (!accepted.isAccepted) return;
    _set(current.copyWith(production: accepted));

    final before = current.progress[step.wordId];
    final after = before == null
        ? null
        : MasteryPolicy.evaluateTuya(before.copyWith(productionDone: true));
    await _save(
      [
        if (after != null && after != before)
          () => _learning.saveProgress(after),
      ],
      apply: after == null ? null : (s) => _withProgress(s, before, after),
      then: continueStep,
    );
  }

  /// Transcribes [audio] and feeds the transcript through the SAME
  /// unchanged [ProductionFlow.submit] used for a typed answer (design
  /// D34-D36, U17b; D35 — only form recall gets a new matcher; production's
  /// existing text-based validator already works fine against a transcript
  /// string).
  ///
  /// Guarded at this domain primitive (see [answerFormRecallAloud]'s own
  /// doc): never transcribes when the current step is not [ProductionStep],
  /// the flow has already left the writing phase, or a save is in flight.
  Future<MicDelivery> answerProductionAloud(RecordedAudio audio) async {
    final current = state.value;
    final production = current?.production;
    if (current == null ||
        production == null ||
        current.step is! ProductionStep ||
        production.phase != ProductionPhase.writing ||
        current.saving) {
      return const MicDeliveryFailed('No hay ningún paso activo para grabar.');
    }
    final transcribed = await ref
        .read(speechAnalysisRepositoryProvider)
        .transcribe(
          audio.bytes,
          mimeType: audio.mimeType,
          duration: audio.duration,
        );
    if (!ref.mounted) return const MicAccepted();
    return switch (transcribed) {
      Err(:final failure) => _micDeliveryForTranscribeFailure(failure),
      Ok(:final value) => _onProductionHeard(value.text),
    };
  }

  MicDelivery _onProductionHeard(String transcript) {
    final current = state.value;
    final production = current?.production;
    if (current == null || production == null) return const MicAccepted();
    _set(current.copyWith(production: production.submit(transcript)));
    return const MicAccepted();
  }

  /// "Continuar sin hablar" (design D36): the view offers this ONLY while
  /// the mic is latched/blocked. Advances past the current Úsala step
  /// WITHOUT persisting `form_recall_done`/`production_done` — both stay
  /// false, so the step resurfaces on a later visit, mirroring every other
  /// non-graded step's own [SessionFlow.completeStep] call (`DiscoverStep`,
  /// `ReadingsStep`).
  Future<void> skipSpokenStep() async {
    final current = state.value;
    final step = current?.step;
    if (current == null || current.saving) return;
    if (step is! FormRecallStep && step is! ProductionStep) return;
    await _advance(current.flow.completeStep());
  }

  Future<void> retrySave() => _flush();

  Future<void> _updateFormRecall(
    FormRecallCheck Function(FormRecallCheck check) update,
  ) async {
    final current = state.value;
    final check = current?.formRecall;
    final step = current?.step;
    if (current == null || check == null || step == null || current.saving) {
      return;
    }
    final next = update(check);
    _set(current.copyWith(formRecall: next));
    final before = current.progress[step.wordId];
    if (!next.countsAsDone || before == null || before.formRecallDone) return;
    final after = MasteryPolicy.evaluateTuya(
      before.copyWith(formRecallDone: true),
    );
    await _save([
      () => _learning.saveProgress(after),
    ], apply: (s) => _withProgress(s, before, after));
  }

  WordProgress _progressAfterCloze(
    SessionState current,
    SessionStep step,
    WordProgress before,
    Grade grade,
    DateTime now,
  ) {
    // A free run is extra practice: the attempt is recorded, the schedule is
    // not touched. Grading a word that is not due would push its real review
    // away and quietly break the ladder.
    if (current.mode == SessionMode.free) return before;
    final discovery = current.flow.discoveryCompletedFor(step.wordId);
    return switch (step) {
      ReviewClozeStep() => MasteryPolicy.review(
        before,
        grade: grade,
        today: current.today,
        now: now,
      ),
      FinalCheckStep() => MasteryPolicy.afterSessionCheck(
        before,
        discoveryCompleted: discovery,
        grade: grade,
        today: current.today,
      ),
      // A re-queued new word gets its unaided chance in a fresh sentence.
      RequeueClozeStep(fromReview: false)
          when before.state == WordState.nueva && grade == Grade.good =>
        MasteryPolicy.afterSessionCheck(
          before,
          discoveryCompleted: discovery,
          grade: grade,
          today: current.today,
        ),
      _ => before,
    };
  }

  SessionState _withProgress(
    SessionState s,
    WordProgress? before,
    WordProgress after,
  ) => s.copyWith(
    progress: {...s.progress, after.wordId: after},
    ownedWordIds:
        after.state == WordState.tuya && before?.state != WordState.tuya
        ? [...s.ownedWordIds, after.wordId]
        : s.ownedWordIds,
  );

  Future<void> _advance(SessionFlow flow) async {
    final current = state.requireValue;
    _set(
      _enterStep(
        current.copyWith(
          flow: flow,
          cloze: null,
          formRecall: null,
          production: null,
          failure: null,
        ),
      ),
    );
    if (flow.isFinished) await _completeDailySession(state.requireValue);
  }

  SessionState _enterStep(SessionState s) {
    final step = s.step;
    final word = s.word;
    final base = s.copyWith(stepStartedAt: ref.read(clockProvider).now());
    if (step == null || word == null) return base;
    if (step.isCloze) {
      final exercise = base.exercise;
      if (exercise == null) return base;
      return base.copyWith(
        cloze: ClozeAttemptFlow.start(
          exercise,
          random: ref.read(shuffleRandomProvider),
        ),
      );
    }
    return switch (step) {
      FormRecallStep() => base.copyWith(
        formRecall: FormRecallCheck(
          expectedForm: FormRecallPrompt.forWord(word).expectedForm,
          forms: word.forms,
        ),
      ),
      ProductionStep() => base.copyWith(
        production: ProductionFlow(
          forms: word.forms,
          modelSentence: word.exampleSentence,
        ),
      ),
      _ => base,
    };
  }

  /// Marks today active. Opening a session is enough: an empty plan is our
  /// gap, not the user's, and it must never cost a streak. A review run only
  /// closes the day when the plan had nothing to offer, so it never hides a
  /// session the user still owes.
  Future<void> _completeDailySession(SessionState current) async {
    final userId = _userId;
    if (userId == null || !current.isFinished) return;
    final data = ref.read(learningDataControllerProvider(userId)).value;
    final session = data?.sessionOn(current.today);
    if (session == null || session.isCompleted) return;
    if (current.mode != SessionMode.daily && !session.isEmpty) return;
    await _learning.completeSession(
      current.today,
      ref.read(clockProvider).now(),
    );
  }

  Future<void> _save(
    List<Future<Result<void>> Function()> operations, {
    SessionState Function(SessionState state)? apply,
    Future<void> Function()? then,
  }) {
    _pending = operations;
    _afterSave = () async {
      final current = state.value;
      if (apply != null && current != null) _set(apply(current));
      if (then != null) await then();
    };
    return _flush();
  }

  Future<void> _flush() async {
    final current = state.value;
    if (current == null) return;
    _set(current.copyWith(saving: true, failure: null));
    while (_pending.isNotEmpty) {
      final result = await _pending.first();
      if (!ref.mounted) return;
      if (result case Err(:final failure)) {
        _set(state.requireValue.copyWith(saving: false, failure: failure));
        return;
      }
      _pending = _pending.skip(1).toList();
    }
    _set(state.requireValue.copyWith(saving: false));
    final after = _afterSave;
    _afterSave = null;
    if (after != null) await after();
  }

  LearningDataController get _learning =>
      ref.read(learningDataControllerProvider(_userId ?? '').notifier);

  void _set(SessionState next) => state = AsyncData(next);
}

/// Maps a `transcribe` failure to the [MicDelivery] the mic controller
/// expects (design D34-D37): access/quota latch the mic exactly like the
/// full-analysis loop path (`TrainingLoopController._onAnalysisFailure`);
/// `noSpeech` gets the distinct copy (no hint consumed, since the caller
/// never even reaches [FormRecallCheck.submitHeard]/[ProductionFlow.submit]
/// on this branch); everything else falls back to a generic message.
MicDelivery _micDeliveryForTranscribeFailure(Failure failure) {
  final code = failure is SpeechAnalysisFailure
      ? failure.code
      : SpeechAnalysisErrorCode.unknown;
  return switch (code) {
    SpeechAnalysisErrorCode.accessRequired => const MicAccessRequired(),
    SpeechAnalysisErrorCode.dailyLimitReached => const MicDailyLimitReached(),
    // The exact shared literal (U17b): lets `MicController` pick the
    // dedicated `MicNotice.noSpeech` notice over the generic one.
    SpeechAnalysisErrorCode.noSpeech => const MicDeliveryFailed(
      noSpeechDeliveryMessage,
    ),
    SpeechAnalysisErrorCode.accessUnavailable ||
    SpeechAnalysisErrorCode.rateLimited ||
    SpeechAnalysisErrorCode.unknown => const MicDeliveryFailed(
      'No pudimos enviar tu grabación. Inténtalo de nuevo.',
    ),
  };
}

/// Words for a free run: everything past `nueva`, the ones due furthest in
/// the future last, capped so a free run still respects the user's time.
List<String> _freeReviewIds(
  LearningData data,
  Map<String, Word> words,
  LocalDate today,
) {
  final rows =
      [
        for (final row in data.progress)
          if (words.containsKey(row.wordId) && row.state != WordState.nueva)
            row,
      ]..sort((a, b) {
        final dueA = a.nextDueOn ?? a.introducedOn;
        final dueB = b.nextDueOn ?? b.introducedOn;
        final byDue = dueA.compareTo(dueB);
        return byDue != 0 ? byDue : a.wordId.compareTo(b.wordId);
      });
  return [for (final row in rows.take(freeReviewLimit)) row.wordId];
}

/// How many words one free run offers.
const freeReviewLimit = 8;
