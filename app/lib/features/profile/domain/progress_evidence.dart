import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/polarity.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/speaking_attempt.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:meta/meta.dart';

/// The direction a [SkillTrend] states — always paired with
/// [SkillTrendComputed.evidence], the specific behaviors that justify it.
/// Never a numeric confidence or aggregate score (spec `progress`,
/// `training-engine`).
enum TrendDirection { improving, steady, needsWork }

/// One specific behavior observed in the "before" or "now" window that
/// justifies a [SkillTrend]'s direction — never a number.
@immutable
final class SkillTrendEvidence {
  const new({
    required this.attemptId,
    required this.code,
    required this.polarity,
  });

  /// The `speaking_attempts.id` this behavior was observed in.
  final String attemptId;
  final BehaviorCode code;
  final Polarity polarity;

  @override
  bool operator ==(Object other) =>
      other is SkillTrendEvidence &&
      other.attemptId == attemptId &&
      other.code == code &&
      other.polarity == polarity;

  @override
  int get hashCode => Object.hash(attemptId, code, polarity);

  // attemptId is a traceability key, not user-facing text, and is
  // deliberately left out of toString() so a numeric-looking id (e.g.
  // "attempt-42") can never trip the no-number contract
  // (progress_evidence_test.dart).
  @override
  String toString() => 'SkillTrendEvidence(${code.wireCode}, $polarity)';
}

/// A per-[SkillArea] trend between a "before" and a "now" attempt window
/// (spec `progress`: per-skill trend breakdowns), or an explicit statement
/// that too few attempts exist in [area] to state one honestly.
@immutable
sealed class SkillTrend {
  const new({required this.area});

  final SkillArea area;
}

/// [direction] plus the specific behaviors that justify it.
final class SkillTrendComputed extends SkillTrend {
  const new({
    required super.area,
    required this.direction,
    required this.evidence,
  });

  final TrendDirection direction;

  /// Never empty when this variant is returned — [ProgressEvidence.compute]
  /// only produces a [SkillTrendComputed] once [area] has at least
  /// [ProgressEvidence.minimumEvidenceCount] observations, so there is
  /// always at least one behavior to cite.
  final List<SkillTrendEvidence> evidence;

  @override
  String toString() =>
      'SkillTrendComputed($area, $direction, [${evidence.join(', ')}])';
}

/// Fewer than [ProgressEvidence.minimumEvidenceCount] observations exist in
/// [area] across both windows — a direction is never fabricated from too
/// little evidence.
final class SkillTrendInsufficientEvidence extends SkillTrend {
  const new({required super.area});

  @override
  String toString() => 'SkillTrendInsufficientEvidence($area)';
}

/// Whether a [BeforeNowComparison] is anchored on a completed 30-day retake
/// (formal) or, absent one, on the most recent training attempts
/// (indicative — decision #429: never presented as a formal retake
/// comparison).
enum BeforeNowLabel { formal, indicative }

/// [ProgressEvidence]'s top-level before→now comparison: either a labeled
/// set of per-area [SkillTrend]s, or an explicit statement that there is
/// not enough evidence on at least one side to compare at all.
@immutable
sealed class BeforeNow {
  const new();
}

/// One [SkillTrend] per [SkillArea] (in [SkillArea.values] order), labeled
/// [label] depending on whether "now" is a completed retake or a recent-
/// attempts window (decision #429).
final class BeforeNowComparison extends BeforeNow {
  const new({required this.label, required this.trends});

  final BeforeNowLabel label;
  final List<SkillTrend> trends;

  @override
  String toString() => 'BeforeNowComparison($label, [${trends.join(', ')}])';
}

/// There is no baseline, no "now" window, or both (after excluding contexts
/// that never count, design D33/D37) — nothing to compare, so no
/// comparison is fabricated.
final class BeforeNowInsufficientEvidence extends BeforeNow {
  const new();

  @override
  String toString() => 'BeforeNowInsufficientEvidence()';
}

/// The pure evidence behind the PROGRESO tab (spec `progress`, design
/// part-3 §5): a before→now comparison, always explainable from specific
/// recorded behaviors, never a numeric/universal score.
@immutable
final class ProgressEvidence {
  const new({required this.beforeNow});

