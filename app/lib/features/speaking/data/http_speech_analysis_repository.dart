import 'dart:convert';
import 'dart:typed_data';

import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/features/speaking/data/speech_analysis_error_mapper.dart';
import 'package:flui/features/speaking/domain/speech_analysis_repository.dart';
import 'package:flui/features/speaking/domain/speech_transcript.dart';
import 'package:http/http.dart' as http;

final class HttpSpeechAnalysisRepository implements SpeechAnalysisRepository {
  new({required this.endpoint, http.Client? client})
    : _client = client ?? http.Client();

  final Uri endpoint;
  final http.Client _client;

  @override
  Future<Result<SpeechTranscript>> analyze(
    Uint8List audio, {
    required String mimeType,
    required Duration duration,
    String? challengeId,
  }) => _send(
    audio,
    mimeType: mimeType,
    duration: duration,
    extra: challengeId == null ? const {} : {'challengeId': challengeId},
  );

  @override
  Future<Result<SpeechTranscript>> transcribe(
    Uint8List audio, {
    required String mimeType,
    required Duration duration,
  }) => _send(
    audio,
    mimeType: mimeType,
    duration: duration,
    extra: const {'mode': 'transcribe'},
  );

  Future<Result<SpeechTranscript>> _send(
    Uint8List audio, {
    required String mimeType,
    required Duration duration,
    required Map<String, dynamic> extra,
  }) async {
    if (audio.isEmpty) return const Result.err(UnexpectedFailure('no_speech'));
    try {
      final requestBody = <String, dynamic>{
        'audioBase64': base64Encode(audio),
        'mimeType': mimeType,
        'durationMs': duration.inMilliseconds,
        ...extra,
      };
      final response = await _client.post(
        endpoint,
        headers: const {
          'authorization': 'Bearer local-dev',
          'content-type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        return Result.err(
          mapSpeechAnalysisErrorCode(readSpeechAnalysisErrorCode(body)),
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Result.ok(
        SpeechTranscript.fromJson(json, fallbackDuration: duration),
      );
    } on Object {
      return const Result.err(UnexpectedFailure('speech_unavailable'));
    }
  }
}
