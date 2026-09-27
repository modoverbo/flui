import 'package:flui/features/speaking/domain/speech_transcript.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpeechTranscript.fromJson', () {
    test('parses coaching and observations when both are present', () {
      final transcript = SpeechTranscript.fromJson(const {
        'text': 'Una idea clara',
        'durationMs': 1200,
        'words': [
          {'text': 'Una', 'start': 0.0, 'end': 0.2},
        ],
        'analysis': {
          'summary': 'Explica una idea.',
          'structure': 'Tiene una idea central.',
          'vocabulary': 'Usa el adjetivo “clara”.',
          'strength': 'Es directa.',
          'retryCue': 'Agrega una conclusión de una frase.',
        },
        'observations': [
          {
            'skill': 'thinking',
            'code': 'main_point_late',
            'polarity': 'opportunity',
            'evidence': 'Empezaste con el contexto antes de tu punto.',
          },
        ],
      }, fallbackDuration: const Duration(milliseconds: 1200));

      expect(transcript.text, 'Una idea clara');
      expect(transcript.coaching?.summary, 'Explica una idea.');
      expect(transcript.observations, [
        const SpeechObservation(
          skill: 'thinking',
          code: 'main_point_late',
          polarity: 'opportunity',
          evidence: 'Empezaste con el contexto antes de tu punto.',
        ),
      ]);
    });

    test('transcribe-mode response has no analysis/observations and coaching '
        'stays null', () {
      final transcript = SpeechTranscript.fromJson(const {
        'text': 'Una idea clara',
        'durationMs': 1200,
        'words': <Object?>[],
      }, fallbackDuration: const Duration(milliseconds: 1200));

      expect(transcript.coaching, isNull);
      expect(transcript.observations, isEmpty);
    });

    test('drops an observation entry missing a required string field', () {
      final transcript = SpeechTranscript.fromJson(const {
        'text': 'texto',
        'durationMs': 500,
        'words': <Object?>[],
        'observations': [
          {'skill': 'thinking', 'code': 'main_point_late'},
          {
            'skill': 'language',
            'code': 'vague_word',
            'polarity': 'opportunity',
          },
        ],
      }, fallbackDuration: const Duration(milliseconds: 500));

      expect(transcript.observations, [
        const SpeechObservation(
          skill: 'language',
          code: 'vague_word',
          polarity: 'opportunity',
        ),
      ]);
    });

    test('drops a non-map entry in observations without throwing', () {
      final transcript = SpeechTranscript.fromJson(const {
        'text': 'texto',
        'durationMs': 500,
        'words': <Object?>[],
        'observations': ['not-a-map', 42, null],
      }, fallbackDuration: const Duration(milliseconds: 500));

      expect(transcript.observations, isEmpty);
    });

    test('treats a non-list observations value as absent, never throwing', () {
      final transcript = SpeechTranscript.fromJson(const {
        'text': 'texto',
        'durationMs': 500,
        'words': <Object?>[],
        'observations': 'not-a-list',
      }, fallbackDuration: const Duration(milliseconds: 500));

      expect(transcript.observations, isEmpty);
    });

    test('treats non-string evidence as absent rather than throwing', () {
      final transcript = SpeechTranscript.fromJson(const {
        'text': 'texto',
        'durationMs': 500,
        'words': <Object?>[],
        'observations': [
          {
            'skill': 'thinking',
            'code': 'main_point_late',
            'polarity': 'opportunity',
            'evidence': 42,
          },
        ],
      }, fallbackDuration: const Duration(milliseconds: 500));

      expect(transcript.observations.single.evidence, isNull);
    });
  });
}
