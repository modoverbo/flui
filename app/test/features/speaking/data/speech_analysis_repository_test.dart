import 'dart:convert';
import 'dart:typed_data';

import 'package:flui/core/error/failure.dart';
import 'package:flui/features/speaking/data/fake_speech_analysis_repository.dart';
import 'package:flui/features/speaking/data/http_speech_analysis_repository.dart';
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

  test('local analysis maps transcript and evidence-based coaching', () async {
    late http.Request captured;
    final client = _RecordingClient((request) {
      captured = request;
      return http.Response(
        jsonEncode({
          'text': 'Organicé mi mañana y terminé el trabajo con calma.',
          'words': [
            {'text': 'Organicé', 'start': 0.0, 'end': 0.4},
            {'text': 'mañana', 'start': 0.5, 'end': 0.9},
          ],
          'durationMs': 4200,
          'analysis': {
            'summary': 'Explica una decisión y su resultado.',
            'structure': 'Idea y consecuencia claras; falta un cierre.',
            'vocabulary': 'Vocabulario concreto pero poco variado.',
            'strength': 'Conecta la acción con su beneficio.',
            'retryCue': 'Cierra con una frase que resuma el aprendizaje.',
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final result =
        await HttpSpeechAnalysisRepository(
          endpoint: Uri.parse('http://127.0.0.1:8787/analyze'),
          client: client,
        ).analyze(
          Uint8List.fromList([1, 2, 3]),
          mimeType: 'audio/wav',
          duration: const Duration(milliseconds: 4200),
        );

    expect(result.valueOrNull?.text, contains('Organicé'));
    expect(result.valueOrNull?.coaching?.summary, contains('decisión'));
    expect(result.valueOrNull?.coaching?.vocabulary, contains('concreto'));
    expect(captured.headers['authorization'], 'Bearer local-dev');
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
                'analysis': {
                  'summary': 'Explica una idea.',
                  'structure': 'Tiene una idea central.',
                  'vocabulary': 'Usa el adjetivo “clara”.',
                  'strength': 'Es directa.',
                  'retryCue': 'Agrega una conclusión de una frase.',
                },
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
      expect(transcript.coaching?.vocabulary, contains('clara'));
      final body = jsonDecode(recorder.last.body) as Map<String, dynamic>;
      expect(body['audioBase64'], base64Encode([1, 2, 3]));
      expect(body['mimeType'], 'audio/wav');
      expect(body['durationMs'], 1200);
    },
  );

  test(
    'supabase analysis maps 403 access_required to SpeechAnalysisFailure',
    () async {
      final recorder = SupabaseRecorder(
        respond: (request) => http.Response(
          jsonEncode({
            'error': {
              'code': 'access_required',
              'message': 'An active subscription or trial is required.',
            },
          }),
          403,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseSpeechAnalysisRepository(recorder.client)
          .analyze(
            Uint8List.fromList([1, 2, 3]),
            mimeType: 'audio/wav',
            duration: const Duration(seconds: 1),
          );

      expect(
        result.failureOrNull,
        const SpeechAnalysisFailure(SpeechAnalysisErrorCode.accessRequired),
      );
    },
  );

  test(
    'supabase analysis maps 503 access_unavailable to SpeechAnalysisFailure',
    () async {
      final recorder = SupabaseRecorder(
        respond: (request) => http.Response(
          jsonEncode({
            'error': {
              'code': 'access_unavailable',
              'message': 'Could not verify access. Try again shortly.',
            },
          }),
          503,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseSpeechAnalysisRepository(recorder.client)
          .analyze(
            Uint8List.fromList([1, 2, 3]),
            mimeType: 'audio/wav',
            duration: const Duration(seconds: 1),
          );

      expect(
        result.failureOrNull,
        const SpeechAnalysisFailure(SpeechAnalysisErrorCode.accessUnavailable),
      );
    },
  );

  test(
    'http analysis maps 403 access_required to SpeechAnalysisFailure',
    () async {
      final client = _RecordingClient(
        (_) => http.Response(
          jsonEncode({
            'error': {
              'code': 'access_required',
              'message': 'An active subscription or trial is required.',
            },
          }),
          403,
          headers: {'content-type': 'application/json'},
        ),
      );

      final result =
          await HttpSpeechAnalysisRepository(
            endpoint: Uri.parse('http://127.0.0.1:8787/analyze'),
            client: client,
          ).analyze(
            Uint8List.fromList([1, 2, 3]),
            mimeType: 'audio/wav',
            duration: const Duration(seconds: 1),
          );

      expect(
        result.failureOrNull,
        const SpeechAnalysisFailure(SpeechAnalysisErrorCode.accessRequired),
      );
    },
  );

  test(
    'supabase analysis maps 429 daily_limit_reached to SpeechAnalysisFailure',
    () async {
      final recorder = SupabaseRecorder(
        respond: (request) => http.Response(
          jsonEncode({
            'error': {
              'code': 'daily_limit_reached',
              'message': "You have reached today's analysis limit.",
            },
          }),
          429,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseSpeechAnalysisRepository(recorder.client)
          .analyze(
            Uint8List.fromList([1, 2, 3]),
            mimeType: 'audio/wav',
            duration: const Duration(seconds: 1),
          );

      expect(
        result.failureOrNull,
        const SpeechAnalysisFailure(SpeechAnalysisErrorCode.dailyLimitReached),
      );
    },
  );

  test(
    'http analysis maps 429 daily_limit_reached to SpeechAnalysisFailure',
    () async {
      final client = _RecordingClient(
        (_) => http.Response(
          jsonEncode({
            'error': {
              'code': 'daily_limit_reached',
              'message': "You have reached today's analysis limit.",
            },
          }),
          429,
          headers: {'content-type': 'application/json'},
        ),
      );

      final result =
          await HttpSpeechAnalysisRepository(
            endpoint: Uri.parse('http://127.0.0.1:8787/analyze'),
            client: client,
          ).analyze(
            Uint8List.fromList([1, 2, 3]),
            mimeType: 'audio/wav',
            duration: const Duration(seconds: 1),
          );

      expect(
        result.failureOrNull,
        const SpeechAnalysisFailure(SpeechAnalysisErrorCode.dailyLimitReached),
      );
    },
  );

  test('fake transcribe returns a coaching-free transcript', () async {
    final repository = FakeSpeechAnalysisRepository();

    final result = await repository.transcribe(
      Uint8List.fromList([1, 2, 3]),
      mimeType: 'audio/wav',
      duration: const Duration(seconds: 5),
    );

    final transcript = result.valueOrNull!;
    expect(transcript.text, isNotEmpty);
    expect(transcript.coaching, isNull);
    expect(transcript.observations, isEmpty);
  });

  test('local transcribe posts mode=transcribe and parses a coaching-free '
      'transcript', () async {
    late http.Request captured;
    final client = _RecordingClient((request) {
      captured = request;
      return http.Response(
        jsonEncode({
          'text': 'Casa',
          'words': [
            {'text': 'Casa', 'start': 0.0, 'end': 0.4},
          ],
          'durationMs': 900,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final result =
        await HttpSpeechAnalysisRepository(
          endpoint: Uri.parse('http://127.0.0.1:8787/analyze'),
          client: client,
        ).transcribe(
          Uint8List.fromList([1, 2, 3]),
          mimeType: 'audio/wav',
          duration: const Duration(milliseconds: 900),
        );

    expect(result.valueOrNull?.text, 'Casa');
    expect(result.valueOrNull?.coaching, isNull);
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['mode'], 'transcribe');
    expect(body.containsKey('challengeId'), false);
  });

  test('supabase transcribe posts mode=transcribe and parses a coaching-free '
      'transcript', () async {
    final recorder = SupabaseRecorder(
      respond: (request) {
        if (request.url.path.endsWith('/functions/v1/speech-analyze')) {
          return http.Response(
            jsonEncode({
              'text': 'Casa',
              'words': [
                {'text': 'Casa', 'start': 0.0, 'end': 0.4},
              ],
              'durationMs': 900,
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
        .transcribe(
          Uint8List.fromList([1, 2, 3]),
          mimeType: 'audio/wav',
          duration: const Duration(milliseconds: 900),
        );

    expect(result.valueOrNull?.text, 'Casa');
    expect(result.valueOrNull?.coaching, isNull);
    final body = jsonDecode(recorder.last.body) as Map<String, dynamic>;
    expect(body['mode'], 'transcribe');
  });

  test(
    'supabase analysis maps 422 no_speech to SpeechAnalysisFailure',
    () async {
      final recorder = SupabaseRecorder(
        respond: (request) => http.Response(
          jsonEncode({
            'error': {
              'code': 'no_speech',
              'message': 'No speech was detected.',
            },
          }),
          422,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseSpeechAnalysisRepository(recorder.client)
          .transcribe(
            Uint8List.fromList([1, 2, 3]),
            mimeType: 'audio/wav',
            duration: const Duration(seconds: 1),
          );

      expect(
        result.failureOrNull,
        const SpeechAnalysisFailure(SpeechAnalysisErrorCode.noSpeech),
      );
    },
  );

  test('http analysis maps 422 no_speech to SpeechAnalysisFailure', () async {
    final client = _RecordingClient(
      (_) => http.Response(
        jsonEncode({
          'error': {'code': 'no_speech', 'message': 'No speech was detected.'},
        }),
        422,
        headers: {'content-type': 'application/json'},
      ),
    );

    final result =
        await HttpSpeechAnalysisRepository(
          endpoint: Uri.parse('http://127.0.0.1:8787/analyze'),
          client: client,
        ).transcribe(
          Uint8List.fromList([1, 2, 3]),
          mimeType: 'audio/wav',
          duration: const Duration(seconds: 1),
        );

    expect(
      result.failureOrNull,
      const SpeechAnalysisFailure(SpeechAnalysisErrorCode.noSpeech),
    );
  });

  test(
    'http analysis maps 503 access_unavailable to SpeechAnalysisFailure',
    () async {
      final client = _RecordingClient(
        (_) => http.Response(
          jsonEncode({
            'error': {
              'code': 'access_unavailable',
              'message': 'Could not verify access. Try again shortly.',
            },
          }),
          503,
          headers: {'content-type': 'application/json'},
        ),
      );

      final result =
          await HttpSpeechAnalysisRepository(
            endpoint: Uri.parse('http://127.0.0.1:8787/analyze'),
            client: client,
          ).analyze(
            Uint8List.fromList([1, 2, 3]),
            mimeType: 'audio/wav',
            duration: const Duration(seconds: 1),
          );

      expect(
        result.failureOrNull,
        const SpeechAnalysisFailure(SpeechAnalysisErrorCode.accessUnavailable),
      );
    },
  );
}

final class _RecordingClient extends http.BaseClient {
  new(this.respond);

  final http.Response Function(http.Request request) respond;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final concrete = request as http.Request;
    final response = respond(concrete);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}
