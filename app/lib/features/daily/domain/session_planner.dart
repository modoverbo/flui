import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/daily/domain/session_plan.dart';
import 'package:flui/features/themes/domain/theme.dart';
import 'package:flui/features/themes/domain/theme_neighbours.dart';
import 'package:flui/features/vocabulary/domain/confusability.dart';
import 'package:flui/features/vocabulary/domain/grade.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/features/vocabulary/domain/word_progress.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';
import 'package:meta/meta.dart';

/// A due review with the catalog order of its word.
@immutable
final class DueReview {
  const new({required this.progress, required this.sortOrder});

  final WordProgress progress;
  final int sortOrder;

  String get wordId => progress.wordId;
}

/// Planner inputs derived from the catalog and the user's progress.
@immutable
final class SessionPlanInputs {
  const new({
    required this.dueReviews,
    required this.candidates,
    required this.recentIntroductions,
    this.practiceWords = const [],
    this.neighbourThemeIds = const [],
  });

  /// - due reviews: progress with `next_due_on <= today`;
  /// - candidates: catalog words without progress, by `sort_order`;
  /// - recent introductions: words introduced on or after `today - 6`;
  /// - practice words: words already in `practica`, for the themed
  ///   recombination step of the cascade;
  /// - neighbour themes: the themes closest to [themeId] by shared words.
  ///
  /// [themes] and [themeId] only ever affect the last two lists. The due
  /// queue and the candidate pool are derived exactly as they were before
  /// themes existed.
  factory derive({
    required List<Word> catalog,
    required List<WordProgress> progress,
    required LocalDate today,
    List<Theme> themes = const [],
    String? themeId,
  }) {
    final wordsById = {for (final word in catalog) word.id: word};
    final progressByWord = {for (final row in progress) row.wordId: row};
    final windowStart = today.addDays(-(SessionPlanner.interferenceDays - 1));
    final theme = themeId == null
        ? null
        : themes.where((value) => value.id == themeId).firstOrNull;
    return SessionPlanInputs(
      dueReviews: [
        for (final row in progress)
          if (row.isDueOn(today) && wordsById[row.wordId] != null)
            DueReview(
              progress: row,
              sortOrder: wordsById[row.wordId]!.sortOrder,
            ),
      ],
      candidates: [
        for (final word in catalog)
          if (!progressByWord.containsKey(word.id)) word,
      ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      recentIntroductions: [
        for (final row in progress)
          if (!row.introducedOn.isBefore(windowStart) &&
              wordsById[row.wordId] != null)
            wordsById[row.wordId]!,
      ],
      practiceWords: themeId == null
          ? const []
          : ([
              for (final row in progress)
                if (row.state == WordState.practica &&
                    wordsById[row.wordId] != null)
                  wordsById[row.wordId]!,
            ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder))),
      neighbourThemeIds: theme == null
          ? const []
          : ThemeNeighbours.nearestIds(
              theme: theme,
              themes: themes,
              catalog: catalog,
            ),
    );
  }

  final List<DueReview> dueReviews;
  final List<Word> candidates;
  final List<Word> recentIntroductions;

  /// Words the user is consolidating, oldest in the catalog first.
  final List<Word> practiceWords;

  /// Themes nearest to the chosen one, closest first.
  final List<String> neighbourThemeIds;
}

/// Session planner (docs/learning-method.md §1).
abstract final class SessionPlanner {
  static const reviewMinutes = 0.5;
  static const newWordMinutes = 7;
  static const maxNewWordsPerDay = 3;
  static const afianzarThreshold = 0.5;

  /// Confusable words, and words of one semantic set, are never introduced
  /// within this many days (§7).
  static const interferenceDays = 7;

  /// Easy planned reviews moved to the front as a quick win.
  static const defaultWarmUpSize = 2;

