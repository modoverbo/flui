import 'dart:typed_data';

import 'package:flui/features/speaking/data/record_speech_recorder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

void main() {
  test('stream capture uses the PCM encoder supported by record_web', () {
    expect(speechStreamConfig.encoder, AudioEncoder.pcm16bits);
    expect(speechStreamConfig.sampleRate, 16000);
    expect(speechStreamConfig.numChannels, 1);
  });

  test('captured PCM is wrapped in a valid mono 16 kHz WAV file', () {
    final wav = encodePcm16AsWav(Uint8List.fromList([1, 2, 3, 4]));
    final header = ByteData.sublistView(wav);

    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(header.getUint32(4, Endian.little), 40);
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(header.getUint16(20, Endian.little), 1);
    expect(header.getUint16(22, Endian.little), 1);
    expect(header.getUint32(24, Endian.little), 16000);
    expect(header.getUint16(34, Endian.little), 16);
    expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');
    expect(header.getUint32(40, Endian.little), 4);
    expect(wav.sublist(44), [1, 2, 3, 4]);
  });
}
