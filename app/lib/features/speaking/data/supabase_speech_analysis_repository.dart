import 'dart:convert';
import 'dart:typed_data';

import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/core/supabase/data_error_mapper.dart';
import 'package:flui/features/speaking/data/speech_analysis_error_mapper.dart';
import 'package:flui/features/speaking/domain/speech_analysis_repository.dart';
import 'package:flui/features/speaking/domain/speech_transcript.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseSpeechAnalysisRepository
    implements SpeechAnalysisRepository {
  const new(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<SpeechTranscript>> analyze(
    Uint8List audio, {
    required String mimeType,
    required Duration duration,
  }) async {
    if (audio.isEmpty) {
      return const Result.err(UnexpectedFailure('no_speech'));
    }
    try {
      final response = await _client.functions.invoke(
        'speech-analyze',
        body: {
          'audioBase64': base64Encode(audio),
          'mimeType': mimeType,
          'durationMs': duration.inMilliseconds,
        },
      );
      final data = response.data;
      if (data is! Map) {
        return const Result.err(UnexpectedFailure('invalid_speech_response'));
      }
      final json = Map<String, dynamic>.from(data);
      final rawWords = json['words'];
      if (json['text'] is! String || rawWords is! List) {
        return const Result.err(UnexpectedFailure('invalid_speech_response'));
      }
      final rawAnalysis = json['analysis'];
      final analysis = rawAnalysis is Map
          ? Map<String, dynamic>.from(rawAnalysis)
          : null;
      return Result.ok(
        SpeechTranscript(
          text: json['text'] as String,
          duration: Duration(
            milliseconds:
                (json['durationMs'] as num?)?.round() ??
                duration.inMilliseconds,
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
        ),
      );
    } on FunctionsFetchException catch (error) {
      // No response reached the client (network/transport failure): keep
      // going through the transport error mapper, same as any other call.
      return Result.err(mapDataError(error));
    } on FunctionException catch (error) {
      return Result.err(
        mapSpeechAnalysisErrorCode(readSpeechAnalysisErrorCode(error.details)),
      );
    } on Object catch (error) {
      return Result.err(mapDataError(error));
    }
  }
}
