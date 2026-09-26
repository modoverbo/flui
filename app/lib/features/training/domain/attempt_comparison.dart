import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/observation.dart';
import 'package:flui/features/training/domain/voice_metrics.dart';
import 'package:meta/meta.dart';

/// Whether a behavior seen in the first attempt was fixed, kept, or
/// introduced by the repeat — never a score delta.
enum ObservationChangeKind { resolved, persisted, appeared }

@immutable
final class ObservationChange {
  const new({required this.code, required this.kind});

  final BehaviorCode code;
  final ObservationChangeKind kind;

  @override
  bool operator ==(Object other) =>
      other is ObservationChange && other.code == code && other.kind == kind;

  @override
  int get hashCode => Object.hash(code, kind);

  @override
  String toString() => 'ObservationChange(${code.wireCode}, $kind)';
}

/// The raw voice metric a [MetricChange] describes.
enum MetricKind { pace, fillers, pauses, volume }

enum MetricDirection { improved, worsened }

/// A directional trend between two attempts' [VoiceMetrics] — never the raw
/// numbers themselves.
@immutable
final class MetricChange {
  const new({required this.kind, required this.direction});

  final MetricKind kind;
  final MetricDirection direction;

  @override
  bool operator ==(Object other) =>
      other is MetricChange &&
      other.kind == kind &&
      other.direction == direction;

  @override
  int get hashCode => Object.hash(kind, direction);

  @override
  String toString() => 'MetricChange($kind, $direction)';
}

/// What changed between a first and a repeat attempt, expressed only as
/// observable behavior changes and directional metric trends — never a
/// numeric delta (spec `training-engine`: attempt comparison requirement).
@immutable
final class AttemptComparison {
  const new({
    required this.observationChanges,
    required this.metricChanges,
    required this.isMateriallySame,
  });

  // The dot-only unnamed-constructor shorthand this codebase otherwise uses
  // (`new(...)`) does not extend to named constructors — `factory .between`
  // is a parse error, so the class name stays here.
  // ignore: unnecessary_type_name_in_constructor
  factory AttemptComparison.between({
    required List<Observation> firstObservations,
    required List<Observation> repeatObservations,
    required VoiceMetrics firstMetrics,
    required VoiceMetrics repeatMetrics,
  }) {
    final firstCodes = {for (final o in firstObservations) o.code};
    final repeatCodes = {for (final o in repeatObservations) o.code};
    final observationChanges = [
      for (final code in {...firstCodes, ...repeatCodes})
        ObservationChange(
          code: code,
          kind: _kindFor(code, firstCodes, repeatCodes),
        ),
    ];

    final metricChanges = [
      ..._fillers(firstMetrics, repeatMetrics),
      ..._pauses(firstMetrics, repeatMetrics),
      ..._pace(firstMetrics, repeatMetrics),
      ..._volume(firstMetrics, repeatMetrics),
    ];

    return AttemptComparison(
      observationChanges: observationChanges,
      metricChanges: metricChanges,
      isMateriallySame:
          observationChanges.every(
            (c) => c.kind == ObservationChangeKind.persisted,
          ) &&
          metricChanges.isEmpty,
    );
  }

  final List<ObservationChange> observationChanges;
  final List<MetricChange> metricChanges;

  /// True when nothing observable changed — the comparison plainly says
  /// "similar to your first try" rather than forcing an improvement claim.
  final bool isMateriallySame;

  static ObservationChangeKind _kindFor(
    BehaviorCode code,
    Set<BehaviorCode> firstCodes,
    Set<BehaviorCode> repeatCodes,
  ) {
    final inFirst = firstCodes.contains(code);
    final inRepeat = repeatCodes.contains(code);
    if (inFirst && !inRepeat) return ObservationChangeKind.resolved;
    if (!inFirst && inRepeat) return ObservationChangeKind.appeared;
    return ObservationChangeKind.persisted;
  }

  static List<MetricChange> _fillers(VoiceMetrics first, VoiceMetrics repeat) {
    if (repeat.fillerCount == first.fillerCount) return const [];
    return [
      MetricChange(
        kind: MetricKind.fillers,
        direction: repeat.fillerCount < first.fillerCount
            ? MetricDirection.improved
            : MetricDirection.worsened,
      ),
    ];
  }

  static List<MetricChange> _pauses(VoiceMetrics first, VoiceMetrics repeat) {
    if (repeat.longPauses == first.longPauses) return const [];
    return [
      MetricChange(
        kind: MetricKind.pauses,
        direction: repeat.longPauses < first.longPauses
            ? MetricDirection.improved
            : MetricDirection.worsened,
      ),
    ];
  }

  static List<MetricChange> _pace(VoiceMetrics first, VoiceMetrics repeat) {
    final firstWpm = first.wordsPerMinute;
    final repeatWpm = repeat.wordsPerMinute;
    if (firstWpm == null || repeatWpm == null || firstWpm == repeatWpm) {
      return const [];
    }
    return [
      MetricChange(
        kind: MetricKind.pace,
        direction: _towardsSteadyBand(firstWpm) > _towardsSteadyBand(repeatWpm)
            ? MetricDirection.improved
            : MetricDirection.worsened,
      ),
    ];
  }

  /// Distance outside the steady 100-170 wpm band (0 when inside it).
  static int _towardsSteadyBand(int wpm) {
    if (wpm < 100) return 100 - wpm;
    if (wpm > 170) return wpm - 170;
    return 0;
  }

  static List<MetricChange> _volume(VoiceMetrics first, VoiceMetrics repeat) {
    final firstSpread = first.volumeSpreadDb;
    final repeatSpread = repeat.volumeSpreadDb;
    if (firstSpread == null ||
        repeatSpread == null ||
        firstSpread == repeatSpread) {
      return const [];
    }
    return [
      MetricChange(
        kind: MetricKind.volume,
        direction: repeatSpread < firstSpread
            ? MetricDirection.improved
            : MetricDirection.worsened,
      ),
    ];
  }
}
