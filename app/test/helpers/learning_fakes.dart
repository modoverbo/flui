import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/auth/data/fake_auth_repository.dart';
import 'package:flui/features/auth/domain/app_user.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/daily/data/fake_daily_session_repository.dart';
import 'package:flui/features/daily/presentation/providers/daily_providers.dart';
import 'package:flui/features/exercises/data/fake_exercise_attempt_repository.dart';
import 'package:flui/features/exercises/presentation/providers/exercise_providers.dart';
import 'package:flui/features/profile/data/fake_streak_repair_repository.dart';
import 'package:flui/features/profile/presentation/providers/profile_providers.dart';
import 'package:flui/features/vocabulary/data/fake/seed_content.dart';
import 'package:flui/features/vocabulary/data/fake_content_repository.dart';
import 'package:flui/features/vocabulary/data/fake_word_progress_repository.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/features/vocabulary/presentation/providers/vocabulary_providers.dart';
import 'package:flutter_riverpod/misc.dart';

/// In-memory learning backend for one signed-in user and a fixed clock
/// (Sunday 2026-09-13, 10:00).
final class LearningFakes {
  new({
    DateTime? now,
    List<Word> words = seedWords,
    String displayName = 'Ana',
    bool signedIn = true,
  }) : clock = FixedClock(now ?? DateTime(2026, 9, 13, 10)),
       auth = FakeAuthRepository(
         initialUser: signedIn
             ? AppUser(
                 id: 'user-1',
                 email: 'ana@correo.com',
                 displayName: displayName,
               )
             : null,
       ),
       content = FakeContentRepository(words: words) {
    progress = FakeWordProgressRepository(currentUserId: _userId);
    attempts = FakeExerciseAttemptRepository(
      currentUserId: _userId,
      now: clock.now,
    );
    sessions = FakeDailySessionRepository(currentUserId: _userId);
    repairs = FakeStreakRepairRepository(currentUserId: _userId);
  }

  final FixedClock clock;
  final FakeAuthRepository auth;
  final FakeContentRepository content;
  late final FakeWordProgressRepository progress;
  late final FakeExerciseAttemptRepository attempts;
  late final FakeDailySessionRepository sessions;
  late final FakeStreakRepairRepository repairs;

  static const userId = 'user-1';

  LocalDate get today => clock.localToday();

  String? _userId() => auth.currentUser?.id;

  List<Override> get overrides => [
    authRepositoryProvider.overrideWithValue(auth),
    contentRepositoryProvider.overrideWithValue(content),
    wordProgressRepositoryProvider.overrideWithValue(progress),
    exerciseAttemptRepositoryProvider.overrideWithValue(attempts),
    dailySessionRepositoryProvider.overrideWithValue(sessions),
    streakRepairRepositoryProvider.overrideWithValue(repairs),
    clockProvider.overrideWithValue(clock),
    shuffleRandomProvider.overrideWithValue(null),
  ];

  Future<void> dispose() => auth.dispose();
}

Word seedWord(String lemma) => seedWords.firstWhere((w) => w.lemma == lemma);
