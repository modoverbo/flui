import 'package:flui/features/training/domain/speaking_attempt.dart';
import 'package:meta/meta.dart';

/// The then-vs-now audio pair PROGRESO offers for playback (spec `progress`,
/// design part-3 §5 "Milestones"; deferred from U18a to U18b), or an
/// explicit statement that there is nothing to pair yet.
@immutable
sealed class BeforeNowAudio {
  const new();
}

/// Both sides of the pair have retained audio — [beforeAttemptId] and
/// [nowAttemptId] are carried alongside the storage path/mime so a caller
/// can offer per-clip deletion without a second lookup.
final class BeforeNowAudioAvailable extends BeforeNowAudio {
  const new({
    required this.beforeAttemptId,
    required this.beforePath,
    required this.beforeMime,
    required this.nowAttemptId,
    required this.nowPath,
    required this.nowMime,
  });

  final String beforeAttemptId;
  final String beforePath;
  final String beforeMime;
  final String nowAttemptId;
  final String nowPath;
  final String nowMime;

  @override
  bool operator ==(Object other) =>
      other is BeforeNowAudioAvailable &&
      other.beforeAttemptId == beforeAttemptId &&
      other.beforePath == beforePath &&
      other.beforeMime == beforeMime &&
      other.nowAttemptId == nowAttemptId &&
      other.nowPath == nowPath &&
      other.nowMime == nowMime;

  @override
  int get hashCode => Object.hash(
    beforeAttemptId,
    beforePath,
    beforeMime,
    nowAttemptId,
    nowPath,
    nowMime,
  );

  @override
  String toString() =>
      'BeforeNowAudioAvailable($beforeAttemptId -> $nowAttemptId)';
}

/// The baseline has no stored audio, no milestone has retained audio yet,
/// or both — the comparison shown without audio, clearly indicated, never a
/// broken player (spec `progress`, "Then-vs-now audio playback
/// unavailable").
final class BeforeNowAudioUnavailable extends BeforeNowAudio {
  const new();

  @override
  bool operator ==(Object other) => other is BeforeNowAudioUnavailable;

  @override
  int get hashCode => (BeforeNowAudioUnavailable).hashCode;

  @override
  String toString() => 'BeforeNowAudioUnavailable()';
}

/// Pairs the diagnosis baseline's own retained audio with the latest
/// retained weekly milestone (design part-3 §5) — a single then-vs-now
/// clip, not one pair per skill area: the "before" side is the first
/// baseline-session attempt whose audio is still stored (diagnosis slot
/// order), the "now" side is whichever attempt `latestMilestone` names.
final class BeforeNowAudioSelector {
  const new();

  BeforeNowAudio select({
    required List<SpeakingAttempt> baselineAttempts,
    required SpeakingAttempt? latestMilestone,
  }) {
    AudioRetentionStored? before;
    String? beforeId;
    for (final attempt in baselineAttempts) {
      if (attempt.audio case final AudioRetentionStored stored) {
        before = stored;
        beforeId = attempt.id;
        break;
      }
    }

    final milestone = latestMilestone;
    final nowAudio = milestone?.audio;
    final now = nowAudio is AudioRetentionStored ? nowAudio : null;

    if (before == null ||
        beforeId == null ||
        now == null ||
        milestone == null) {
      return const BeforeNowAudioUnavailable();
    }

    return BeforeNowAudioAvailable(
      beforeAttemptId: beforeId,
      beforePath: before.path,
      beforeMime: before.mime,
      nowAttemptId: milestone.id,
      nowPath: now.path,
      nowMime: now.mime,
    );
  }
}
