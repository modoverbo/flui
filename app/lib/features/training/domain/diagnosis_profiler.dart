import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/observation.dart';
import 'package:flui/features/training/domain/polarity.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/skill_profile.dart';
import 'package:meta/meta.dart';

/// One analyzed diagnosis attempt: exactly one per slot (1-3).
@immutable
final class DiagnosisAttempt {
  const new({
    required this.attemptId,
    required this.slot,
    required this.observations,
  });

  final String attemptId;
  final int slot;
  final List<Observation> observations;
}

/// The outcome of [DiagnosisProfiler.profile]: either a computed
/// [SkillProfile], or the slots still missing an analyzed attempt.
sealed class DiagnosisProfileResult {
  const new();
}

final class DiagnosisProfileComplete extends DiagnosisProfileResult {
  const new(this.profile);

  final SkillProfile profile;
}

final class DiagnosisProfileIncomplete extends DiagnosisProfileResult {
  const new(this.missingSlots);

  /// Ascending, a subset of 1-3.
  final List<int> missingSlots;
}

/// Turns the 3 analyzed diagnosis attempts into a [SkillProfile] (design
/// part-3 §7): ranks areas by how many attempts showed an opportunity in
/// them, then by total opportunity count, then by a fixed priority order
/// (thinking > language > fluency > voice) so ties are deterministic.
final class DiagnosisProfiler {
  const new();

  static const totalSlots = 3;

  static const List<SkillArea> _areaPriority = [
    SkillArea.thinking,
    SkillArea.language,
    SkillArea.fluency,
    SkillArea.voice,
  ];

  DiagnosisProfileResult profile(List<DiagnosisAttempt> attempts) {
    final missingSlots = [
      for (var slot = 1; slot <= totalSlots; slot++)
        if (!attempts.any((a) => a.slot == slot)) slot,
    ];
    if (missingSlots.isNotEmpty) {
      return DiagnosisProfileIncomplete(missingSlots);
    }

    final opportunitiesByArea = <SkillArea, List<Observation>>{};
    for (final attempt in attempts) {
      for (final obs in attempt.observations) {
        if (obs.polarity != Polarity.opportunity) continue;
        opportunitiesByArea.putIfAbsent(obs.area, () => []).add(obs);
      }
    }

    final rankedAreas = [...SkillArea.values]
      ..sort((a, b) => _compareAreas(a, b, attempts, opportunitiesByArea));
    final topArea = rankedAreas[0];
    final secondArea = rankedAreas[1];

    final strengthsByArea = <SkillArea, List<BehaviorCode>>{};
    for (final attempt in attempts) {
      for (final obs in attempt.observations) {
        if (obs.polarity != Polarity.strength) continue;
        if (obs.area == topArea || obs.area == secondArea) continue;
        strengthsByArea.putIfAbsent(obs.area, () => []).add(obs.code);
      }
    }
    final strengths = <BehaviorCode>[
      for (final area in SkillArea.values)
        if ((strengthsByArea[area] ?? const <BehaviorCode>[]).isNotEmpty)
          _mostFrequent(strengthsByArea[area]!),
    ];

    final topBehavior = _mostFrequentInArea(opportunitiesByArea, topArea);
    final secondBehavior = _mostFrequentInArea(opportunitiesByArea, secondArea);
    final evidence = [
      for (final attempt in attempts)
        for (final obs in attempt.observations)
          if (obs.code == topBehavior || obs.code == secondBehavior)
            DiagnosisEvidence(attemptId: attempt.attemptId, code: obs.code),
    ];

    return DiagnosisProfileComplete(
      SkillProfile(
        topArea: topArea,
        topBehavior: topBehavior,
        secondArea: secondArea,
        secondBehavior: secondBehavior,
        strengths: strengths,
        evidence: evidence,
      ),
    );
  }

  int _compareAreas(
    SkillArea a,
    SkillArea b,
    List<DiagnosisAttempt> attempts,
    Map<SkillArea, List<Observation>> opportunitiesByArea,
  ) {
    final byAttempts = _attemptsWithOpportunity(
      attempts,
      b,
    ).compareTo(_attemptsWithOpportunity(attempts, a));
    if (byAttempts != 0) return byAttempts;
    final byTotal = (opportunitiesByArea[b]?.length ?? 0).compareTo(
      opportunitiesByArea[a]?.length ?? 0,
    );
    if (byTotal != 0) return byTotal;
    return _areaPriority.indexOf(a).compareTo(_areaPriority.indexOf(b));
  }

  int _attemptsWithOpportunity(
    List<DiagnosisAttempt> attempts,
    SkillArea area,
  ) => attempts
      .where(
        (a) => a.observations.any(
          (o) => o.polarity == Polarity.opportunity && o.area == area,
        ),
      )
      .length;

  BehaviorCode? _mostFrequentInArea(
    Map<SkillArea, List<Observation>> byArea,
    SkillArea area,
  ) {
    final codes = byArea[area]?.map((o) => o.code).toList();
    if (codes == null || codes.isEmpty) return null;
    return _mostFrequent(codes);
  }

  BehaviorCode _mostFrequent(List<BehaviorCode> codes) {
    final counts = <BehaviorCode, int>{};
    for (final code in codes) {
      counts[code] = (counts[code] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}
