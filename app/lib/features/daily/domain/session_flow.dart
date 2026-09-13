import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/daily/domain/session_step.dart';
import 'package:flui/features/exercises/domain/cloze_attempt_flow.dart';
import 'package:flui/features/exercises/domain/cloze_exercise.dart';
import 'package:flui/features/exercises/domain/exercise_attempt.dart';
import 'package:flui/features/exercises/domain/session_frustration_guard.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/features/vocabulary/domain/word_progress.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';
import 'package:meta/meta.dart';

/// The ordered steps of a session and where the user is.
///
/// Order (docs/learning-method.md §1): due reviews, then each new word
/// through Descubre → Mira → Elige → Úsala, then one end-of-session check per
/// new word, then re-queued items.
///
/// Sessions resume after a reload from persisted data only
/// (`word_progress` and today's `exercise_attempts`):
/// - a review is done when its word has an attempt today;
/// - a new word introduced today has finished Descubre, Mira and Elige once
///   it has an attempt today, Úsala once `production_done` is true, and its
///   check once it has a second attempt after Úsala (or left `nueva`);
/// - pending re-queues are not restored, and forced reveals are counted over
///   the whole local day.
@immutable
final class SessionFlow {
  const new _({
    required this.steps,
    required this.index,
    required this.guard,
    required this.seeding,
    required this.postponedWordIds,
    required this._exercisesByWord,
    required this._lastSeen,
    required this._shownExerciseIds,
    required this._requeuedWordIds,
    required this._readableWordIds,
  });

  factory build({
    required List<String> reviewWordIds,
    required List<String> newWordIds,
    required Map<String, Word> words,
    required Map<String, WordProgress> progress,
    required List<ExerciseAttempt> attempts,
    required LocalDate today,
  }) {
    final todayAttempts = [
      for (final attempt in attempts)
        if (attempt.localDate == today) attempt,
    ];
    final shown = {for (final attempt in todayAttempts) attempt.exerciseId};
    final lastSeen = <String, (LocalDate, DateTime?)>{};
    for (final attempt in attempts) {
      final seen = (attempt.localDate, attempt.createdAt);
      final previous = lastSeen[attempt.exerciseId];
      if (previous == null || _compareSeen(seen, previous) > 0) {
        lastSeen[attempt.exerciseId] = seen;
      }
    }
    final exercisesByWord = {
      for (final word in words.values)
        word.id: ([...word.exercises]
          ..sort((a, b) => a.position.compareTo(b.position))),
    };
    final picker = _ExercisePicker(
      exercisesByWord: exercisesByWord,
      lastSeen: lastSeen,
      unavailable: {...shown},
    );
    List<ExerciseAttempt> attemptsOf(String wordId) => [
      for (final attempt in todayAttempts)
        if (attempt.wordId == wordId) attempt,
    ];

    final done = <SessionStep>[];
    final pending = <SessionStep>[];
    void add(SessionStep step, {required bool isDone}) =>
        (isDone ? done : pending).add(step);

    for (final wordId in reviewWordIds) {
      final word = words[wordId];
      final row = progress[wordId];
      if (word == null || row == null) continue;
      final answered = attemptsOf(wordId);
      final exerciseId =
          answered.firstOrNull?.exerciseId ?? picker.pick(wordId);
      if (exerciseId == null) continue;
      final isDone = answered.isNotEmpty;
      add(
        SessionStep.reviewCloze(wordId: wordId, exerciseId: exerciseId),
        isDone: isDone,
      );
      if (row.state == WordState.nueva) continue;
      if (!row.formRecallDone) {
        add(
          SessionStep.formRecall(wordId: wordId, isReview: true),
          isDone: isDone,
        );
      }
      if (!row.productionDone) {
        add(
          SessionStep.production(wordId: wordId, isReview: true),
          isDone: isDone,
        );
      }
    }

    final checks = <(SessionStep, bool)>[];
    for (final wordId in newWordIds) {
      final word = words[wordId];
      final row = progress[wordId];
      if (word == null || (row != null && row.introducedOn != today)) continue;
      final answered = attemptsOf(wordId);
      final started = row != null;
      final leftNueva = started && row.state != WordState.nueva;
      final usalaDone = started && (row.productionDone || leftNueva);
      final eligeDone = started && (answered.isNotEmpty || leftNueva);
      final checkDone = leftNueva || (usalaDone && answered.length >= 2);

      final practiceId =
          answered.firstOrNull?.exerciseId ?? picker.pick(wordId);
      if (practiceId == null) continue;
      add(SessionStep.discover(wordId: wordId), isDone: eligeDone || usalaDone);
      add(SessionStep.readings(wordId: wordId), isDone: eligeDone || usalaDone);
      add(
        SessionStep.practiceCloze(wordId: wordId, exerciseId: practiceId),
        isDone: eligeDone,
      );
      add(
        SessionStep.formRecall(wordId: wordId, isReview: false),
        isDone: usalaDone,
      );
      add(
        SessionStep.production(wordId: wordId, isReview: false),
        isDone: usalaDone,
      );
      final checkId = answered.length >= 2
          ? answered[1].exerciseId
          : picker.pick(wordId);
      if (checkId != null) {
        checks.add((
          SessionStep.finalCheck(wordId: wordId, exerciseId: checkId),
          checkDone,
        ));
      }
    }
    for (final (step, isDone) in checks) {
      add(step, isDone: isDone);
    }

    final flow = SessionFlow._(
      steps: List.unmodifiable([...done, ...pending]),
      index: done.length,
      guard: SessionFrustrationGuard(
        forcedReveals: todayAttempts.where((a) => a.revealed).length,
      ),
      seeding: false,
      postponedWordIds: const [],
      exercisesByWord: exercisesByWord,
      lastSeen: lastSeen,
      shownExerciseIds: shown,
      requeuedWordIds: const {},
      readableWordIds: {
        for (final word in words.values)
          if (word.readings.isNotEmpty) word.id,
      },
    );
    return flow.guard.isTriggered && !flow.isFinished
        ? flow._switchToSeeding()
        : flow;
  }

