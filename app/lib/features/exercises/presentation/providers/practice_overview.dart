import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/daily/presentation/providers/learning_data_controller.dart';
import 'package:flui/features/vocabulary/presentation/providers/vocabulary_providers.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'practice_overview.g.dart';

/// View model of "Practica".
@immutable
final class PracticeOverview {
  const new({required this.dueCount, required this.hasWords, this.nextDueOn});

  final int dueCount;
  final bool hasWords;

  /// The next review date when nothing is due today.
  final LocalDate? nextDueOn;
}

@riverpod
Future<PracticeOverview> practiceOverview(Ref ref) async {
  final data = await ref.watch(currentLearningDataProvider.future);
  final words = await ref.watch(wordsByIdProvider.future);
  final today = ref.watch(clockProvider).localToday();
  final rows = [
    for (final row in data.progress)
      if (words.containsKey(row.wordId)) row,
  ];
  LocalDate? next;
  for (final row in rows) {
    final due = row.nextDueOn;
    if (due == null || !due.isAfter(today)) continue;
    if (next == null || due.isBefore(next)) next = due;
  }
  return PracticeOverview(
    dueCount: rows.where((row) => row.isDueOn(today)).length,
    hasWords: rows.isNotEmpty,
    nextDueOn: next,
  );
}