  /// Computes the before→now comparison from already-fetched attempts.
  ///
  /// [baselineAttempts] is the diagnosis baseline's attempts (the "before"
  /// window); [nowAttempts] is either a completed retake's attempts or the
  /// most recent training attempts (the "now" window) — [isRetake] states
  /// which, and drives [BeforeNowComparison.label]. Neither list is
  /// date-filtered here beyond context exclusion: callers already scope
  /// [nowAttempts] to the relevant window (a retake session, or the last 14
  /// days) before calling this.
  factory compute({
    required List<SpeakingAttempt> baselineAttempts,
    required List<SpeakingAttempt> nowAttempts,
    required bool isRetake,
  }) {
    final before = _eligible(baselineAttempts);
    final now = _eligible(nowAttempts);
    if (before.isEmpty || now.isEmpty) {
      return const ProgressEvidence(beforeNow: BeforeNowInsufficientEvidence());
    }

    return ProgressEvidence(
      beforeNow: BeforeNowComparison(
        label: isRetake ? BeforeNowLabel.formal : BeforeNowLabel.indicative,
        trends: [
          for (final area in SkillArea.values) _trendFor(area, before, now),
        ],
      ),
    );
  }

  final BeforeNow beforeNow;

  /// The fewest total observations (opportunity + strength combined) a
  /// [SkillArea] needs, across both windows together, before
  /// [ProgressEvidence.compute] states a direction for it — one observation
  /// is an anecdote, not a trend.
  static const minimumEvidenceCount = 2;

  /// Contexts [ProgressEvidence.compute] never counts as evidence: quick
  /// practice is excluded from progression everywhere (design D33), and
  /// word-exercise answers are never persisted as `speaking_attempts` rows
  /// at all (design D37) — filtered here defensively all the same, so a
  /// misrouted row can never inflate a trend.
  static const Set<TrainingContext> _excludedContexts = {
    TrainingContext.quick,
    TrainingContext.word,
  };

  static List<SpeakingAttempt> _eligible(List<SpeakingAttempt> attempts) => [
    for (final attempt in attempts)
      if (!_excludedContexts.contains(attempt.context)) attempt,
  ];

  static SkillTrend _trendFor(
    SkillArea area,
    List<SpeakingAttempt> before,
    List<SpeakingAttempt> now,
  ) {
    final beforeByCode = _attemptIdsByCode(before, area);
    final nowByCode = _attemptIdsByCode(now, area);
    final total =
        beforeByCode.values.fold(0, (sum, ids) => sum + ids.length) +
        nowByCode.values.fold(0, (sum, ids) => sum + ids.length);
    if (total < minimumEvidenceCount) {
      return SkillTrendInsufficientEvidence(area: area);
    }

    final nowHasOpportunity = nowByCode.keys.any(
      (code) => code.polarity == Polarity.opportunity,
    );
    final beforeHasOpportunity = beforeByCode.keys.any(
      (code) => code.polarity == Polarity.opportunity,
    );
    final direction = nowHasOpportunity
        ? TrendDirection.needsWork
        : beforeHasOpportunity
        ? TrendDirection.improving
        : TrendDirection.steady;

    return SkillTrendComputed(
      area: area,
      direction: direction,
      evidence: [
        for (final code in BehaviorCode.values)
          if (code.area == area &&
              (nowByCode.containsKey(code) || beforeByCode.containsKey(code)))
            SkillTrendEvidence(
              // "Now" evidence is the freshest and takes priority; only an
              // opportunity/strength that never recurred in "now" falls
              // back to citing where it was seen "before".
              attemptId: (nowByCode[code] ?? beforeByCode[code])!.first,
              code: code,
              polarity: code.polarity,
            ),
      ],
    );
  }

  /// Maps each [BehaviorCode] observed in [area] across [attempts] to the
  /// attempt ids that showed it, in [attempts] order.
  static Map<BehaviorCode, List<String>> _attemptIdsByCode(
    List<SpeakingAttempt> attempts,
    SkillArea area,
  ) {
    final result = <BehaviorCode, List<String>>{};
    for (final attempt in attempts) {
      for (final observation in attempt.observations) {
        if (observation.area != area) continue;
        result.putIfAbsent(observation.code, () => []).add(attempt.id);
      }
    }
    return result;
  }

  @override
  String toString() => 'ProgressEvidence($beforeNow)';
}
