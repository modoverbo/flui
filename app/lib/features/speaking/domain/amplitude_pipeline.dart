/// Normalises raw dBFS microphone amplitude samples into a smoothed
/// `[0, 1]` drive value for bubble animation.
///
/// Pure Dart — no `dart:ui`, no `package:flutter` — so it is testable
/// without a widget pump and reusable by any renderer.
///
/// Two stages:
///
/// 1. [normalize]: a stateless linear map from `[floorDbfs, ceilingDbfs]`
///    to `[0, 1]`, clamped so no input (including `NaN`/`Infinity`) can
///    escape the range.
/// 2. [addSample]: an asymmetric exponential moving average (an envelope
///    follower, standard for audio-reactive UI) applied on top of
///    [normalize] — attack faster than release, so the bubble responds
///    promptly to a spike in volume but doesn't flicker during brief
///    pauses between words.
///
/// Constants (`attackAlpha = 0.5`, `releaseAlpha = 0.15`), chosen against
/// the recorder's real 120 ms sample cadence
/// (`record`'s `onAmplitudeChanged` interval):
///
/// - Attack time constant `τ = -120ms / ln(1 - 0.5) ≈ 173ms`: a jump from
///   silence to loud reaches ~87% of the target within 2 samples (~240ms)
///   and ~97% within 4 samples (~480ms) — present and prompt, not a jump
///   cut, but still under half a second.
/// - Release time constant `τ = -120ms / ln(1 - 0.15) ≈ 738ms`: decay back
///   towards silence reaches ~63% within one time constant and ~95% only
///   after ~2.2s — slower than a typical inter-word pause (~200-500ms) so
///   the bubble doesn't flicker down and back up between syllables, but
///   still visibly deflates over a couple of seconds of real silence.
///
/// Together this reads as breathing — a living envelope — rather than a
/// twitchy VU meter that jumps with every sample.
class AmplitudePipeline {
  new({
    this.floorDbfs = -60,
    this.ceilingDbfs = 0,
    this.attackAlpha = 0.5,
    this.releaseAlpha = 0.15,
  }) : assert(floorDbfs < ceilingDbfs, 'floorDbfs must be below ceilingDbfs'),
       assert(
         attackAlpha > 0 && attackAlpha <= 1,
         'attackAlpha must be in (0, 1]',
       ),
       assert(
         releaseAlpha > 0 && releaseAlpha <= 1,
         'releaseAlpha must be in (0, 1]',
       );

  /// dBFS at or below this normalises to 0 (rest).
  final double floorDbfs;

  /// dBFS at or above this normalises to 1 (ceiling).
  final double ceilingDbfs;

  /// How fast the smoothed value rises toward a new, louder sample.
  final double attackAlpha;

  /// How fast the smoothed value falls toward a new, quieter sample.
  final double releaseAlpha;

  double _smoothed = 0;

  /// The current smoothed drive value, `[0, 1]`.
  double get smoothed => _smoothed;

  /// Maps a raw dBFS sample to `[0, 1]`, clamped. Stateless — does not
  /// affect [smoothed]. `NaN` is treated as silence (rest); `+Infinity`
  /// clamps to the ceiling; `-Infinity` (a true silent frame, as some
  /// recorders report) clamps to the floor.
  double normalize(double dbfs) {
    if (dbfs.isNaN) return 0;
    final range = ceilingDbfs - floorDbfs;
    final level = (dbfs - floorDbfs) / range;
    if (level.isNaN) return 0;
    return level.clamp(0.0, 1.0);
  }

  /// Feeds one raw dBFS sample through [normalize] and the asymmetric EMA,
  /// updating and returning [smoothed].
  double addSample(double dbfs) {
    final level = normalize(dbfs);
    final alpha = level > _smoothed ? attackAlpha : releaseAlpha;
    final next = _smoothed + alpha * (level - _smoothed);
    return _smoothed = next.isFinite ? next.clamp(0.0, 1.0) : 0;
  }

  /// Returns [smoothed] to rest (0), e.g. when a recording stops.
  void reset() => _smoothed = 0;
}
