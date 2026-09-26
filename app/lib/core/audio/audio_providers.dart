import 'dart:async';

import 'package:flui/core/audio/application/hold_to_record.dart';
import 'package:flui/core/audio/data/record_speech_recorder.dart';
import 'package:flui/core/audio/speech_recorder.dart';
import 'package:flui/core/clock/clock_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Builds the platform [SpeechRecorder] used for a hold. A plain factory
/// (not a value) so [holdToRecordProvider] gets a fresh recorder per hold
/// lifecycle rather than sharing platform capture state.
final speechRecorderFactoryProvider = Provider<SpeechRecorder Function()>(
  (ref) => RecordSpeechRecorder.new,
);

/// One [HoldToRecord] per subscriber lifecycle: disposed (and its
/// underlying recorder released) once nothing watches it anymore.
final Provider<HoldToRecord> holdToRecordProvider =
    Provider.autoDispose<HoldToRecord>((ref) {
      final recorder = ref.watch(speechRecorderFactoryProvider)();
      final holdToRecord = HoldToRecord(
        recorder,
        minDuration: const Duration(milliseconds: 600),
        maxDuration: const Duration(seconds: 45),
        clock: ref.watch(clockProvider),
      );
      ref.onDispose(() => unawaited(holdToRecord.dispose()));
      return holdToRecord;
    });
