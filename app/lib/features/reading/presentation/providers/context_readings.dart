import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/daily/presentation/providers/learning_data_controller.dart';
import 'package:flui/features/reading/domain/reading.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/features/vocabulary/presentation/providers/vocabulary_providers.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'context_readings.g.dart';

@immutable
final class ContextReading {
  const new({required this.reading, required this.word});

  final Reading reading;
  final Word word;
}

/// "En contexto": every word the user has met, newest first — not only the
/// ones met this week. A seven-day window emptied this page for good a week
/// after the catalog ran out, which is exactly when the scenes are the only
/// thing left to come back for.
///
/// The order rotates once a day: which word opens the page and which scene
/// opens each word both move, so the page is never the same two days running
/// and no scene is stuck at the bottom.
@riverpod
Future<List<ContextReading>> contextReadings(Ref ref) async {
  final data = await ref.watch(currentLearningDataProvider.future);
  final words = await ref.watch(wordsByIdProvider.future);
  final today = ref.watch(clockProvider).localToday();
  final rows =
      [
        for (final row in data.progress)
          if (words[row.wordId] != null) row,
      ]..sort((a, b) {
        final byDate = b.introducedOn.compareTo(a.introducedOn);
        return byDate != 0 ? byDate : a.wordId.compareTo(b.wordId);
      });

  final day = daysSinceEpoch(today);
  return [
    for (final row in rotate(rows, day))
      for (final reading in rotate(words[row.wordId]!.readings, day))
        ContextReading(reading: reading, word: words[row.wordId]!),
  ];
}

/// Days since 1970-01-01: the daily rotation offset.
int daysSinceEpoch(LocalDate date) => LocalDate(1970, 1, 1).daysUntil(date);

/// Moves the first `offset % length` items to the end.
List<T> rotate<T>(List<T> items, int offset) {
  if (items.length < 2) return [...items];
  final by = offset % items.length;
  return [...items.skip(by), ...items.take(by)];
}
