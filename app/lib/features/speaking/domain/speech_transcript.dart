import 'package:meta/meta.dart';

@immutable
final class SpeechWord {
  const new({
    required this.text,
    required this.startSeconds,
    required this.endSeconds,
  });

  final String text;
  final double startSeconds;
  final double endSeconds;
}

@immutable
final class SpeechTranscript {
  const new({
    required this.text,
    required this.words,
    required this.duration,
    this.coaching,
  });

  final String text;
  final List<SpeechWord> words;
  final Duration duration;
  final SpeechCoaching? coaching;
}

@immutable
final class SpeechCoaching {
  const new({
    required this.summary,
    required this.structure,
    required this.vocabulary,
    required this.strength,
    required this.retryCue,
  });

  final String summary;
  final String structure;
  final String vocabulary;
  final String strength;
  final String retryCue;
}
