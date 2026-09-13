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
    required LocalDate today,
  }) {
    int count(WordState state) =>
        progress.where((row) => row.state == state).length;
    final since = today.addDays(-(precisionWindowDays - 1));
    final recent = [
      for (final attempt in attempts)
        if (!attempt.localDate.isBefore(since) &&
            !attempt.localDate.isAfter(today))
          attempt,
    ];
    final firstTry = recent.where((attempt) => attempt.firstTry).length;
    return ProgressStats(
      nueva: count(WordState.nueva),
      practica: count(WordState.practica),
      tuya: count(WordState.tuya),
      activeDays: activeDates.length,
      firstTryPrecisionPercent: recent.isEmpty
          ? null
          : (firstTry * 100 / recent.length).round(),
    );
  }

  /// Precision is a rolling window, not a lifetime average: a hard first week
  /// should stop dragging the number down months later, and a good week
  /// should show up while it still means something.
  static const precisionWindowDays = 30;

  final int nueva;
  final int practica;
  final int tuya;
  final int activeDays;

  /// Share of answers correct on the first try over the last
  /// [precisionWindowDays] days, `null` without answers in that window.
  final int? firstTryPrecisionPercent;

  int get totalWords => nueva + practica + tuya;

  /// Words the user is working on: everything that is not `tuya` yet.
  int get inPractice => nueva + practica;
}
