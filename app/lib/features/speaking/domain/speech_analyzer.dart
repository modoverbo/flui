import 'dart:math' as math;

import 'package:flui/features/speaking/domain/speaking_feedback.dart';
import 'package:flui/features/speaking/domain/speaking_metrics.dart';
import 'package:flui/features/speaking/domain/speech_transcript.dart';

final class SpeechAnalyzer {
  const new();

  static const _fillers = [
    'como que',
    'o sea',
    'digamos',
    'este',
    'pues',
    'mmm',
    'eh',
    'em',
    'um',
  ];
  static const _ignoredRepetitions = {
    'para',
    'pero',
    'porque',
    'como',
    'que',
    'una',
    'uno',
    'con',
    'por',
    'del',
    'las',
    'los',
    'sus',
    'este',
    'esta',
    'eso',
    'esa',
    'hay',
    'muy',
  };

  SpeakingMetrics analyze(SpeechTranscript transcript) {
    final tokens = _tokens(transcript.text);
    final fillers = <String, int>{};
    var fillerText = ' ${tokens.join(' ')} ';
    for (final filler in _fillers) {
      final pattern = RegExp(' ${RegExp.escape(filler)} ');
      final count = pattern.allMatches(fillerText).length;
      if (count > 0) {
        fillers[filler] = count;
        fillerText = fillerText.replaceAll(pattern, ' ');
      }
    }

    final counts = <String, int>{};
    for (final token in tokens) {
      if (token.length < 4 || _ignoredRepetitions.contains(token)) continue;
      counts[token] = (counts[token] ?? 0) + 1;
    }
    counts.removeWhere((_, count) => count < 2);

    var usefulPauses = 0;
    var longPauses = 0;
    for (var index = 1; index < transcript.words.length; index++) {
      final gap =
          transcript.words[index].startSeconds -
          transcript.words[index - 1].endSeconds;
      if (gap > 2) {
        longPauses++;
      } else if (gap >= .6) {
        usefulPauses++;
      }
    }

    final durationSeconds = math.max(
      1,
      transcript.duration.inMilliseconds / 1000,
    );
    return SpeakingMetrics(
      spokenWords: tokens.length,
      wordsPerMinute: tokens.length < 15
          ? null
          : (tokens.length * 60 / durationSeconds).round(),
      usefulPauses: usefulPauses,
      longPauses: longPauses,
      fillerCounts: Map.unmodifiable(fillers),
      repeatedWords: Map.unmodifiable(counts),
    );
  }

  SpeakingFeedback feedback(SpeakingMetrics metrics) {
    final signals = <FeedbackSignal>[];
    if (metrics.totalFillers >= 3 ||
        metrics.fillerCounts.values.any((v) => v >= 2)) {
      signals.add(
        FeedbackSignal(
          title: 'Muletillas',
          detail: '${metrics.totalFillers} detectadas · estimación',
          tone: FeedbackTone.opportunity,
        ),
      );
    }
    if (metrics.wordsPerMinute case final pace? when pace > 170) {
      signals.add(
        FeedbackSignal(
          title: 'Ritmo',
          detail: '$pace palabras/min · prueba un 15% más lento',
          tone: FeedbackTone.attention,
        ),
      );
    } else if (metrics.wordsPerMinute case final pace?) {
      signals.add(
        FeedbackSignal(
          title: 'Ritmo',
          detail: '$pace palabras/min · ritmo estable',
          tone: FeedbackTone.positive,
        ),
      );
    }
    if (metrics.longPauses > 0) {
      signals.add(
        FeedbackSignal(
          title: 'Pausas largas',
          detail: '${metrics.longPauses} de más de 2 segundos',
          tone: FeedbackTone.attention,
        ),
      );
    }
    if (metrics.repeatedWords.isNotEmpty) {
      final repeated = metrics.repeatedWords.entries.first;
      signals.add(
        FeedbackSignal(
          title: 'Variedad',
          detail: '“${repeated.key}” apareció ${repeated.value} veces',
          tone: FeedbackTone.attention,
        ),
      );
    }
    if (signals.isEmpty) {
      signals.add(
        const FeedbackSignal(
          title: 'Respuesta clara',
          detail: 'No detectamos patrones dominantes en este intento',
          tone: FeedbackTone.positive,
        ),
      );
    }
    final top = signals.take(3).toList(growable: false);
    final retryCue = metrics.totalFillers > 0
        ? 'Repite haciendo una pausa silenciosa donde usarías una muletilla.'
        : metrics.longPauses > 0
        ? 'Repite preparando tu conclusión antes de la última idea.'
        : 'Repite con una pausa breve antes de tu conclusión.';
    return SpeakingFeedback(signals: top, retryCue: retryCue);
  }

  List<String> _tokens(String text) => text
      .toLowerCase()
      .replaceAll(RegExp('[^a-záéíóúüñ0-9 ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
}
