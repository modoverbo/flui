import 'dart:typed_data';

abstract interface class SpeechRecorder {
  Future<bool> requestPermission();
  Future<void> start();
  Future<Uint8List> stop();
  Future<void> cancel();
  Stream<double> get amplitude;
  Future<void> dispose();
}
