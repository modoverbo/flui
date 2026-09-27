import 'package:flui/core/audio/data/just_audio_speech_player.dart';
import 'package:flui/core/audio/data/record_speech_recorder.dart';
import 'package:flui/core/audio/speech_player.dart';
import 'package:flui/core/audio/speech_recorder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Builds the platform [SpeechRecorder] used for a hold. A plain factory
/// (not a value) so each hold owner gets a fresh recorder rather than
/// sharing platform capture state.
final speechRecorderFactoryProvider = Provider<SpeechRecorder Function()>(
  (ref) => RecordSpeechRecorder.new,
);

/// Builds the platform [SpeechPlayer] used to play back a recording. A
/// plain factory (not a value), matching [speechRecorderFactoryProvider],
/// so each owner gets a fresh player — and disposes it itself — rather
/// than sharing playback state across unrelated consumers.
final speechPlayerFactoryProvider = Provider<SpeechPlayer Function()>(
  (ref) => JustAudioSpeechPlayer.new,
);
