import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/training/domain/attempt_kind.dart';
import 'package:flui/features/training/domain/observation.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:flui/features/training/domain/voice_metrics.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'speaking_attempt.freezed.dart';

/// Whether a [SpeakingAttempt]'s audio is retained in the private
/// `speaking-audio` bucket, and the state of its upload (design D7, part-3
/// §5's guard trigger: `none`/`deleted` are terminal; `pending -> stored |
/// failed`; `failed -> pending | stored`; `stored -> deleted`).
@immutable
sealed class AudioRetention {
  const new();

  const factory none() = AudioRetentionNone;
  const factory pending() = AudioRetentionPending;
  const factory stored({required String path, required String mime}) =
      AudioRetentionStored;
  const factory failed() = AudioRetentionFailed;
  const factory deleted() = AudioRetentionDeleted;

  /// The wire value of `speaking_attempts.audio_status`.
  String get wireStatus => switch (this) {
    AudioRetentionNone() => 'none',
    AudioRetentionPending() => 'pending',
    AudioRetentionStored() => 'stored',
    AudioRetentionFailed() => 'failed',
    AudioRetentionDeleted() => 'deleted',
  };

  /// Whether a write may transition `audio_status` from [from] (`null` for
  /// a row that was never written yet, i.e. the server default `none`) to
  /// [to]. Mirrors `speaking_attempts_guard_audio` (migration
  /// `20260913120800_speaking_history.sql`): `none`/`deleted` are terminal;
  /// `pending -> stored|failed`; `failed -> pending|stored`; `stored ->
  /// deleted`; same status is always an allowed no-op.
  ///
  /// `FakeAttemptAudioStore` uses this to reject the same transitions the
  /// real database trigger rejects, so it behaves identically to
  /// `SupabaseAttemptAudioStore` for shared contract tests.
  static bool isAllowedTransition(AudioRetention? from, AudioRetention to) {
    final fromStatus = from?.wireStatus ?? 'none';
    final toStatus = to.wireStatus;
    if (fromStatus == toStatus) return true;
    return switch (fromStatus) {
      'pending' => toStatus == 'stored' || toStatus == 'failed',
      'failed' => toStatus == 'pending' || toStatus == 'stored',
      'stored' => toStatus == 'deleted',
      _ => false, // 'none'/'deleted' are terminal.
    };
  }
}

@immutable
final class AudioRetentionNone extends AudioRetention {
  const new();

  @override
  bool operator ==(Object other) => other is AudioRetentionNone;

  @override
  int get hashCode => (AudioRetentionNone).hashCode;

  @override
  String toString() => 'AudioRetention.none()';
}

@immutable
final class AudioRetentionPending extends AudioRetention {
  const new();

  @override
  bool operator ==(Object other) => other is AudioRetentionPending;

  @override
  int get hashCode => (AudioRetentionPending).hashCode;

  @override
  String toString() => 'AudioRetention.pending()';
}

@immutable
final class AudioRetentionStored extends AudioRetention {
  const new({required this.path, required this.mime});

  final String path;
  final String mime;

  @override
  bool operator ==(Object other) =>
      other is AudioRetentionStored && other.path == path && other.mime == mime;

  @override
  int get hashCode => Object.hash(AudioRetentionStored, path, mime);

  @override
  String toString() => 'AudioRetention.stored($path, $mime)';
}

@immutable
final class AudioRetentionFailed extends AudioRetention {
  const new();

  @override
  bool operator ==(Object other) => other is AudioRetentionFailed;

  @override
  int get hashCode => (AudioRetentionFailed).hashCode;

  @override
  String toString() => 'AudioRetention.failed()';
}

@immutable
final class AudioRetentionDeleted extends AudioRetention {
  const new();

  @override
  bool operator ==(Object other) => other is AudioRetentionDeleted;

  @override
  int get hashCode => (AudioRetentionDeleted).hashCode;

  @override
  String toString() => 'AudioRetention.deleted()';
}

/// One analyzed speaking attempt (design part-3 §5 `speaking_attempts`,
/// append-only). Diagnosis progress and progression are derived from these
/// rows — never a numeric score.
@freezed
abstract class SpeakingAttempt with _$SpeakingAttempt {
  const factory({
    required String id,
    required String sessionId,
    required TrainingContext context,
    required AttemptKind kind,
    required LocalDate localDate,
    required String transcript,
    required Duration duration,
    required VoiceMetrics metrics,
    required AudioRetention audio,
    @Default(<Observation>[]) List<Observation> observations,
    @Default(<String>[]) List<String> targetWordIds,
    @Default(<String>[]) List<String> wordsUsed,
    String? challengeId,

    /// Monday of the local ISO week this attempt claims as its stored
    /// milestone; only set together with [AudioRetention.pending] or
    /// [AudioRetention.stored] (design part-3 §5).
    LocalDate? milestoneWeek,
  }) = _SpeakingAttempt;
}
