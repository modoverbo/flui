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
    String? challengeId,
  }) => _invoke(
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
  }) => _invoke(
    audio,
    mimeType: mimeType,
    duration: duration,
    extra: const {'mode': 'transcribe'},
  );

  Future<Result<SpeechTranscript>> _invoke(
    Uint8List audio, {
    required String mimeType,
    required Duration duration,
    required Map<String, dynamic> extra,
  }) async {
    if (audio.isEmpty) {
      return const Result.err(UnexpectedFailure('no_speech'));
    }
    try {
      final requestBody = <String, dynamic>{
        'audioBase64': base64Encode(audio),
        'mimeType': mimeType,
        'durationMs': duration.inMilliseconds,
        ...extra,
      };
      final response = await _client.functions.invoke(
        'speech-analyze',
        body: requestBody,
      );
      final data = response.data;
      if (data is! Map) {
        return const Result.err(UnexpectedFailure('invalid_speech_response'));
      }
      final json = Map<String, dynamic>.from(data);
      if (json['text'] is! String || json['words'] is! List) {
        return const Result.err(UnexpectedFailure('invalid_speech_response'));
      }
      return Result.ok(
        SpeechTranscript.fromJson(json, fallbackDuration: duration),
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