  /// Plans one day.
  ///
  /// [themeId] filters the **new-word candidate pool and nothing else**. It
  /// never changes [dueReviews], the number of new slots, the "Hoy toca
  /// afianzar" threshold or the ladder: a theme decides what you meet next,
  /// never when you see again what you already met.
  static SessionPlan plan({
    required int budgetMinutes,
    required LocalDate today,
    required List<DueReview> dueReviews,
    required List<Word> candidates,
    required List<Word> recentIntroductions,
    String? themeId,
    List<Word> practiceWords = const [],
    List<String> neighbourThemeIds = const [],
    int warmUpSize = defaultWarmUpSize,
  }) {
    final ordered = orderReviews(dueReviews);
    final capacity = (budgetMinutes / reviewMinutes).floor();
    final planned = ordered.take(capacity).toList();
    final reviewTime = planned.length * reviewMinutes;

    var newSlots = budgetMinutes <= 5
        ? 0
        : ((budgetMinutes - reviewTime) / newWordMinutes).floor().clamp(
            0,
            maxNewWordsPerDay,
          );
    final afianzar = isAfianzar(
      minutes: budgetMinutes,
      reviewCount: planned.length,
    );
    if (afianzar && newSlots > 1) newSlots = 1;

    final sortedCandidates = [...candidates]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final picked = <Word>[];
    final recombination = <Word>[];
    ThemeFallback? fallback;
    String? fallbackThemeId;

    if (themeId == null) {
      _fill(picked, sortedCandidates, newSlots, recentIntroductions);
    } else {
      _fill(
        picked,
        _inTheme(sortedCandidates, themeId),
        newSlots,
        recentIntroductions,
      );

      // The cascade runs only when the theme itself had nothing to give.
      if (picked.isEmpty && newSlots > 0) {
        // (a) Recombine what the user already has from this theme. One item
        // per slot the theme could not fill.
        recombination.addAll(_inTheme(practiceWords, themeId).take(newSlots));
        if (recombination.isNotEmpty) {
          fallback = ThemeFallback.themedPractice;
        } else {
          // (b) The nearest theme by shared-word overlap.
          for (final neighbour in neighbourThemeIds) {
            _fill(
              picked,
              _inTheme(sortedCandidates, neighbour),
              newSlots,
              recentIntroductions,
            );
            if (picked.isNotEmpty) {
              fallback = ThemeFallback.neighbourTheme;
              fallbackThemeId = neighbour;
              break;
            }
          }
          // (c) The global next word, announced for what it is.
          if (picked.isEmpty) {
            _fill(picked, sortedCandidates, newSlots, recentIntroductions);
            if (picked.isNotEmpty) {
              fallback = ThemeFallback.globalCatalog;
              fallbackThemeId = picked.first.themeIds.firstOrNull;
            }
          }
        }
      }
    }

    final warmUp = _warmUp(planned, warmUpSize);
    return SessionPlan(
      budgetMinutes: budgetMinutes,
      reviewWordIds: [
        ...warmUp.map((review) => review.wordId),
        for (final review in planned)
          if (!warmUp.contains(review)) review.wordId,
      ],
      newWordIds: [for (final word in picked) word.id],
      afianzar: afianzar,
      warmUpCount: warmUp.length,
      themeId: themeId,
      recombinationWordIds: [for (final word in recombination) word.id],
      themeFallback: fallback,
      fallbackThemeId: fallbackThemeId,
      emptyReason: planned.isEmpty && picked.isEmpty && recombination.isEmpty
          ? emptyReasonFor(
              candidatesLeft: sortedCandidates.isNotEmpty,
              newSlots: newSlots,
            )
          : null,
    );
  }

  /// Why an empty day is empty (see [EmptyPlanReason]).
  static EmptyPlanReason emptyReasonFor({
    required bool candidatesLeft,
    required int newSlots,
  }) {
    if (!candidatesLeft) return EmptyPlanReason.noCandidatesLeft;
    if (newSlots == 0) return EmptyPlanReason.budgetTooSmall;
    return EmptyPlanReason.allReviewsDone;
  }

  /// Oldest `next_due_on` first, then lower `ladder_step`, then `sort_order`.
  static List<DueReview> orderReviews(List<DueReview> reviews) =>
      [...reviews]..sort((a, b) {
        final byDue = _dueOf(a).compareTo(_dueOf(b));
        if (byDue != 0) return byDue;
        final byStep = a.progress.ladderStep.compareTo(b.progress.ladderStep);
        if (byStep != 0) return byStep;
        return a.sortOrder.compareTo(b.sortOrder);
      });

  /// "Hoy toca afianzar": review time above half of the budget.
  static bool isAfianzar({required int minutes, required int reviewCount}) =>
      reviewCount * reviewMinutes > afianzarThreshold * minutes;

  /// Walks [pool] in order and takes what neither the last 7 days nor the
  /// words already picked today interfere with (§7), up to [slots].
  static void _fill(
    List<Word> picked,
    Iterable<Word> pool,
    int slots,
    List<Word> recentIntroductions,
  ) {
    for (final candidate in pool) {
      if (picked.length >= slots) return;
      final blocked = [
        ...recentIntroductions,
        ...picked,
      ].any((other) => interferes(candidate, other));
      if (!blocked) picked.add(candidate);
    }
  }

  static Iterable<Word> _inTheme(Iterable<Word> words, String themeId) =>
      words.where((word) => word.themeIds.contains(themeId));

  /// Up to [size] planned reviews whose last review was first-try correct,
  /// highest ladder step first. They are part of the due reviews, never
  /// extra items, so the budget and the ladder stay exact.
  static List<DueReview> _warmUp(List<DueReview> planned, int size) {
    if (size <= 0) return const [];
    final easy = [
      for (final review in planned)
        if (review.progress.lastGrade == Grade.good) review,
    ]..sort((a, b) => b.progress.ladderStep.compareTo(a.progress.ladderStep));
    return easy.take(size).toList();
  }

  static LocalDate _dueOf(DueReview review) =>
      review.progress.nextDueOn ?? review.progress.introducedOn;
}
