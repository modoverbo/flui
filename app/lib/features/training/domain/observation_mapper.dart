import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/observation.dart';
import 'package:meta/meta.dart';

/// One `speech-analyze` `observations[]` entry (design §9), before it is
/// checked against the closed [BehaviorCode] catalog. Kept independent of
/// `features/speaking/domain` so this mapping stays a pure, one-way
/// sanitizer: the wire shape is whatever the server sends, this type is
/// only the training domain's own read of it.
@immutable
final class RawObservation {
  const new({
    required this.skill,
    required this.code,
    required this.polarity,
    this.evidence,
  });

  /// The wire-format skill-area name the server reported (e.g. `"thinking"`).
  final String skill;

  /// The wire-format [BehaviorCode.wireCode] the server reported.
  final String code;

  /// The wire-format polarity name the server reported.
  final String polarity;

  final String? evidence;
}

/// Sanitizes raw AI-reported observations against the closed catalog:
/// unknown codes and skill/polarity mismatches are dropped, never crash the
/// response (design §9 "sanitized, never failing the response").
final class ObservationMapper {
  const new();

  List<Observation> fromAnalysis(List<RawObservation> raw) => [
    for (final entry in raw) ?_sanitize(entry),
  ];

  Observation? _sanitize(RawObservation entry) {
    final code = BehaviorCode.fromWireCode(entry.code);
    if (code == null) return null;
    if (code.area.name != entry.skill) return null;
    if (code.polarity.name != entry.polarity) return null;
    final evidence = entry.evidence;
    final hasEvidence = evidence != null && evidence.isNotEmpty;
    return Observation(
      code: code,
      source: ObservationSource.ai,
      evidence: hasEvidence ? evidence : null,
    );
  }
}
