import 'package:flui/features/vocabulary/domain/word_progress.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';
import 'package:meta/meta.dart';

enum AchievementKind {
  /// Primera palabra.
  firstWord,

  /// Primera palabra tuya.
  firstOwnedWord,

  /// 5 días activos.
  fiveActiveDays,

  /// 10 palabras.
  tenWords,

  /// Primera frase propia.
  firstOwnSentence,
}

@immutable
final class Achievement {
  const new({required this.kind, required this.current, required this.target});

  final AchievementKind kind;

  /// Progress so far, capped at [target].
  final int current;
  final int target;

  bool get isCompleted => current >= target;

  double get fraction => target == 0 ? 1 : current / target;
}

/// Achievements computed from the learning data (never stored).
abstract final class Achievements {
  static List<Achievement> compute({
    required List<WordProgress> progress,
    required int activeDays,
  }) {
    final introduced = progress.length;
    final owned = progress.where((row) => row.state == WordState.tuya).length;
    final sentences = progress.where((row) => row.productionDone).length;
    Achievement build(AchievementKind kind, int current, int target) =>
        Achievement(
          kind: kind,
          current: current > target ? target : current,
          target: target,
        );
    return [
      build(AchievementKind.firstWord, introduced, 1),
      build(AchievementKind.firstOwnedWord, owned, 1),
      build(AchievementKind.fiveActiveDays, activeDays, 5),
      build(AchievementKind.tenWords, introduced, 10),
      build(AchievementKind.firstOwnSentence, sentences, 1),
    ];
  }
}
