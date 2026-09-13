import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/daily/domain/session_planner.dart';
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

/// "En contexto": readings of words introduced today or in the last 7 days,
/// newest word first.
@riverpod
Future<List<ContextReading>> contextReadings(Ref ref) async {
  final data = await ref.watch(currentLearningDataProvider.future);
  final words = await ref.watch(wordsByIdProvider.future);
  final today = ref.watch(clockProvider).localToday();
  final since = today.addDays(-(SessionPlanner.interferenceDays - 1));
  final recent = [
    for (final row in data.progress)
      if (!row.introducedOn.isBefore(since) && words[row.wordId] != null) row,
  ]..sort((a, b) => b.introducedOn.compareTo(a.introducedOn));
  return [
    for (final row in recent)
      for (final reading in words[row.wordId]!.readings)
        ContextReading(reading: reading, word: words[row.wordId]!),
  ];
}
