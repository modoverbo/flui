import 'package:flui/core/audio/data/record_speech_recorder.dart';
import 'package:flui/core/audio/speech_recorder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Builds the platform [SpeechRecorder] used for a hold. A plain factory
/// (not a value) so each hold owner gets a fresh recorder rather than
/// sharing platform capture state.
final speechRecorderFactoryProvider = Provider<SpeechRecorder Function()>(
  (ref) => RecordSpeechRecorder.new,
);
