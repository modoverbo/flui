import 'package:meta/meta.dart';

@immutable
final class SpeakingMetrics {
  const new({
    required this.spokenWords,
    required this.wordsPerMinute,
    required this.usefulPauses,
    required this.longPauses,
    required this.fillerCounts,
    required this.repeatedWords,
  });

  final int spokenWords;
  final int? wordsPerMinute;
  final int usefulPauses;
  final int longPauses;
  final Map<String, int> fillerCounts;
  final Map<String, int> repeatedWords;

  bool get hasEnoughSpeech => wordsPerMinute != null;
  int get totalFillers =>
      fillerCounts.values.fold(0, (sum, count) => sum + count);
}
