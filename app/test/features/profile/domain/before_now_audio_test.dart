import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/profile/domain/before_now_audio.dart';
import 'package:flui/features/training/domain/attempt_kind.dart';
import 'package:flui/features/training/domain/speaking_attempt.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:flui/features/training/domain/voice_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

const _metrics = VoiceMetrics(longPauses: 0, usefulPauses: 0, fillerCount: 0);

SpeakingAttempt _attempt({
  required String id,
  required AudioRetention audio,
  TrainingContext context = TrainingContext.diagnosis,
}) => SpeakingAttempt(
  id: id,
  sessionId: 'baseline',
  context: context,
  kind: AttemptKind.first,
  localDate: LocalDate(2026, 9, 1),
  transcript: 'Hola, esto es una prueba.',
  duration: const Duration(seconds: 20),
  metrics: _metrics,
  audio: audio,
);

void main() {
  group('BeforeNowAudioSelector', () {
    const selector = BeforeNowAudioSelector();

    test('pairs the first stored baseline attempt with the latest stored '
        'milestone', () {
      final result = selector.select(
        baselineAttempts: [
          _attempt(id: 'b1', audio: const AudioRetention.none()),
          _attempt(
            id: 'b2',
            audio: const AudioRetention.stored(
              path: 'u1/b2.wav',
              mime: 'audio/wav',
            ),
          ),
          _attempt(
            id: 'b3',
            audio: const AudioRetention.stored(
              path: 'u1/b3.wav',
              mime: 'audio/wav',
            ),
          ),
        ],
        latestMilestone: _attempt(
          id: 'm1',
          audio: const AudioRetention.stored(
            path: 'u1/m1.wav',
            mime: 'audio/wav',
          ),
          context: TrainingContext.daily,
        ),
      );

      expect(
        result,
        const BeforeNowAudioAvailable(
          beforeAttemptId: 'b2',
          beforePath: 'u1/b2.wav',
          beforeMime: 'audio/wav',
          nowAttemptId: 'm1',
          nowPath: 'u1/m1.wav',
          nowMime: 'audio/wav',
        ),
      );
    });

    test('is unavailable when no baseline attempt has stored audio', () {
      final result = selector.select(
        baselineAttempts: [
          _attempt(id: 'b1', audio: const AudioRetention.none()),
          _attempt(id: 'b2', audio: const AudioRetention.deleted()),
        ],
        latestMilestone: _attempt(
          id: 'm1',
          audio: const AudioRetention.stored(
            path: 'u1/m1.wav',
            mime: 'audio/wav',
          ),
        ),
      );

      expect(result, const BeforeNowAudioUnavailable());
    });

    test('is unavailable when there is no milestone yet', () {
      final result = selector.select(
        baselineAttempts: [
          _attempt(
            id: 'b1',
            audio: const AudioRetention.stored(
              path: 'u1/b1.wav',
              mime: 'audio/wav',
            ),
          ),
        ],
        latestMilestone: null,
      );

      expect(result, const BeforeNowAudioUnavailable());
    });

    test('is unavailable when the milestone audio was deleted', () {
      final result = selector.select(
        baselineAttempts: [
          _attempt(
            id: 'b1',
            audio: const AudioRetention.stored(
              path: 'u1/b1.wav',
              mime: 'audio/wav',
            ),
          ),
        ],
        latestMilestone: _attempt(
          id: 'm1',
          audio: const AudioRetention.deleted(),
        ),
      );

      expect(result, const BeforeNowAudioUnavailable());
    });

    test('is unavailable with no baseline attempts at all', () {
      final result = selector.select(
        baselineAttempts: const [],
        latestMilestone: _attempt(
          id: 'm1',
          audio: const AudioRetention.stored(
            path: 'u1/m1.wav',
            mime: 'audio/wav',
          ),
        ),
      );

      expect(result, const BeforeNowAudioUnavailable());
    });
  });
}
