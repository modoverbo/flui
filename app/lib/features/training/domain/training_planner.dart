import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/challenge.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/skill_profile.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:meta/meta.dart';

/// Why [TrainingPlanner.planDay] picked today's focus area (design part-3
/// §7): straight from the diagnosis profile before any other attempt
/// exists; shifted away from the profile's top area because it has
/// improved and another area needs work; rotated to the second-priority
/// area on the cycle's 4th day; or the ordinary top-opportunity default.
enum PlanReason { fromDiagnosis, shift, rotation, topOpportunity }

/// A previously completed non-diagnosis attempt, summarized for planning
/// (last-14-day window, caller-filtered).
@immutable
final class TrainingAttemptSummary {
  const new({
    required this.date,
    required this.context,
    required this.opportunityCodes,
    this.challengeId,
  });

  final LocalDate date;
  final TrainingContext context;
  final List<BehaviorCode> opportunityCodes;
  final String? challengeId;
}

/// Today's HOY goal (design part-3 §7): a focus area/behavior, a challenge
/// (`null` when the catalog has nothing left to offer — [isUnavailable]),
/// a round count derived from the budget, and up to 3 due review words
/// woven into the transfer step (never new words).
@immutable
final class DailyTrainingPlan {
  const new({
    required this.focusArea,
    required this.rounds,
    required this.wovenWordIds,
    required this.reason,
    this.focusBehavior,
    this.challenge,
  });

  final SkillArea focusArea;
  final BehaviorCode? focusBehavior;
  final Challenge? challenge;
  final int rounds;
  final List<String> wovenWordIds;
  final PlanReason reason;

  bool get isUnavailable => challenge == null;
}

/// Pure-Dart daily-goal selector (ADR-0003, design part-3 §7). No
/// Flutter/Riverpod/live-Supabase dependency: every input is a plain value
/// the caller already has (profile, recent attempts, published challenges,
/// due review word ids sourced from `SessionPlanner`, budget, today).
final class TrainingPlanner {
  const new();

  static const _rotationCycle = 4;
  static const _recentWindow = 6;
  static const _shiftMinOpportunities = 3;
  static const _usedWithinDays = 7;
  static const _maxWovenWords = 3;

  DailyTrainingPlan planDay({
    required SkillProfile profile,
    required List<TrainingAttemptSummary> recentAttempts,
    required List<Challenge> publishedChallenges,
    required List<String> dueReviewWordIds,
    required int budgetMinutes,
    required int difficulty,
    required LocalDate today,
  }) {
    final nonDiagnosis = [
      for (final attempt in recentAttempts)
        if (attempt.context != TrainingContext.diagnosis) attempt,
    ]..sort((a, b) => b.date.compareTo(a.date));

    final (focusArea, focusBehavior, reason) = _selectFocus(
      profile: profile,
      nonDiagnosis: nonDiagnosis,
    );

    final rounds = _roundsFor(budgetMinutes);
    final challenge = _pickChallenge(
      publishedChallenges: publishedChallenges,
      area: focusArea,
      difficulty: difficulty,
      recentAttempts: nonDiagnosis,
      today: today,
    );
    final woven = dueReviewWordIds
        .take(rounds.clamp(0, _maxWovenWords))
        .toList();

    return DailyTrainingPlan(
      focusArea: focusArea,
      focusBehavior: focusBehavior,
      challenge: challenge,
      rounds: rounds,
      wovenWordIds: woven,
      reason: reason,
    );
  }

  (SkillArea, BehaviorCode?, PlanReason) _selectFocus({
    required SkillProfile profile,
    required List<TrainingAttemptSummary> nonDiagnosis,
  }) {
    if (nonDiagnosis.isEmpty) {
      return (profile.topArea, profile.topBehavior, PlanReason.fromDiagnosis);
    }

    final recent = nonDiagnosis.take(_recentWindow).toList();
    final topBehaviorCount = profile.topBehavior == null
        ? 0
        : recent
              .expand((a) => a.opportunityCodes)
              .where((c) => c == profile.topBehavior)
              .length;

    final byArea = <SkillArea, int>{};
    for (final attempt in recent) {
      for (final code in attempt.opportunityCodes) {
        byArea[code.area] = (byArea[code.area] ?? 0) + 1;
      }
    }
    byArea.remove(profile.topArea);
    final shiftCandidates =
        byArea.entries.where((e) => e.value >= _shiftMinOpportunities).toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    if (topBehaviorCount <= 1 && shiftCandidates.isNotEmpty) {
      final area = shiftCandidates.first.key;
      final behavior = _mostFrequentInArea(recent, area);
      return (area, behavior, PlanReason.shift);
    }

    final onRotationDay =
        nonDiagnosis.length % _rotationCycle == _rotationCycle - 1;
    if (onRotationDay) {
      return (profile.secondArea, profile.secondBehavior, PlanReason.rotation);
    }
    return (profile.topArea, profile.topBehavior, PlanReason.topOpportunity);
  }

  BehaviorCode? _mostFrequentInArea(
    List<TrainingAttemptSummary> attempts,
    SkillArea area,
  ) {
    final counts = <BehaviorCode, int>{};
    for (final attempt in attempts) {
      for (final code in attempt.opportunityCodes) {
        if (code.area != area) continue;
        counts[code] = (counts[code] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  int _roundsFor(int budgetMinutes) => switch (budgetMinutes) {
    <= 5 => 1,
    10 => 2,
    _ => 3,
  };

  Challenge? _pickChallenge({
    required List<Challenge> publishedChallenges,
    required SkillArea area,
    required int difficulty,
    required List<TrainingAttemptSummary> recentAttempts,
    required LocalDate today,
  }) {
    final usedRecently = {
      for (final attempt in recentAttempts)
        if (attempt.challengeId != null &&
            today.daysUntil(attempt.date).abs() <= _usedWithinDays)
          attempt.challengeId,
    };

    final byArea = publishedChallenges
        .where((c) => c.purpose == ChallengePurpose.training)
        .where((c) => c.skill == area.skill)
        .toList();
    if (byArea.isEmpty) return null;

    Challenge? pick({
      required bool Function(Challenge) matchesDifficulty,
      required bool excludeUsed,
    }) {
      final candidates =
          byArea
              .where(matchesDifficulty)
              .where((c) => !excludeUsed || !usedRecently.contains(c.id))
              .toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return candidates.isEmpty ? null : candidates.first;
    }

    return pick(
          matchesDifficulty: (c) => c.difficulty == difficulty,
          excludeUsed: true,
        ) ??
        pick(
          matchesDifficulty: (c) => c.difficulty == difficulty,
          excludeUsed: false,
        ) ??
        pick(matchesDifficulty: (_) => true, excludeUsed: true) ??
        pick(matchesDifficulty: (_) => true, excludeUsed: false);
  }
}
