import 'dart:convert';
import 'dart:typed_data';

import 'package:flui/features/speaking/data/fake_speech_analysis_repository.dart';
import 'package:flui/features/speaking/data/supabase_speech_analysis_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../../helpers/supabase_recorder.dart';

void main() {
  test('fake analysis returns timestamped Spanish speech', () async {
    final repository = FakeSpeechAnalysisRepository();

    final result = await repository.analyze(
      Uint8List.fromList([1, 2, 3]),
      mimeType: 'audio/wav',
      duration: const Duration(seconds: 30),
    );

    final transcript = result.valueOrNull!;
    expect(transcript.text, isNotEmpty);
    expect(transcript.words, isNotEmpty);
    expect(transcript.duration, const Duration(seconds: 30));
  });

  test(
    'supabase analysis sends transient base64 audio and maps timestamps',
    () async {
      final recorder = SupabaseRecorder(
        respond: (request) {
          if (request.url.path.endsWith('/functions/v1/speech-analyze')) {
            return http.Response(
              jsonEncode({
                'text': 'Una idea clara',
                'words': [
                  {'text': 'Una', 'start': 0.0, 'end': 0.2},
                  {'text': 'idea', 'start': 0.3, 'end': 0.6},
                  {'text': 'clara', 'start': 0.7, 'end': 1.0},
                ],
                'durationMs': 1200,
              }),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          return const [];
        },
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseSpeechAnalysisRepository(recorder.client)
          .analyze(
            Uint8List.fromList([1, 2, 3]),
            mimeType: 'audio/wav',
            duration: const Duration(milliseconds: 1200),
          );

      final transcript = result.valueOrNull!;
      expect(transcript.text, 'Una idea clara');
      expect(transcript.words.last.endSeconds, 1.0);
      expect(transcript.duration, const Duration(milliseconds: 1200));
      final body = jsonDecode(recorder.last.body) as Map<String, dynamic>;
      expect(body['audioBase64'], base64Encode([1, 2, 3]));
      expect(body['mimeType'], 'audio/wav');
      expect(body['durationMs'], 1200);
    },
  );
}
