import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/exercises/domain/exercise_attempt.dart';
import 'package:flui/features/vocabulary/domain/word_progress.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';
import 'package:meta/meta.dart';

/// Numbers for "Tu progreso" and "Hoy".
@immutable
final class ProgressStats {
  const new({
    required this.nueva,
    required this.practica,
    required this.tuya,
    required this.activeDays,
    this.firstTryPrecisionPercent,
  });

  factory compute({
    required List<WordProgress> progress,
    required List<ExerciseAttempt> attempts,
    required Set<LocalDate> activeDates,
  }) {
    int count(WordState state) =>
        progress.where((row) => row.state == state).length;
    final firstTry = attempts.where((attempt) => attempt.firstTry).length;
    return ProgressStats(
      nueva: count(WordState.nueva),
      practica: count(WordState.practica),
      tuya: count(WordState.tuya),
      activeDays: activeDates.length,
      firstTryPrecisionPercent: attempts.isEmpty
          ? null
          : (firstTry * 100 / attempts.length).round(),
    );
  }

  final int nueva;
  final int practica;
  final int tuya;
  final int activeDays;

  /// Share of answers correct on the first try, `null` without answers.
  final int? firstTryPrecisionPercent;

  int get totalWords => nueva + practica + tuya;
}
