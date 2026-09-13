import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/daily/domain/session_planner.dart';
import 'package:flui/features/daily/domain/session_step.dart';
import 'package:flui/features/exercises/domain/cloze_attempt_flow.dart';
import 'package:flui/features/exercises/domain/cloze_exercise.dart';
import 'package:flui/features/exercises/domain/exercise_attempt.dart';
import 'package:flui/features/exercises/domain/session_frustration_guard.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/features/vocabulary/domain/word_progress.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';
import 'package:meta/meta.dart';

/// One rung of a word's ladder inside a session.
///
/// The first three phases stay blocked per word; the rest are emitted phase
/// by phase across every word, so the user alternates between lemmas instead
/// of grinding one word to the end. See [SessionFlow] for why.
enum _Phase {
  discover,
  readingsFirst,
  elige,
  formRecall,
  readingsRest,
  production,
  check,
}

/// The ordered steps of a session and where the user is.
///
/// Order (docs/learning-method.md §1):
/// 1. warm-up reviews;
/// 2. one blocked acquisition run per new word — Descubre, one scene, Elige —
///    with the remaining due reviews spread between the runs;
/// 3. the form recalls of every new word and of the reviews that owe one;
/// 4. the scenes held back during acquisition;
/// 5. the productions, new words and reviews together;
/// 6. a mixed end-of-session check: every new word plus one or two of today's
///    reviews, in a deterministic per-day order;
/// 7. re-queued items.
///
/// **Why acquisition is blocked and only practice is interleaved.**
/// Interleaving helps on average (Brunmair & Richter 2019, *Psychological
/// Bulletin*, 59 studies / 238 effect sizes, g = 0.42) but it *hurts* for
/// word-list and vocabulary material (g = -0.39); it only pays off for
/// confusable items (Rohrer & Taylor 2007). So the first contact with a
/// lemma is never chopped up. Variety comes from mixing due reviews between
/// the acquisition runs and from the mixed final check, not from splitting
/// acquisition. Tinkham (1993, 1997) and Nation (2000) add that semantic
/// clusters — synonyms, antonyms, category mates — interfere, while
/// thematic clusters do not; the planner's interference rule is the place
/// for that (see `SessionPlanner`).
///
/// Sessions resume after a reload from persisted data only (`word_progress`
/// and today's `exercise_attempts`). Every step is done when its own evidence
/// says so — a row for Descubre, an attempt for a cloze, `form_recall_done`
/// for a form recall, `production_done` for a production — or when a later
/// step of the same word is done. Steps that persist nothing (Mira) inherit
/// from the step after them. Pending re-queues are not restored, and forced
/// reveals are counted over the whole local day.
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

    /// Leading reviews that open the session as a quick win. The
    /// planner already sorts them to the front; `daily_sessions` does not
    /// persist the count, so the same default is used when resuming.
    int warmUpCount = SessionPlanner.defaultWarmUpSize,
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

    // Reviews first, so a new word never changes which sentence a review uses.
    final reviews = <_ReviewTrack>[];
    for (final wordId in reviewWordIds) {
      final word = words[wordId];
      final row = progress[wordId];
      if (word == null || row == null) continue;
      final answered = attemptsOf(wordId);
      final exerciseId =
          answered.firstOrNull?.exerciseId ?? picker.pick(wordId);
      if (exerciseId == null) continue;
      final catchUp = row.state != WordState.nueva;
      reviews.add(
        _ReviewTrack(
          wordId: wordId,
          exerciseId: exerciseId,
          clozeDone: answered.isNotEmpty,
          needsFormRecall: catchUp && !row.formRecallDone,
          needsProduction: catchUp && !row.productionDone,
        ),
      );
    }

    final newTracks = <Map<_Phase, (SessionStep, bool)>>[];
    for (final wordId in newWordIds) {
      final word = words[wordId];
      final row = progress[wordId];
      if (word == null || (row != null && row.introducedOn != today)) continue;
      final answered = attemptsOf(wordId);
      final practiceId =
          answered.firstOrNull?.exerciseId ?? picker.pick(wordId);
      if (practiceId == null) continue;
      final checkId = answered.length >= 2
          ? answered[1].exerciseId
          : picker.pick(wordId);
      newTracks.add(
        _newWordTrack(
          wordId: wordId,
          practiceExerciseId: practiceId,
          checkExerciseId: checkId,
          readingCount: word.readings.length,
          row: row,
          answers: answered.length,
        ),
      );
    }

    final ordered = _order(
      reviews: reviews,
      newTracks: newTracks,
      warmUpCount: warmUpCount,
      today: today,
    );
    final done = [
      for (final (step, isDone) in ordered)
        if (isDone) step,
    ];
    final pending = [
      for (final (step, isDone) in ordered)
        if (!isDone) step,
    ];

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

  /// Descubre, at least one Mira, Elige and both Úsala steps of [wordId] are
  /// behind the cursor.
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

/// A due review: one cloze, plus the Úsala steps it still owes.
@immutable
final class _ReviewTrack {
  const new({
    required this.wordId,
    required this.exerciseId,
    required this.clozeDone,
    required this.needsFormRecall,
    required this.needsProduction,
  });

  final String wordId;
  final String exerciseId;
  final bool clozeDone;
  final bool needsFormRecall;
  final bool needsProduction;

  /// Only a review that owes nothing else can be held back for the mixed
  /// end-of-session check: its Úsala steps would otherwise come first.
  bool get isPlain => !needsFormRecall && !needsProduction;

  (SessionStep, bool) get cloze => (
    SessionStep.reviewCloze(wordId: wordId, exerciseId: exerciseId),
    clozeDone,
  );
}

