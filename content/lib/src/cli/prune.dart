/// Removing the exercises the adversarial gate found ambiguous, instead of
/// rewriting them a third time.
///
/// Round 2 of the gate showed rewriting backfires: a reworded sentence buys
/// one reviewer and loses the other, and the Spanish stops sounding like
/// Spanish. A word with six verified exercises is worth more than a word with
/// eight where two are broken — but only down to a floor, and never at the
/// cost of the paronym/register coverage the exercise set owes the learner.
/// Below either line this refuses and says what is missing, because the answer
/// there is authoring, not pruning.
library;

import 'package:content/src/model/word.dart';
import 'package:content/src/validation/structural.dart';

final _exerciseNumber = RegExp(r'^exercise (\d+):');

/// The exercise positions named by the reasons in a `<slug>.failures.json`.
///
/// A reason that names no exercise (an incomplete reviewer pass, say) names
/// nothing to prune: it is a reason to re-run the gate, not to delete an item.
Set<int> failedExercisePositions(Iterable<String> reasons) => {
  for (final reason in reasons)
    if (_exerciseNumber.firstMatch(reason) case final match?)
      int.parse(match.group(1)!),
};

/// Reads the `reasons` array `content:gate-apply` writes.
///
/// Throws [FormatException] on anything it cannot read, so `content:prune` can
/// say what is wrong with a file instead of silently pruning nothing.
List<String> parseFailureReasons(Object? json) {
  if (json is! Map<String, Object?>) {
    throw FormatException('a failures file must be an object, got $json');
  }
  final reasons = json['reasons'];
  if (reasons is! List) {
    throw FormatException('"reasons" must be a list, got $reasons');
  }
  return [
    for (final reason in reasons)
      if (reason is String)
        reason
      else
        throw FormatException('every reason must be a string, got $reason'),
  ];
}

/// What pruning one word would do, or why it must not happen.
final class PrunePlan {
  const PrunePlan({
    required this.slug,
    required this.dropped,
    required this.kept,
    required this.refusals,
    this.word,
  });

  final String slug;

  /// Original positions of the exercises the gate named, sorted.
  final List<int> dropped;

  /// Exercises that would survive.
  final int kept;

  /// Why the prune must not happen. Empty when it may.
  final List<String> refusals;

  /// The pruned word map, or null when [refusals] is not empty.
  final Map<String, Object?>? word;

  bool get refused => refusals.isNotEmpty;
}

/// Drops [failed] from [word] and renumbers what is left 1..n.
///
/// [word] is not modified; the plan carries its own copy.
PrunePlan planPrune({
  required String slug,
  required Map<String, Object?> word,
  required Set<int> failed,
}) {
  final exercises = (word['exercises']! as List<Object?>)
      .cast<Map<String, Object?>>();
  final positions = {
    for (final exercise in exercises) exercise['position']! as int,
  };
  final dropped = failed.toList()..sort();

  final refusals = <String>[];
  final unknown = dropped.where((p) => !positions.contains(p)).toList();
  if (unknown.isNotEmpty) {
    refusals.add(
      'the failures file names exercise ${unknown.join(', ')}, which '
      '$slug does not have — re-run content:gate-prepare and the gate',
    );
    return PrunePlan(
      slug: slug,
      dropped: dropped,
      kept: exercises.length,
      refusals: refusals,
    );
  }

  final survivors = [
    for (final exercise in exercises)
      if (!failed.contains(exercise['position'])) exercise,
  ];

  if (survivors.length < minExerciseCount) {
    refusals.add(
      'pruning ${dropped.length} of ${exercises.length} exercises would leave '
      '${survivors.length}, below the floor of $minExerciseCount — $slug needs '
      'authoring, not pruning',
    );
  }

  final present = <DistractorType>{
    for (final exercise in survivors)
      for (final option
          in (exercise['options']! as List<Object?>)
              .cast<Map<String, Object?>>())
        if (option['is_correct'] != true && option['distractor_type'] != null)
          _distractorType(option['distractor_type']! as String),
  };
  final missing = missingDistractorTypes(present);
  if (missing.isNotEmpty) {
    refusals.add(
      'the surviving exercises carry no ${missing.join(' and no ')} '
      'distractor — $slug needs authoring, not pruning',
    );
  }

  if (refusals.isNotEmpty) {
    return PrunePlan(
      slug: slug,
      dropped: dropped,
      kept: survivors.length,
      refusals: refusals,
    );
  }

  final renumbered = <Object?>[
    for (var i = 0; i < survivors.length; i++)
      <String, Object?>{...survivors[i], 'position': i + 1},
  ];
  return PrunePlan(
    slug: slug,
    dropped: dropped,
    kept: survivors.length,
    refusals: const [],
    word: <String, Object?>{...word, 'exercises': renumbered},
  );
}

DistractorType _distractorType(String raw) {
  for (final entry in distractorTypeNames.entries) {
    if (entry.value == raw) return entry.key;
  }
  throw FormatException('unknown distractor_type "$raw"');
}
