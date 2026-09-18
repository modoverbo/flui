import 'dart:async';
import 'dart:typed_data';

import 'package:flui/features/speaking/domain/speech_recorder.dart';
import 'package:record/record.dart';

const speechStreamConfig = RecordConfig(
  encoder: AudioEncoder.pcm16bits,
  sampleRate: 16000,
  numChannels: 1,
);

Uint8List encodePcm16AsWav(
  Uint8List pcm, {
  int sampleRate = 16000,
  int numChannels = 1,
}) {
  const headerLength = 44;
  const bitsPerSample = 16;
  const bytesPerSample = bitsPerSample ~/ 8;
  final wav = Uint8List(headerLength + pcm.length);
  final header = ByteData.sublistView(wav);

  void writeAscii(int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      header.setUint8(offset + index, value.codeUnitAt(index));
    }
  }

  writeAscii(0, 'RIFF');
  header.setUint32(4, wav.length - 8, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  header
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, numChannels, Endian.little)
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, sampleRate * numChannels * bytesPerSample, Endian.little)
    ..setUint16(32, numChannels * bytesPerSample, Endian.little)
    ..setUint16(34, bitsPerSample, Endian.little);
  writeAscii(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);
  wav.setRange(headerLength, wav.length, pcm);
  return wav;
}

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
    final stream = await _recorder.startStream(speechStreamConfig);
    _audioSubscription = stream.listen(_bytes.add);
  }

  @override
  Future<Uint8List> stop() async {
    await _recorder.stop();
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    return encodePcm16AsWav(_bytes.takeBytes());
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
