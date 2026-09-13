import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/daily/presentation/providers/learning_data_controller.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/features/vocabulary/domain/word_progress.dart';
import 'package:flui/features/vocabulary/presentation/providers/vocabulary_providers.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'my_words.g.dart';

/// A word of the user's repertoire.
@immutable
final class WordEntry {
  const new({required this.word, required this.progress, required this.isDue});

  final Word word;
  final WordProgress progress;
  final bool isDue;
}

/// "Palabras": every introduced word, newest first.
@riverpod
Future<List<WordEntry>> myWords(Ref ref) async {
  final data = await ref.watch(currentLearningDataProvider.future);
  final words = await ref.watch(wordsByIdProvider.future);
  final today = ref.watch(clockProvider).localToday();
  final entries = [
    for (final row in data.progress)
      if (words[row.wordId] case final word?)
        WordEntry(word: word, progress: row, isDue: row.isDueOn(today)),
  ];
  return entries..sort((a, b) {
    final byDate = b.progress.introducedOn.compareTo(a.progress.introducedOn);
    return byDate != 0 ? byDate : a.word.sortOrder.compareTo(b.word.sortOrder);
  });
}

/// One word of the repertoire, `null` when the user has not met it.
@riverpod
Future<WordEntry?> wordEntry(Ref ref, String wordId) async {
  final entries = await ref.watch(myWordsProvider.future);
  return entries.where((entry) => entry.word.id == wordId).firstOrNull;
}
