import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/training/domain/attempt_kind.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/observation.dart';
import 'package:flui/features/training/domain/speaking_attempt.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:flui/features/training/domain/voice_metrics.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'speaking_attempt_dto.freezed.dart';
part 'speaking_attempt_dto.g.dart';

/// A `public.speaking_attempts` row (design part-3 §5).
@freezed
abstract class SpeakingAttemptDto with _$SpeakingAttemptDto {
  @JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
  const factory({
    required String id,
    required String sessionId,
    required String context,
    required String kind,
    required String localDate,
    required String transcript,
    required int durationMs,
    required Map<String, Object?> metrics,
    required List<Object?> observations,
    required String audioStatus,
    @Default(<String>[]) List<String> targetWordIds,
    @Default(<String>[]) List<String> wordsUsed,
    String? challengeId,
    String? audioPath,
    String? audioMime,
    String? milestoneWeek,
  }) = _SpeakingAttemptDto;

  factory fromJson(Map<String, dynamic> json) =>
      _$SpeakingAttemptDtoFromJson(json);

  factory fromDomain(SpeakingAttempt attempt) => SpeakingAttemptDto(
    id: attempt.id,
    sessionId: attempt.sessionId,
    context: attempt.context.name,
    kind: attempt.kind.name,
    challengeId: attempt.challengeId,
    targetWordIds: attempt.targetWordIds,
    wordsUsed: attempt.wordsUsed,
    localDate: attempt.localDate.toIso(),
    transcript: attempt.transcript,
    durationMs: attempt.duration.inMilliseconds,
    metrics: _metricsToJson(attempt.metrics),
    observations: [
      for (final observation in attempt.observations)
        _observationToJson(observation),
    ],
    audioStatus: attempt.audio.wireStatus,
    audioPath: switch (attempt.audio) {
      AudioRetentionStored(:final path) => path,
      _ => null,
    },
    audioMime: switch (attempt.audio) {
      AudioRetentionStored(:final mime) => mime,
      _ => null,
    },
    milestoneWeek: attempt.milestoneWeek?.toIso(),
  );

  const new _();

  static const columns =
      'id, session_id, context, kind, challenge_id, target_word_ids, '
      'words_used, local_date, transcript, duration_ms, metrics, '
      'observations, audio_status, audio_path, audio_mime, milestone_week';

  SpeakingAttempt toDomain() {
    final week = milestoneWeek;
    return SpeakingAttempt(
      id: id,
      sessionId: sessionId,
      context: TrainingContext.values.byName(context),
      kind: AttemptKind.values.byName(kind),
      challengeId: challengeId,
      targetWordIds: targetWordIds,
      wordsUsed: wordsUsed,
      localDate: LocalDate.parse(localDate),
      transcript: transcript,
      duration: Duration(milliseconds: durationMs),
      metrics: _metricsFromJson(metrics),
      observations: [
        for (final row in observations) ?_observationFromJson(row),
      ],
      audio: _audioFromWire(
        status: audioStatus,
        path: audioPath,
        mime: audioMime,
      ),
      milestoneWeek: week == null ? null : LocalDate.parse(week),
    );
  }
}

Map<String, Object?> _metricsToJson(VoiceMetrics metrics) => {
  'words_per_minute': ?metrics.wordsPerMinute,
  'long_pauses': metrics.longPauses,
  'useful_pauses': metrics.usefulPauses,
  'filler_count': metrics.fillerCount,
  'fillers_per_minute': ?metrics.fillersPerMinute,
  'volume_spread_db': ?metrics.volumeSpreadDb,
};

VoiceMetrics _metricsFromJson(Map<String, Object?> json) => VoiceMetrics(
  longPauses: (json['long_pauses'] as num?)?.toInt() ?? 0,
  usefulPauses: (json['useful_pauses'] as num?)?.toInt() ?? 0,
  fillerCount: (json['filler_count'] as num?)?.toInt() ?? 0,
  wordsPerMinute: (json['words_per_minute'] as num?)?.toInt(),
  fillersPerMinute: (json['fillers_per_minute'] as num?)?.toDouble(),
  volumeSpreadDb: (json['volume_spread_db'] as num?)?.toDouble(),
);

Map<String, Object?> _observationToJson(Observation observation) => {
  'code': observation.code.wireCode,
  'source': observation.source.name,
  'evidence': ?observation.evidence,
};

/// Drops an entry with an unknown code, a mismatched source, or a malformed
/// shape rather than failing the whole row — the same leniency
/// `ObservationMapper` applies to freshly analyzed observations.
Observation? _observationFromJson(Object? row) {
  if (row is! Map) return null;
  final code = row['code'];
  final source = row['source'];
  if (code is! String || source is! String) return null;
  final behaviorCode = BehaviorCode.fromWireCode(code);
  final observationSource = switch (source) {
    'ai' => ObservationSource.ai,
    'measured' => ObservationSource.measured,
    _ => null,
  };
  if (behaviorCode == null || observationSource == null) return null;
  final evidence = row['evidence'];
  return Observation(
    code: behaviorCode,
    source: observationSource,
    evidence: evidence is String ? evidence : null,
  );
}

AudioRetention _audioFromWire({
  required String status,
  required String? path,
  required String? mime,
}) => switch (status) {
  'pending' => const AudioRetention.pending(),
  'stored' when path != null && mime != null => AudioRetention.stored(
    path: path,
    mime: mime,
  ),
  'failed' => const AudioRetention.failed(),
  'deleted' => const AudioRetention.deleted(),
  _ => const AudioRetention.none(),
};
