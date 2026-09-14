import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:flui/features/daily/domain/session_plan.dart';
import 'package:flui/features/daily/domain/session_planner.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:meta/meta.dart';

/// How a saved day turned out against the theme it was planned with.
///
/// `daily_sessions` stores the plan, never the reasoning behind it, and
/// re-planning later would answer about a different day: the word introduced
/// this morning is no longer a candidate this afternoon. So the reason is
/// reconstructed from the stored row, exactly like [EmptyPlanReason] already
/// is in `today_overview.dart`.
@immutable
final class ThemeOutcome {
  const new({
    this.fallback,
    this.otherThemeId,
    this.recombinationWordIds = const [],
  });

  factory of({
    required DailySession session,
    required Map<String, Word> wordsById,
    required List<Word> practiceWords,
    required List<String> neighbourThemeIds,
  }) {
    final themeId = session.themeId;
    if (themeId == null) return onTheme;

    final planned = [for (final id in session.plannedWordIds) ?wordsById[id]];
    if (planned.isEmpty) {
      // (a) No new word: the theme is recombined over what the user has.
      final themed = [
        for (final word in practiceWords)
          if (word.themeIds.contains(themeId)) word.id,
      ];
      return themed.isEmpty
          ? onTheme
          : ThemeOutcome(
              fallback: ThemeFallback.themedPractice,
              recombinationWordIds: themed
                  .take(SessionPlanner.maxNewWordsPerDay)
                  .toList(),
            );
    }

    final substituted = [
      for (final word in planned)
        if (!word.themeIds.contains(themeId)) word,
    ].firstOrNull;
    if (substituted == null) return onTheme;

    // (b) A neighbour lent it, or (c) it came from the catalog at large.
    final neighbour = substituted.themeIds
        .where(neighbourThemeIds.contains)
        .firstOrNull;
    return ThemeOutcome(
      fallback: neighbour == null
          ? ThemeFallback.globalCatalog
          : ThemeFallback.neighbourTheme,
      otherThemeId: neighbour ?? substituted.themeIds.firstOrNull,
    );
  }

  /// The day came from the theme the user asked for.
  static const onTheme = ThemeOutcome();

  /// `null` when the day came from the chosen theme.
  final ThemeFallback? fallback;

  /// The theme the substituted word does come from, when it has one.
  final String? otherThemeId;

  /// Words already in `practica` that today recombines instead of
  /// introducing something new. Never a review: the ladder is untouched.
  final List<String> recombinationWordIds;
}
