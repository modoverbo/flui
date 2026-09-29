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

  /// Overrides the NEXT [transcribe] call's transcript text exactly once
  /// (consumed then reset to `null`), so real-path tests can prove a
  /// specific spoken answer matches/mismatches (U17b) without depending on
  /// [_nextText]'s fixed alternating sentences. Never affects [analyze].
  String? nextTranscribeText;

  /// How many times [transcribe] has been called — real-path tests use
  /// this to prove the mic's call count matches the number of recordings
  /// made (U17b's own quota-honesty requirement), independent of
  /// [analyze]'s own call count.
  int transcribeCalls = 0;

  @override
  Future<Result<SpeechTranscript>> analyze(
    Uint8List audio, {
    required String mimeType,
    required Duration duration,
    String? challengeId,
  }) async {
    final rejected = await _rejectIfNeeded(audio);
    if (rejected != null) return rejected;

    final text = _nextText();
    final isOdd = _attempt.isOdd;
    return Result.ok(
      SpeechTranscript(
        text: text,
        duration: duration,
        coaching: SpeechCoaching(
          summary: isOdd
              ? 'Explicaste que organizar tu mañana mejoró tu claridad.'
              : 'Explicaste el efecto de organizar tu mañana.',
          structure: isOdd
              ? 'Presentas la decisión y el beneficio; falta un cierre.'
              : 'La secuencia acción, resultado y cierre es clara.',
          vocabulary: isOdd
              ? 'Usaste “organizar” y “claridad”; “decisión” se repite.'
              : 'Usaste verbos concretos y evitaste repeticiones dominantes.',
          strength: 'Relacionas una acción concreta con su resultado.',
          retryCue: 'Cierra con una frase de máximo 10 palabras.',
        ),
        words: _words(text, duration),
      ),
    );
  }

  @override
  Future<Result<SpeechTranscript>> transcribe(
    Uint8List audio, {
    required String mimeType,
    required Duration duration,
  }) async {
    transcribeCalls++;
    final rejected = await _rejectIfNeeded(audio);
    if (rejected != null) return rejected;

    final override = nextTranscribeText;
    nextTranscribeText = null;
    final text = override ?? _nextText();
    return Result.ok(
      SpeechTranscript(
        text: text,
        duration: duration,
        words: _words(text, duration),
      ),
    );
  }

  /// Shared latency/failure/empty-audio handling for [analyze]/[transcribe].
  /// Returns a rejecting [Result] when the caller must stop here, or null to
  /// continue building a successful transcript.
  Future<Result<SpeechTranscript>?> _rejectIfNeeded(Uint8List audio) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final failure = nextFailure;
    nextFailure = null;
    if (failure != null) return Result.err(failure);
    if (audio.isEmpty) return const Result.err(UnexpectedFailure('no_speech'));
    return null;
  }

  String _nextText() {
    _attempt++;
    return _attempt.isOdd
        ? 'Eh pues tomé una decisión importante y o sea la decisión fue '
              'organizar mejor mi mañana para trabajar con más claridad.'
        : 'Organicé mi mañana antes de comenzar. Eso me permitió trabajar '
              'con más claridad y terminar el día con menos presión.';
  }

  List<SpeechWord> _words(String text, Duration duration) {
    final tokens = text.split(' ');
    final seconds = duration.inMilliseconds / 1000;
    final step = seconds / tokens.length;
    return [
      for (var index = 0; index < tokens.length; index++)
        SpeechWord(
          text: tokens[index],
          startSeconds: index * step,
          endSeconds: index * step + step * .7,
        ),
    ];
  }
}
