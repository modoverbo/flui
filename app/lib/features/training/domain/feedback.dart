import 'package:flui/features/training/domain/observation.dart';
import 'package:meta/meta.dart';

/// User-facing feedback for one attempt: an observable-behavior primary
/// opportunity, an optional strength, and a retry cue.
///
/// Deliberately carries no numeric field anywhere — no field of this class
/// (or [summary]'s rendering of it) is ever a score or percentage (spec
/// `training-engine`: "attempted regression toward a numeric score is
/// rejected").
@immutable
final class Feedback {
  const new({required this.retryCue, this.primary, this.strength});

  /// The headline opportunity, or `null` when nothing stood out.
  final Observation? primary;

  /// An optional highlighted strength.
  final Observation? strength;

  final String retryCue;

  /// The plain-text rendering a UI would show: exactly what the no-number
  /// contract test scans.
  String get summary {
    final lines = <String>[
      if (primary != null) 'Oportunidad: ${primary!.code.wireCode}',
      if (strength != null) 'Fortaleza: ${strength!.code.wireCode}',
      retryCue,
    ];
    return lines.join(' ');
  }

  @override
  bool operator ==(Object other) =>
      other is Feedback &&
      other.primary == primary &&
      other.strength == strength &&
      other.retryCue == retryCue;

  @override
  int get hashCode => Object.hash(primary, strength, retryCue);
}
