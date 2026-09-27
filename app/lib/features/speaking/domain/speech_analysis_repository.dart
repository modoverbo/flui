import 'dart:typed_data';

import 'package:flui/core/error/result.dart';
import 'package:flui/features/speaking/domain/speech_transcript.dart';

abstract interface class SpeechAnalysisRepository {
  Future<Result<SpeechTranscript>> analyze(
    Uint8List audio, {
    required String mimeType,
    required Duration duration,
    String? challengeId,
  });

  /// Transcribes audio without running the coaching evaluation: the
  /// cheapest correct server path (Whisper only, D34) for exercises that
  /// only need to judge what was said, not how. Same access/quota gates as
  /// [analyze]; the returned transcript's `coaching`/`observations` are
  /// always null/empty.
  Future<Result<SpeechTranscript>> transcribe(
    Uint8List audio, {
    required String mimeType,
    required Duration duration,
  });
}