  final List<SessionStep> steps;

  /// Index of the current step; equals [total] when the session is over.
  final int index;
  final SessionFrustrationGuard guard;

  /// Reading mode after the frustration cap.
  final bool seeding;

  /// New words not started when reading mode began (planned again later).
  final List<String> postponedWordIds;

  final Map<String, List<ClozeExercise>> _exercisesByWord;
  final Map<String, (LocalDate, DateTime?)> _lastSeen;
  final Set<String> _shownExerciseIds;
  final Set<String> _requeuedWordIds;
  final Set<String> _readableWordIds;

  SessionStep? get current => index < steps.length ? steps[index] : null;

  bool get isFinished => index >= steps.length;

  int get total => steps.length;

  /// 1-based position for "2 de 5".
  int get position => isFinished ? total : index + 1;

  /// Word ids in session order, without repeats.
  List<String> get wordIds => {for (final step in steps) step.wordId}.toList();

  /// Descubre, Mira, Elige and both Úsala steps of [wordId] are done.
  bool discoveryCompletedFor(String wordId) {
    final visited = steps.take(index).where((step) => step.wordId == wordId);
    return visited.any((s) => s is DiscoverStep) &&
        visited.any((s) => s is ReadingsStep) &&
        visited.any((s) => s is PracticeClozeStep) &&
        visited.any((s) => s is FormRecallStep && !s.isReview) &&
        visited.any((s) => s is ProductionStep && !s.isReview);
  }

  /// Moves past a non-cloze step.
  SessionFlow completeStep() => isFinished ? this : _copy(index: index + 1);