/// The seven steps of a new word, each with whether persisted data already
/// proves it done. A step that persists nothing inherits from the next one,
/// so the cursor never lands before work the user has visibly finished.
Map<_Phase, (SessionStep, bool)> _newWordTrack({
  required String wordId,
  required String practiceExerciseId,
  required String? checkExerciseId,
  required int readingCount,
  required WordProgress? row,
  required int answers,
}) {
  final started = row != null;
  final leftNueva = started && row.state != WordState.nueva;
  final entries = <(_Phase, SessionStep, bool?)>[
    (_Phase.discover, SessionStep.discover(wordId: wordId), started),
    // Always present: discovery is only complete once Mira was visited.
    (
      _Phase.readingsFirst,
      SessionStep.readings(wordId: wordId, maxCount: 1),
      null,
    ),
    (
      _Phase.elige,
      SessionStep.practiceCloze(wordId: wordId, exerciseId: practiceExerciseId),
      answers >= 1 || leftNueva,
    ),
    (
      _Phase.formRecall,
      SessionStep.formRecall(wordId: wordId, isReview: false),
      started && (row.formRecallDone || leftNueva),
    ),
    if (readingCount > 1)
      (
        _Phase.readingsRest,
        SessionStep.readings(wordId: wordId, fromIndex: 1),
        null,
      ),
    (
      _Phase.production,
      SessionStep.production(wordId: wordId, isReview: false),
      started && (row.productionDone || leftNueva),
    ),
    if (checkExerciseId != null)
      (
        _Phase.check,
        SessionStep.finalCheck(wordId: wordId, exerciseId: checkExerciseId),
        leftNueva || answers >= 2,
      ),
  ];

  final track = <_Phase, (SessionStep, bool)>{};
  var laterDone = false;
  for (final (phase, step, evidence) in entries.reversed) {
    laterDone = (evidence ?? false) || laterDone;
    track[phase] = (step, laterDone);
  }
  return track;
}

/// Interleaves the tracks phase by phase (see [SessionFlow]).
List<(SessionStep, bool)> _order({
  required List<_ReviewTrack> reviews,
  required List<Map<_Phase, (SessionStep, bool)>> newTracks,
  required int warmUpCount,
  required LocalDate today,
}) {
  final warmUps = reviews.take(warmUpCount.clamp(0, reviews.length)).toList();
  final rest = reviews.skip(warmUps.length).toList();

  // One or two plain reviews close the session inside the mixed check.
  final reservable = [
    for (final review in rest)
      if (review.isPlain) review,
  ];
  var reserveCount = newTracks.isEmpty ? 0 : (rest.length ~/ 2).clamp(1, 2);
  if (reserveCount > reservable.length) reserveCount = reservable.length;
  final reserved = reservable.skip(reservable.length - reserveCount).toList();
  final reservedIds = {for (final review in reserved) review.wordId};
  final separators = [
    for (final review in rest)
      if (!reservedIds.contains(review.wordId)) review,
  ];

  final ordered = <(SessionStep, bool)>[
    for (final review in warmUps) review.cloze,
  ];
  void emitPhase(_Phase phase) {
    for (final track in newTracks) {
      if (track[phase] case final entry?) ordered.add(entry);
    }
  }

  // First contact with a word stays blocked: Descubre, one scene and Elige
  // of the same lemma, back to back. Due reviews go between the blocks, so
  // the session is still unpredictable without splitting acquisition.
  const acquisition = [_Phase.discover, _Phase.readingsFirst, _Phase.elige];
  final perGap = newTracks.isEmpty
      ? 0
      : (separators.length + newTracks.length - 1) ~/ newTracks.length;
  var cursor = 0;
  for (final track in newTracks) {
    for (final phase in acquisition) {
      if (track[phase] case final entry?) ordered.add(entry);
    }
    for (var i = 0; i < perGap && cursor < separators.length; i++) {
      ordered.add(separators[cursor++].cloze);
    }
  }
  while (cursor < separators.length) {
    ordered.add(separators[cursor++].cloze);
  }

  emitPhase(_Phase.formRecall);
  for (final review in reviews) {
    if (review.needsFormRecall) {
      ordered.add((
        SessionStep.formRecall(wordId: review.wordId, isReview: true),
        false,
      ));
    }
  }

  emitPhase(_Phase.readingsRest);

  emitPhase(_Phase.production);
  for (final review in reviews) {
    if (review.needsProduction) {
      ordered.add((
        SessionStep.production(wordId: review.wordId, isReview: true),
        false,
      ));
    }
  }

  ordered.addAll(
    _dailyOrder([
      for (final track in newTracks) ?track[_Phase.check],
      for (final review in reserved) review.cloze,
    ], _epochDay(today)),
  );
  return ordered;
}

/// Days since 1970-01-01, the seed of the end-of-session order.
int _epochDay(LocalDate date) => LocalDate(1970, 1, 1).daysUntil(date);

/// A deterministic per-day permutation: rotate, then reverse every other
/// lap. The same day always yields the same order (so a reload resumes on
/// the same step) while consecutive days move the lemmas around, so the
/// check never ends on the same word twice in a row. Only small-integer
/// arithmetic is used, so the VM and the web build agree.
List<T> _dailyOrder<T>(List<T> items, int dayNumber) {
  if (items.length < 2) return [...items];
  final laps = dayNumber ~/ items.length;
  final offset = dayNumber % items.length;
  final rotated = [...items.skip(offset), ...items.take(offset)];
  return laps.isEven ? rotated : rotated.reversed.toList();
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
