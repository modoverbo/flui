import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/auth/data/fake_auth_repository.dart';
import 'package:flui/features/auth/domain/app_user.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/daily/data/fake_daily_session_repository.dart';
import 'package:flui/features/daily/presentation/providers/daily_providers.dart';
import 'package:flui/features/diagnosis/data/fake_skill_profile_repository.dart';
import 'package:flui/features/diagnosis/presentation/providers/diagnosis_providers.dart';
import 'package:flui/features/onboarding/domain/onboarding_store.dart';
import 'package:flui/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:flui/features/profile/data/fake_streak_repair_repository.dart';
import 'package:flui/features/profile/presentation/providers/profile_providers.dart';
import 'package:flui/features/themes/data/fake/seed_themes.dart';
import 'package:flui/features/themes/data/fake_theme_repository.dart';
import 'package:flui/features/themes/domain/theme.dart';
import 'package:flui/features/themes/presentation/providers/theme_providers.dart';
import 'package:flui/features/training/data/fake_challenge_repository.dart';
import 'package:flui/features/training/data/fake_speaking_attempt_repository.dart';
import 'package:flui/features/training/presentation/providers/training_providers.dart';
import 'package:flui/features/vocabulary/data/fake_content_repository.dart';
import 'package:flui/features/vocabulary/data/fake_exercise_attempt_repository.dart';
import 'package:flui/features/vocabulary/data/fake_word_progress_repository.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/features/vocabulary/presentation/providers/exercise_providers.dart';
import 'package:flui/features/vocabulary/presentation/providers/vocabulary_providers.dart';
import 'package:flutter_riverpod/misc.dart';

/// In-memory learning backend for one signed-in user and a fixed clock
/// (Sunday 2026-09-13, 10:00).
///
/// Also registers the training-gym fakes ([challenges], [speakingAttempts],
/// [skillProfiles]) needed by the HOY/ENTRENAR/diagnosis flows. A caller
/// that needs its own instance of any of these 3 providers must override
/// them AFTER spreading [overrides], not add a duplicate — Riverpod throws
/// "Tried to override a provider twice" otherwise.
final class LearningFakes {
  new({
    DateTime? now,
    List<Word>? words,
    List<Theme>? themes,
    InMemoryOnboardingStore? onboarding,
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
       content = FakeContentRepository(words: words),
       themes = FakeThemeRepository(themes: themes ?? seedThemes),
       onboarding = onboarding ?? InMemoryOnboardingStore() {
    progress = FakeWordProgressRepository(currentUserId: _userId);
    attempts = FakeExerciseAttemptRepository(
      currentUserId: _userId,
      now: clock.now,
    );
    sessions = FakeDailySessionRepository(currentUserId: _userId);
    repairs = FakeStreakRepairRepository(currentUserId: _userId);
    challenges = FakeChallengeRepository();
    speakingAttempts = FakeSpeakingAttemptRepository(currentUserId: _userId);
    skillProfiles = FakeSkillProfileRepository(
      currentUserId: _userId,
      now: clock.now,
    );
  }

  final FixedClock clock;
  final FakeAuthRepository auth;
  final FakeContentRepository content;
  final FakeThemeRepository themes;
  final InMemoryOnboardingStore onboarding;
  late final FakeWordProgressRepository progress;
  late final FakeExerciseAttemptRepository attempts;
  late final FakeDailySessionRepository sessions;
  late final FakeStreakRepairRepository repairs;
  late FakeChallengeRepository challenges;
  late final FakeSpeakingAttemptRepository speakingAttempts;
  late final FakeSkillProfileRepository skillProfiles;

  static const userId = 'user-1';

  LocalDate get today => clock.localToday();

  String? _userId() => auth.currentUser?.id;

  List<Override> get overrides => [
    authRepositoryProvider.overrideWithValue(auth),
    contentRepositoryProvider.overrideWithValue(content),
    themeRepositoryProvider.overrideWithValue(themes),
    onboardingStoreProvider.overrideWithValue(onboarding),
    wordProgressRepositoryProvider.overrideWithValue(progress),
    exerciseAttemptRepositoryProvider.overrideWithValue(attempts),
    dailySessionRepositoryProvider.overrideWithValue(sessions),
    streakRepairRepositoryProvider.overrideWithValue(repairs),
    clockProvider.overrideWithValue(clock),
    shuffleRandomProvider.overrideWithValue(null),
    challengeRepositoryProvider.overrideWithValue(challenges),
    speakingAttemptRepositoryProvider.overrideWithValue(speakingAttempts),
    skillProfileRepositoryProvider.overrideWithValue(skillProfiles),
  ];

  Future<void> dispose() => auth.dispose();
}

/// A seed word by lemma, with its themes and semantic set.
Word seedWord(String lemma) =>
    seedWordsWithThemes.firstWhere((w) => w.lemma == lemma);

/// A seed theme by slug.
Theme seedTheme(String slug) =>
    seedThemes.firstWhere((theme) => theme.slug == slug);
