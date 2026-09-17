import 'package:meta/meta.dart';

enum FeedbackTone { positive, attention, opportunity }

@immutable
final class FeedbackSignal {
  const new({required this.title, required this.detail, required this.tone});

  final String title;
  final String detail;
  final FeedbackTone tone;
}

@immutable
final class SpeakingFeedback {
  const new({required this.signals, required this.retryCue});

  final List<FeedbackSignal> signals;
  final String retryCue;
}
