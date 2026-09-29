import 'dart:typed_data';

import 'package:flui/core/error/result.dart';
import 'package:flui/features/speaking/data/fake_speech_analysis_repository.dart';
import 'package:flui/features/speaking/domain/speech_transcript.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nextTranscribeText overrides transcribe() exactly once, then reverts '
      'to the default alternating text', () async {
    final repo = FakeSpeechAnalysisRepository(latency: Duration.zero)
      ..nextTranscribeText = 'perspicaz';

    final first = await repo.transcribe(
      Uint8List.fromList(const [1, 2, 3]),
      mimeType: 'audio/wav',
      duration: const Duration(seconds: 2),
    );
    expect((first as Ok<SpeechTranscript>).value.text, 'perspicaz');

    final second = await repo.transcribe(
      Uint8List.fromList(const [1, 2, 3]),
      mimeType: 'audio/wav',
      duration: const Duration(seconds: 2),
    );
    expect((second as Ok<SpeechTranscript>).value.text, isNot('perspicaz'));
  });

  test(
    'transcribeCalls counts transcribe() calls, never analyze() calls',
    () async {
      final repo = FakeSpeechAnalysisRepository(latency: Duration.zero);
      expect(repo.transcribeCalls, 0);

      await repo.transcribe(
        Uint8List.fromList(const [1, 2, 3]),
        mimeType: 'audio/wav',
        duration: const Duration(seconds: 2),
      );
      expect(repo.transcribeCalls, 1);

      await repo.transcribe(
        Uint8List.fromList(const [1, 2, 3]),
        mimeType: 'audio/wav',
        duration: const Duration(seconds: 2),
      );
      expect(repo.transcribeCalls, 2);

      await repo.analyze(
        Uint8List.fromList(const [1, 2, 3]),
        mimeType: 'audio/wav',
        duration: const Duration(seconds: 2),
      );
      expect(repo.transcribeCalls, 2);
    },
  );

  test('nextTranscribeText never affects analyze()', () async {
    final repo = FakeSpeechAnalysisRepository(latency: Duration.zero)
      ..nextTranscribeText = 'perspicaz';

    final result = await repo.analyze(
      Uint8List.fromList(const [1, 2, 3]),
      mimeType: 'audio/wav',
      duration: const Duration(seconds: 2),
    );

    expect((result as Ok<SpeechTranscript>).value.text, isNot('perspicaz'));
  });
}
