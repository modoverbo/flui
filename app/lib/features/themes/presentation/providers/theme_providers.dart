import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/features/daily/presentation/providers/learning_data_controller.dart';
import 'package:flui/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:flui/features/themes/domain/theme.dart';
import 'package:flui/features/themes/domain/theme_recommender.dart';
import 'package:flui/features/themes/domain/theme_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_providers.g.dart';

/// Overridden in `bootstrap.dart` (Supabase or fake) and in tests.
@Riverpod(keepAlive: true)
ThemeRepository themeRepository(Ref ref) {
  throw UnimplementedError('themeRepositoryProvider must be overridden.');
}

/// The published taxonomy, by `sort_order`.
@Riverpod(keepAlive: true)
Future<List<Theme>> themes(Ref ref) async {
  final result = await ref.watch(themeRepositoryProvider).fetchThemes();
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
}

/// Themes by id, for naming the one a day was planned with.
@Riverpod(keepAlive: true)
Future<Map<String, Theme>> themesById(Ref ref) async {
  final all = await ref.watch(themesProvider.future);
  return {for (final theme in all) theme.id: theme};
}

/// The themes today's picker may offer: the ones with content behind them.
@Riverpod(keepAlive: true)
Future<List<Theme>> offeredThemes(Ref ref) async {
  final all = await ref.watch(themesProvider.future);
  return [
    for (final theme in all)
      if (theme.isOffered) theme,
  ];
}

/// The three cards the daily prompt opens on, ranked from the two pre-signup
/// answers (Patall 2008: choice helps most at 2-4 options).
@Riverpod(keepAlive: true)
Future<List<Theme>> recommendedThemes(Ref ref) async {
  final offered = await ref.watch(offeredThemesProvider.future);
  final answers = await ref.watch(onboardingAnswersControllerProvider.future);
  return ThemeRecommender.recommend(themes: offered, answers: answers);
}

/// "Tus temas": the themes the user actually chose lately, most recent first,
/// capped at [ThemeRecommender.maxUserThemes]. A shortlist, never a history.
@riverpod
Future<List<Theme>> recentThemes(Ref ref) async {
  final data = await ref.watch(currentLearningDataProvider.future);
  final byId = await ref.watch(themesByIdProvider.future);
  final sessions = [...data.sessions]
    ..sort((a, b) => b.localDate.compareTo(a.localDate));

  final seen = <String>{};
  final recent = <Theme>[];
  for (final session in sessions) {
    final id = session.themeId;
    if (id == null || !seen.add(id)) continue;
    if (byId[id] case final theme? when theme.isOffered) recent.add(theme);
    if (recent.length >= ThemeRecommender.maxUserThemes) break;
  }
  return recent;
}

/// Yesterday's theme if there was one, else the best recommendation, else
/// none. Changing it any day is free: there is no minimum streak on a theme.
@riverpod
Future<String?> preselectedThemeId(Ref ref) async {
  final data = await ref.watch(currentLearningDataProvider.future);
  final today = ref.watch(clockProvider).localToday();
  final byId = await ref.watch(themesByIdProvider.future);

  final previous = data.latestSessionUntil(today)?.themeId;
  if (previous != null && byId[previous]?.isOffered == true) return previous;

  final recommended = await ref.watch(recommendedThemesProvider.future);
  return recommended.firstOrNull?.id;
}

/// The theme chosen for today, if the day is already planned.
@riverpod
Future<Theme?> todayTheme(Ref ref) async {
  final data = await ref.watch(currentLearningDataProvider.future);
  final today = ref.watch(clockProvider).localToday();
  final id = data.sessionOn(today)?.themeId;
  if (id == null) return null;
  return (await ref.watch(themesByIdProvider.future))[id];
}
