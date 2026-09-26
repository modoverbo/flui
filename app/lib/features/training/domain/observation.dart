import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/polarity.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:meta/meta.dart';

/// Whether an [Observation] came from the LLM's reading of the transcript,
/// or was measured client-side from timing/amplitude (design D12).
enum ObservationSource { ai, measured }

/// One observed behavior in an attempt: a closed [BehaviorCode] plus
/// optional supporting evidence — never a number, never a score.
@immutable
final class Observation {
  const new({required this.code, required this.source, this.evidence});

  final BehaviorCode code;
  final ObservationSource source;
  final String? evidence;

  SkillArea get area => code.area;
  Polarity get polarity => code.polarity;

  @override
  bool operator ==(Object other) =>
      other is Observation &&
      other.code == code &&
      other.source == source &&
      other.evidence == evidence;

  @override
  int get hashCode => Object.hash(code, source, evidence);

  @override
  String toString() => 'Observation(${code.wireCode}, $source)';
}
