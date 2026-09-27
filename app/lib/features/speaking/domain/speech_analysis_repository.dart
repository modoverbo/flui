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
}
