import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:flui/features/daily/presentation/providers/daily_providers.dart';
import 'package:flui/features/profile/domain/streak_calculator.dart';
import 'package:flui/features/profile/presentation/providers/profile_providers.dart';
import 'package:flui/features/vocabulary/domain/exercises/exercise_attempt.dart';
import 'package:flui/features/vocabulary/domain/word_progress.dart';
import 'package:flui/features/vocabulary/presentation/providers/exercise_providers.dart';
import 'package:flui/features/vocabulary/presentation/providers/vocabulary_providers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'learning_data_controller.freezed.dart';
part 'learning_data_controller.g.dart';

/// Everything the app knows about one user's learning.
@freezed
abstract class LearningData with _$LearningData {
  const factory({
    @Default(<WordProgress>[]) List<WordProgress> progress,
    @Default(<ExerciseAttempt>[]) List<ExerciseAttempt> attempts,
    @Default(<DailySession>[]) List<DailySession> sessions,
    @Default(<LocalDate>[]) List<LocalDate> repairs,
  }) = _LearningData;

  const new _();

  WordProgress? progressOf(String wordId) =>
      progress.where((row) => row.wordId == wordId).firstOrNull;

  DailySession? sessionOn(LocalDate date) =>
      sessions.where((session) => session.localDate == date).firstOrNull;

  /// The most recent session on or before [date].
  DailySession? latestSessionUntil(LocalDate date) {
    DailySession? latest;
    for (final session in sessions) {
      if (session.localDate.isAfter(date)) continue;
      if (latest == null || session.localDate.isAfter(latest.localDate)) {
        latest = session;
      }
    }
    return latest;
  }

  List<ExerciseAttempt> attemptsOn(LocalDate date) => [
    for (final attempt in attempts)
      if (attempt.localDate == date) attempt,
  ];

  Set<LocalDate> get activityDates => StreakCalculator.activeDates(
    attemptDates: attempts.map((attempt) => attempt.localDate),
    completedSessionDates: [
      for (final session in sessions)
        if (session.isCompleted) session.localDate,
    ],
    repairedDates: const [],
  );

  Set<LocalDate> get activeDates => {...activityDates, ...repairs};
}

/// Loads and writes the learning tables of one user. Keyed by user id so a
/// new session never sees the previous user's data. Writes go to the
/// repository first; the state changes only when they succeed.
@Riverpod(keepAlive: true)
class LearningDataController extends _$LearningDataController {
  /// How far back answers are read. `exercise_attempts` grows by one row per
  /// answer for ever; this window still covers today's resume, the rolling
  /// precision window and the longest review interval with room to spare.
  /// Active days older than this survive through `daily_sessions`.
  static const attemptWindowDays = 120;

  @override
  Future<LearningData> build(String userId) async {
    final since = ref
        .watch(clockProvider)
        .localToday()
        .addDays(-attemptWindowDays);
    final results = await (
      ref.watch(wordProgressRepositoryProvider).fetchProgress(),
      ref.watch(exerciseAttemptRepositoryProvider).fetchAttempts(since: since),
      ref.watch(dailySessionRepositoryProvider).fetchSessions(),
      ref.watch(streakRepairRepositoryProvider).fetchRepairs(),
    ).wait;
    return LearningData(
      progress: _unwrap(results.$1),
      attempts: _unwrap(results.$2),
      sessions: _unwrap(results.$3),
      repairs: _unwrap(results.$4),
    );
  }

  Future<Result<void>> saveProgress(WordProgress progress) => _write(
    () => ref.read(wordProgressRepositoryProvider).saveProgress(progress),
    (data) => data.copyWith(
      progress: [
        for (final row in data.progress)
          if (row.wordId != progress.wordId) row,
        progress,
      ],
    ),
  );

  Future<Result<void>> recordAttempt(ExerciseAttempt attempt) {
    final stored = attempt.createdAt == null
        ? attempt.copyWith(createdAt: DateTime.now())
        : attempt;
    return _write(
      () => ref.read(exerciseAttemptRepositoryProvider).recordAttempt(attempt),
      (data) => data.copyWith(attempts: [...data.attempts, stored]),
    );
  }

  Future<Result<void>> saveSession(DailySession session) => _write(
    () => ref.read(dailySessionRepositoryProvider).saveSession(session),
    (data) {
      final existing = data.sessionOn(session.localDate);
      return data.copyWith(
        sessions: [
          for (final row in data.sessions)
            if (row.localDate != session.localDate) row,
          session.copyWith(completedAt: existing?.completedAt),
        ]..sort((a, b) => a.localDate.compareTo(b.localDate)),
      );
    },
  );

  Future<Result<void>> completeSession(LocalDate date, DateTime completedAt) =>
      _write(
        () => ref
            .read(dailySessionRepositoryProvider)
            .completeSession(localDate: date, completedAt: completedAt),
        (data) => data.copyWith(
          sessions: [
            for (final row in data.sessions)
              if (row.localDate == date)
                row.copyWith(completedAt: completedAt)
              else
                row,
          ],
        ),
      );

  Future<Result<void>> repairDay(LocalDate date) => _write(
    () => ref.read(streakRepairRepositoryProvider).repairDay(date),
    (data) => data.copyWith(repairs: {...data.repairs, date}.toList()..sort()),
  );

  Future<Result<void>> _write(
    Future<Result<void>> Function() write,
    LearningData Function(LearningData data) apply,
  ) async {
    final result = await write();
    if (!ref.mounted || !result.isOk) return result;
    final current = state.value;
    if (current != null) state = AsyncData(apply(current));
    return result;
  }

  static T _unwrap<T>(Result<T> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
}

/// Learning data of the signed-in user.
@riverpod
Future<LearningData> currentLearningData(Ref ref) async {
  final user = await ref.watch(authUserProvider.future);
  if (user == null) return const LearningData();
  return await ref.watch(learningDataControllerProvider(user.id).future);
}
