import 'dart:convert';
import 'dart:typed_data';

import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/features/speaking/domain/speech_analysis_repository.dart';
import 'package:flui/features/speaking/domain/speech_transcript.dart';
import 'package:http/http.dart' as http;

final class HttpSpeechAnalysisRepository implements SpeechAnalysisRepository {
  HttpSpeechAnalysisRepository({required this.endpoint, http.Client? client})
    : _client = client ?? http.Client();

  final Uri endpoint;
  final http.Client _client;

  @override
  Future<Result<SpeechTranscript>> analyze(
    Uint8List audio, {
    required String mimeType,
    required Duration duration,
  }) async {
    if (audio.isEmpty) return const Result.err(UnexpectedFailure('no_speech'));
    try {
      final response = await _client.post(
        endpoint,
        headers: const {
          'authorization': 'Bearer local-dev',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'audioBase64': base64Encode(audio),
          'mimeType': mimeType,
          'durationMs': duration.inMilliseconds,
        }),
      );
      if (response.statusCode != 200) {
        return Result.err(UnexpectedFailure('speech_${response.statusCode}'));
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Result.ok(_parseTranscript(json, duration));
    } on Object {
      return const Result.err(UnexpectedFailure('speech_unavailable'));
    }
  }

  SpeechTranscript _parseTranscript(
    Map<String, dynamic> json,
    Duration fallbackDuration,
  ) {
    final rawAnalysis = json['analysis'];
    final analysis = rawAnalysis is Map
        ? Map<String, dynamic>.from(rawAnalysis)
        : null;
    final rawWords = json['words'] as List? ?? const [];
    return SpeechTranscript(
      text: json['text'] as String,
      duration: Duration(
        milliseconds:
            (json['durationMs'] as num?)?.round() ??
            fallbackDuration.inMilliseconds,
      ),
      words: [
        for (final raw in rawWords)
          if (raw is Map)
            SpeechWord(
              text: raw['text'] as String,
              startSeconds: (raw['start'] as num).toDouble(),
              endSeconds: (raw['end'] as num).toDouble(),
            ),
      ],
      coaching: analysis == null
          ? null
          : SpeechCoaching(
              summary: analysis['summary'] as String,
              structure: analysis['structure'] as String,
              vocabulary: analysis['vocabulary'] as String,
              strength: analysis['strength'] as String,
              retryCue: analysis['retryCue'] as String,
            ),
    );
  }
}
