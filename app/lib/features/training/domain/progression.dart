import 'package:flui/features/training/domain/attempt_comparison.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:meta/meta.dart';

/// Whether one completed loop showed improvement on its focus behavior:
/// present in the first attempt, resolved (absent) by the repeat (design
/// part-3 §7 `Progression.levelFor`).
@immutable
final class LoopOutcome {
  const new({required this.context, required this.improved});

  /// Derives the outcome from an already-computed [comparison]: improved
  /// iff [focusBehavior] was observed in the first attempt and resolved by
  /// the repeat.
  factory fromComparison({
    required TrainingContext context,
    required BehaviorCode focusBehavior,
    required AttemptComparison comparison,
  }) {
    final improved = comparison.observationChanges.any(
      (change) =>
          change.code == focusBehavior &&
          change.kind == ObservationChangeKind.resolved,
    );
    return LoopOutcome(context: context, improved: improved);
  }

  final TrainingContext context;
  final bool improved;

  @override
  bool operator ==(Object other) =>
      other is LoopOutcome &&
      other.context == context &&
      other.improved == improved;

  @override
  int get hashCode => Object.hash(context, improved);

  @override
  String toString() => 'LoopOutcome($context, improved: $improved)';
}

/// Advances a skill's difficulty level from completed loops (design part-3
/// §7): 3 improved loops at the current level advance it by one; a
/// non-improved loop resets the streak without lowering the level. `quick`
/// practice never forms loops for progression (D33) and is ignored.
final class Progression {
  const new();

  static const loopsToAdvance = 3;

  int levelFor({
    required int currentLevel,
    required List<LoopOutcome> outcomes,
  }) {
    var level = currentLevel;
    var streak = 0;
    for (final outcome in outcomes) {
      if (outcome.context == TrainingContext.quick) continue;
      if (!outcome.improved) {
        streak = 0;
        continue;
      }
      streak++;
      if (streak == loopsToAdvance) {
        level++;
        streak = 0;
      }
    }
    return level;
  }
}
