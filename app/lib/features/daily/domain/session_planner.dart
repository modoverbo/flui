import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/daily/domain/session_plan.dart';
import 'package:flui/features/vocabulary/domain/confusability.dart';
import 'package:flui/features/vocabulary/domain/grade.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/features/vocabulary/domain/word_progress.dart';
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
  });

  /// - due reviews: progress with `next_due_on <= today`;
  /// - candidates: catalog words without progress, by `sort_order`;
  /// - recent introductions: words introduced on or after `today - 6`.
  factory derive({
    required List<Word> catalog,
    required List<WordProgress> progress,
    required LocalDate today,
  }) {
    final wordsById = {for (final word in catalog) word.id: word};
    final progressByWord = {for (final row in progress) row.wordId: row};
    final windowStart = today.addDays(-(SessionPlanner.interferenceDays - 1));
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
    );
  }

  final List<DueReview> dueReviews;
  final List<Word> candidates;
  final List<Word> recentIntroductions;
}

/// Session planner (docs/learning-method.md §1).
abstract final class SessionPlanner {
  static const reviewMinutes = 0.5;
  static const newWordMinutes = 7;
  static const maxNewWordsPerDay = 3;
  static const afianzarThreshold = 0.5;

  /// Confusable words are never introduced within this many days.
  static const interferenceDays = 7;

  /// Easy planned reviews moved to the front as a quick win.
  static const defaultWarmUpSize = 2;

  static SessionPlan plan({
    required int budgetMinutes,
    required LocalDate today,
    required List<DueReview> dueReviews,
    required List<Word> candidates,
    required List<Word> recentIntroductions,
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

    final picked = <Word>[];
    final sortedCandidates = [...candidates]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    for (final candidate in sortedCandidates) {
      if (picked.length >= newSlots) break;
      final blocked = [
        ...recentIntroductions,
        ...picked,
      ].any((other) => areConfusable(candidate, other));
      if (!blocked) picked.add(candidate);
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
    );
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
