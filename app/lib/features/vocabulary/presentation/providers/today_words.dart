import 'package:flui/features/vocabulary/presentation/providers/my_words.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'today_words.g.dart';

/// PALABRAS' own "1-3 active words/day" (spec `vocabulary`, U17): the
/// repertoire's due entries, earliest due first, capped at 3 — the same
/// due-word source `/session`'s review flow already reads
/// (`WordProgress.isDueOn`, via `WordEntry.isDue`), so PALABRAS never
/// invents a second selection rule for "today's words". Empty (never a
/// crash) when nothing is due.
@riverpod
Future<List<WordEntry>> todayWords(Ref ref) async {
  final entries = await ref.watch(myWordsProvider.future);
  final due = [
    for (final entry in entries)
      if (entry.isDue) entry,
  ]..sort(_byNextDue);
  return due.take(3).toList();
}

int _byNextDue(WordEntry a, WordEntry b) {
  final aDue = a.progress.nextDueOn;
  final bDue = b.progress.nextDueOn;
  if (aDue == null || bDue == null) return 0;
  return aDue.compareTo(bDue);
}
