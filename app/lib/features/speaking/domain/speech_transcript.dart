import 'package:meta/meta.dart';

@immutable
final class SpeechWord {
  const new({
    required this.text,
    required this.startSeconds,
    required this.endSeconds,
  });

  final String text;
  final double startSeconds;
  final double endSeconds;
}

/// One raw, wire-format `observations[]` entry as reported by
/// `speech-analyze` (design §9). Kept independent of
/// `features/training/domain`'s closed `BehaviorCode` catalog so this type
/// stays a plain read of the wire, never importing training (import_rules).
@immutable
final class SpeechObservation {
  const new({
    required this.skill,
    required this.code,
    required this.polarity,
    this.evidence,
  });

  /// The wire-format skill-area name the server reported (e.g. `"thinking"`).
  final String skill;

  /// The wire-format `BehaviorCode.wireCode` the server reported.
  final String code;

  /// The wire-format polarity name the server reported.
  final String polarity;

  final String? evidence;

  @override
  bool operator ==(Object other) =>
      other is SpeechObservation &&
      other.skill == skill &&
      other.code == code &&
      other.polarity == polarity &&
      other.evidence == evidence;

  @override
  int get hashCode => Object.hash(skill, code, polarity, evidence);
}

@immutable
final class SpeechTranscript {
  const new({
    required this.text,
    required this.words,
    required this.duration,
    this.coaching,
    this.observations = const [],
  });

  /// Parses a `speech-analyze` JSON response body. Lenient by design: a
  /// missing `analysis`/`observations` field (transcribe-mode responses,
  /// or an older function version) and a malformed `observations` entry are
  /// dropped rather than throwing, since the server already sanitizes this
  /// field but a client must never crash on an unexpected shape (design §9,
  /// backward-compatible migration window).
  factory fromJson(
    Map<String, dynamic> json, {
    required Duration fallbackDuration,
  }) {
    final rawAnalysis = json['analysis'];
    final analysis = rawAnalysis is Map
        ? Map<String, dynamic>.from(rawAnalysis)
        : null;
    final rawWords = json['words'] as List? ?? const [];
    final rawObservationsField = json['observations'];
    final rawObservations = rawObservationsField is List
        ? rawObservationsField
        : const <Object?>[];
    return SpeechTranscript(
      text: json['text'] as String,
      duration: Duration(
        milliseconds:
            (json['durationMs'] as num?)?.round() ??
            fallbackDuration.inMilliseconds,
      ),
      words: [
        for (final raw in rawWords)
          if (raw is Map)
            SpeechWord(
              text: raw['text'] as String,
              startSeconds: (raw['start'] as num).toDouble(),
              endSeconds: (raw['end'] as num).toDouble(),
            ),
      ],
      coaching: analysis == null
          ? null
          : SpeechCoaching(
              summary: analysis['summary'] as String,
              structure: analysis['structure'] as String,
              vocabulary: analysis['vocabulary'] as String,
              strength: analysis['strength'] as String,
              retryCue: analysis['retryCue'] as String,
            ),
      observations: [
        for (final raw in rawObservations)
          if (raw is Map &&
              raw['skill'] is String &&
              raw['code'] is String &&
              raw['polarity'] is String)
            SpeechObservation(
              skill: raw['skill'] as String,
              code: raw['code'] as String,
              polarity: raw['polarity'] as String,
              evidence: raw['evidence'] is String
                  ? raw['evidence'] as String
                  : null,
            ),
      ],
    );
  }

  final String text;
  final List<SpeechWord> words;
  final Duration duration;
  final SpeechCoaching? coaching;
  final List<SpeechObservation> observations;
}

@immutable
final class SpeechCoaching {
  const new({
    required this.summary,
    required this.structure,
    required this.vocabulary,
    required this.strength,
    required this.retryCue,
  });

  final String summary;
  final String structure;
  final String vocabulary;
  final String strength;
  final String retryCue;
}
