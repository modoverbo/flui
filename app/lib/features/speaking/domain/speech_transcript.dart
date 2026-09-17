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
  const new({required this.text, required this.words, required this.duration});

  final String text;
  final List<SpeechWord> words;
  final Duration duration;
}
