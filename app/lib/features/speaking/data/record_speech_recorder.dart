import 'dart:async';
import 'dart:typed_data';

import 'package:flui/features/speaking/domain/speech_recorder.dart';
import 'package:record/record.dart';

final class RecordSpeechRecorder implements SpeechRecorder {
  final _recorder = AudioRecorder();
  final _bytes = BytesBuilder(copy: false);
  StreamSubscription<Uint8List>? _audioSubscription;

  @override
  Stream<double> get amplitude => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 120))
      .map((value) => value.current);

  @override
  Future<bool> requestPermission() => _recorder.hasPermission();

  @override
  Future<void> start() async {
    _bytes.clear();
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );
    _audioSubscription = stream.listen(_bytes.add);
  }

  @override
  Future<Uint8List> stop() async {
    await _recorder.stop();
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    return _bytes.takeBytes();
  }

  @override
  Future<void> cancel() async {
    await _recorder.cancel();
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    _bytes.clear();
  }

  @override
  Future<void> dispose() async {
    await _audioSubscription?.cancel();
    await _recorder.dispose();
  }
}
