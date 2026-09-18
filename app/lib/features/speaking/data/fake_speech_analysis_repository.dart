import 'dart:typed_data';

import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/features/speaking/domain/speech_analysis_repository.dart';
import 'package:flui/features/speaking/domain/speech_transcript.dart';

final class FakeSpeechAnalysisRepository implements SpeechAnalysisRepository {
  new({this.latency = const Duration(milliseconds: 450)});

  final Duration latency;
  Failure? nextFailure;
  int _attempt = 0;

  @override
  Future<Result<SpeechTranscript>> analyze(
    Uint8List audio, {
    required String mimeType,
    required Duration duration,
  }) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final failure = nextFailure;
    nextFailure = null;
    if (failure != null) return Result.err(failure);
    if (audio.isEmpty) return const Result.err(UnexpectedFailure('no_speech'));

    _attempt++;
    final text = _attempt.isOdd
        ? 'Eh pues tomé una decisión importante y o sea la decisión fue '
              'organizar mejor mi mañana para trabajar con más claridad.'
        : 'Organicé mi mañana antes de comenzar. Eso me permitió trabajar '
              'con más claridad y terminar el día con menos presión.';
    final tokens = text.split(' ');
    final seconds = duration.inMilliseconds / 1000;
    final step = seconds / tokens.length;
    return Result.ok(
      SpeechTranscript(
        text: text,
        duration: duration,
        coaching: SpeechCoaching(
          summary: _attempt.isOdd
              ? 'Explicaste que organizar tu mañana mejoró tu claridad.'
              : 'Explicaste el efecto de organizar tu mañana.',
          structure: _attempt.isOdd
              ? 'Presentas la decisión y el beneficio; falta un cierre.'
              : 'La secuencia acción, resultado y cierre es clara.',
          vocabulary: _attempt.isOdd
              ? 'Usaste “organizar” y “claridad”; “decisión” se repite.'
              : 'Usaste verbos concretos y evitaste repeticiones dominantes.',
          strength: 'Relacionas una acción concreta con su resultado.',
          retryCue: 'Cierra con una frase de máximo 10 palabras.',
        ),
        words: [
          for (var index = 0; index < tokens.length; index++)
            SpeechWord(
              text: tokens[index],
              startSeconds: index * step,
              endSeconds: index * step + step * .7,
            ),
        ],
      ),
    );
  }
}
