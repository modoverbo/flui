import 'package:flui/core/error/failure.dart';

/// Maps a `speech-analyze` error response's machine-readable `error.code` to
/// a typed [SpeechAnalysisFailure]. Unknown or missing codes map to
/// [SpeechAnalysisErrorCode.unknown].
SpeechAnalysisFailure mapSpeechAnalysisErrorCode(String? code) {
  final mapped = switch (code) {
    'access_required' => SpeechAnalysisErrorCode.accessRequired,
    'access_unavailable' => SpeechAnalysisErrorCode.accessUnavailable,
    'daily_limit_reached' => SpeechAnalysisErrorCode.dailyLimitReached,
    'rate_limited' => SpeechAnalysisErrorCode.rateLimited,
    'no_speech' => SpeechAnalysisErrorCode.noSpeech,
    _ => SpeechAnalysisErrorCode.unknown,
  };
  return SpeechAnalysisFailure(mapped);
}

/// Reads the machine-readable `error.code` out of a decoded `{error: {code,
/// message}}` response body, or null when the body does not match that shape.
String? readSpeechAnalysisErrorCode(Object? body) {
  final error = body is Map ? body['error'] : null;
  final code = error is Map ? error['code'] : null;
  return code is String ? code : null;
}