  /// Moves past the current cloze step. A forced reveal counts towards the
  /// frustration cap and re-queues the word once, with an exercise not shown
  /// today, unless the cap is reached.
  SessionFlow completeCloze(ClozeResolution resolution) {
    final step = current;
    final exerciseId = step?.exerciseId;
    if (step == null || exerciseId == null) {
      throw StateError('The current step is not a cloze.');
    }
    final shown = {..._shownExerciseIds, exerciseId};
    final guard = resolution.revealed
        ? this.guard.recordForcedReveal()
        : this.guard;
    var steps = this.steps;
    var requeued = _requeuedWordIds;

    if (resolution.revealed &&
        !guard.isTriggered &&
        step is! RequeueClozeStep &&
        !requeued.contains(step.wordId)) {
      final reserved = {
        for (final pending in steps.skip(index + 1)) ?pending.exerciseId,
      };
      final picker = _ExercisePicker(
        exercisesByWord: _exercisesByWord,
        lastSeen: _lastSeen,
        unavailable: {...shown, ...reserved},
      );
      final requeueId = picker.pick(step.wordId);
      if (requeueId != null) {
        steps = List.unmodifiable([
          ...steps,
          SessionStep.requeueCloze(
            wordId: step.wordId,
            exerciseId: requeueId,
            fromReview: step is ReviewClozeStep,
          ),
        ]);
        requeued = {...requeued, step.wordId};
      }
    }

    final next = _copy(
      steps: steps,
      index: index + 1,
      guard: guard,
      shown: shown,
      requeued: requeued,
    );
    return guard.isTriggered && !seeding ? next._switchToSeeding() : next;
  }

  /// Frustration cap: postpone new words not started, cancel re-queues and
  /// turn every other pending step into one reading per word.
  SessionFlow _switchToSeeding() {
    final pending = steps.skip(index).toList();
    final notStarted = {
      for (final step in pending)
        if (step is DiscoverStep) step.wordId,
    };
    final readingWords = <String>{};
    for (final step in pending) {
      if (step is RequeueClozeStep || notStarted.contains(step.wordId)) {
        continue;
      }
      if (_readableWordIds.contains(step.wordId)) readingWords.add(step.wordId);
    }
    return _copy(
      steps: List.unmodifiable([
        ...steps.take(index),
        for (final wordId in readingWords)
          SessionStep.seedingReading(wordId: wordId),
      ]),
      seeding: true,
      postponed: notStarted.toList(),
    );
  }

  SessionFlow _copy({
    List<SessionStep>? steps,
    int? index,
    SessionFrustrationGuard? guard,
    bool? seeding,
    List<String>? postponed,
    Set<String>? shown,
    Set<String>? requeued,
  }) => SessionFlow._(
    steps: steps ?? this.steps,
    index: index ?? this.index,
    guard: guard ?? this.guard,
    seeding: seeding ?? this.seeding,
    postponedWordIds: postponed ?? postponedWordIds,
    exercisesByWord: _exercisesByWord,
    lastSeen: _lastSeen,
    shownExerciseIds: shown ?? _shownExerciseIds,
    requeuedWordIds: requeued ?? _requeuedWordIds,
    readableWordIds: _readableWordIds,
  );

  static int _compareSeen((LocalDate, DateTime?) a, (LocalDate, DateTime?) b) {
    final byDate = a.$1.compareTo(b.$1);
    if (byDate != 0) return byDate;
    final at = a.$2;
    final bt = b.$2;
    if (at == null || bt == null) return 0;
    return at.compareTo(bt);
  }
}

/// Chooses fresh sentences: not shown today nor reserved by another step,
/// never-seen exercises first, then the least recently seen, then position.
final class _ExercisePicker {
  new({
    required this.exercisesByWord,
    required this.lastSeen,
    required this.unavailable,
  });

  final Map<String, List<ClozeExercise>> exercisesByWord;
  final Map<String, (LocalDate, DateTime?)> lastSeen;
  final Set<String> unavailable;

  String? pick(String wordId) {
    final options = [
      for (final exercise in exercisesByWord[wordId] ?? const <ClozeExercise>[])
        if (!unavailable.contains(exercise.id)) exercise,
    ];
    if (options.isEmpty) return null;
    options.sort((a, b) {
      final seenA = lastSeen[a.id];
      final seenB = lastSeen[b.id];
      if (seenA == null && seenB != null) return -1;
      if (seenA != null && seenB == null) return 1;
      if (seenA != null && seenB != null) {
        final bySeen = SessionFlow._compareSeen(seenA, seenB);
        if (bySeen != 0) return bySeen;
      }
      return a.position.compareTo(b.position);
    });
    final chosen = options.first.id;
    unavailable.add(chosen);
    return chosen;
  }
}
