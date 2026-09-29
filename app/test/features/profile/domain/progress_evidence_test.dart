import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/profile/domain/progress_evidence.dart';
import 'package:flui/features/training/domain/attempt_kind.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/observation.dart';
import 'package:flui/features/training/domain/polarity.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/speaking_attempt.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:flui/features/training/domain/voice_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

const _metrics = VoiceMetrics(longPauses: 0, usefulPauses: 0, fillerCount: 0);

Observation _obs(BehaviorCode code) =>
    Observation(code: code, source: ObservationSource.ai);

SpeakingAttempt _attempt({
  required String id,
  TrainingContext context = TrainingContext.daily,
  List<Observation> observations = const <Observation>[],
}) => SpeakingAttempt(
  id: id,
  sessionId: id,
  context: context,
  kind: AttemptKind.first,
  localDate: LocalDate(2026, 9, 14),
  transcript: 'Hablé sobre mi rutina diaria.',
  duration: const Duration(seconds: 20),
  metrics: _metrics,
  audio: const AudioRetention.none(),
  observations: observations,
);

/// Pulls out the [SkillTrend] for one [area] from an already-computed
/// [BeforeNowComparison] — every call site asserts the cast first.
SkillTrend _trendForArea(BeforeNow beforeNow, SkillArea area) {
  final comparison = beforeNow as BeforeNowComparison;
  return comparison.trends.firstWhere((trend) => trend.area == area);
}

void main() {
  group('SkillTrend direction', () {
    test('no opportunities observed in either window -> steady, still '
        'cites the real evidence behind it (never empty)', () {
      final evidence = ProgressEvidence.compute(
        baselineAttempts: [
          _attempt(
            id: 'b1',
            context: TrainingContext.diagnosis,
            observations: [_obs(BehaviorCode.clearMainPoint)],
          ),
        ],
        nowAttempts: [
          _attempt(id: 'n1', observations: [_obs(BehaviorCode.clearMainPoint)]),
        ],
        isRetake: false,
      );

      final trend = _trendForArea(
        evidence.beforeNow,
        SkillArea.thinking,
      ) as SkillTrendComputed;
      expect(trend.direction, TrendDirection.steady);
      expect(trend.evidence, [
        const SkillTrendEvidence(
          attemptId: 'n1',
          code: BehaviorCode.clearMainPoint,
          polarity: Polarity.strength,
        ),
      ]);
    });

    test('every opportunity present before is gone in now -> improving, '
        'evidence cites the resolved opportunity and the new strength', () {
      final evidence = ProgressEvidence.compute(
        baselineAttempts: [
          _attempt(
            id: 'b1',
            context: TrainingContext.diagnosis,
            observations: [_obs(BehaviorCode.mainPointLate)],
          ),
        ],
        nowAttempts: [
          _attempt(id: 'n1', observations: [_obs(BehaviorCode.clearMainPoint)]),
        ],
        isRetake: false,
      );

      final trend = _trendForArea(
        evidence.beforeNow,
        SkillArea.thinking,
      ) as SkillTrendComputed;
      expect(trend.direction, TrendDirection.improving);
      expect(trend.evidence, [
        const SkillTrendEvidence(
          attemptId: 'b1',
          code: BehaviorCode.mainPointLate,
          polarity: Polarity.opportunity,
        ),
        const SkillTrendEvidence(
          attemptId: 'n1',
          code: BehaviorCode.clearMainPoint,
          polarity: Polarity.strength,
        ),
      ]);
    });

    test('an opportunity present in both before and now -> needsWork, '
        'evidence cites the NOW attempt (freshest), not the before one', () {
      final evidence = ProgressEvidence.compute(
        baselineAttempts: [
          _attempt(
            id: 'b1',
            context: TrainingContext.diagnosis,
            observations: [_obs(BehaviorCode.longPauses)],
          ),
        ],
        nowAttempts: [
          _attempt(id: 'n1', observations: [_obs(BehaviorCode.longPauses)]),
        ],
        isRetake: false,
      );

      final trend = _trendForArea(
        evidence.beforeNow,
        SkillArea.fluency,
      ) as SkillTrendComputed;
      expect(trend.direction, TrendDirection.needsWork);
      expect(trend.evidence, [
        const SkillTrendEvidence(
          attemptId: 'n1',
          code: BehaviorCode.longPauses,
          polarity: Polarity.opportunity,
        ),
      ]);
    });

    test('a new opportunity appears in now that was not in before -> '
        'needsWork', () {
      final evidence = ProgressEvidence.compute(
        baselineAttempts: [
          _attempt(
            id: 'b1',
            context: TrainingContext.diagnosis,
            observations: [_obs(BehaviorCode.steadyPace)],
          ),
        ],
        nowAttempts: [
          _attempt(id: 'n1', observations: [_obs(BehaviorCode.paceFast)]),
        ],
        isRetake: false,
      );

      final trend = _trendForArea(
        evidence.beforeNow,
        SkillArea.voice,
      ) as SkillTrendComputed;
      expect(trend.direction, TrendDirection.needsWork);
    });

    test('mixed polarity: an opportunity and a strength observed in the '
        'same now window -> needsWork (the opportunity is honest even '
        'with a strength alongside it), evidence includes both', () {
      final evidence = ProgressEvidence.compute(
        baselineAttempts: [
          _attempt(
            id: 'b1',
            context: TrainingContext.diagnosis,
            observations: [_obs(BehaviorCode.clearMainPoint)],
          ),
        ],
        nowAttempts: [
          _attempt(
            id: 'n1',
            observations: [
              _obs(BehaviorCode.paceFast),
              _obs(BehaviorCode.steadyVolume),
            ],
          ),
        ],
        isRetake: false,
      );

      final trend = _trendForArea(
        evidence.beforeNow,
        SkillArea.voice,
      ) as SkillTrendComputed;
      expect(trend.direction, TrendDirection.needsWork);
      expect(trend.evidence, [
        const SkillTrendEvidence(
          attemptId: 'n1',
          code: BehaviorCode.paceFast,
          polarity: Polarity.opportunity,
        ),
        const SkillTrendEvidence(
          attemptId: 'n1',
          code: BehaviorCode.steadyVolume,
          polarity: Polarity.strength,
        ),
      ]);
    });
  });

  group('SkillTrend minimum evidence threshold', () {
    test('exactly at the minimum evidence count -> a trend is computed, '
        'never left unstated', () {
      final observations = [
        for (var i = 0; i < ProgressEvidence.minimumEvidenceCount; i++)
          _attempt(id: 'n$i', observations: [_obs(BehaviorCode.mainPointLate)]),
      ];

      final evidence = ProgressEvidence.compute(
        baselineAttempts: [
          _attempt(id: 'b0', context: TrainingContext.diagnosis),
        ],
        nowAttempts: observations,
        isRetake: false,
      );

      final trend = _trendForArea(evidence.beforeNow, SkillArea.thinking);
      expect(trend, isA<SkillTrendComputed>());
    });

    test('one below the minimum evidence count -> insufficient evidence, '
        'never a fabricated trend', () {
      final observations = [
        for (var i = 0; i < ProgressEvidence.minimumEvidenceCount - 1; i++)
          _attempt(id: 'n$i', observations: [_obs(BehaviorCode.mainPointLate)]),
      ];

      final evidence = ProgressEvidence.compute(
        baselineAttempts: [
          _attempt(id: 'b0', context: TrainingContext.diagnosis),
        ],
        nowAttempts: observations,
        isRetake: false,
      );

      final trend = _trendForArea(evidence.beforeNow, SkillArea.thinking);
      expect(trend, isA<SkillTrendInsufficientEvidence>());
    });
  });

  group('BeforeNow labeled variants (decision #429)', () {
    test('a completed retake -> formally labeled comparison', () {
      final evidence = ProgressEvidence.compute(
        baselineAttempts: [
          _attempt(
            id: 'b1',
            context: TrainingContext.diagnosis,
            observations: [_obs(BehaviorCode.mainPointLate)],
          ),
        ],
        nowAttempts: [
          _attempt(
            id: 'n1',
            context: TrainingContext.diagnosis,
            observations: [_obs(BehaviorCode.clearMainPoint)],
          ),
        ],
        isRetake: true,
      );

      final comparison = evidence.beforeNow as BeforeNowComparison;
      expect(comparison.label, BeforeNowLabel.formal);
    });

    test('no retake yet, recent attempts instead -> indicative, never '
        'presented as a formal retake comparison', () {
      final evidence = ProgressEvidence.compute(
        baselineAttempts: [
          _attempt(
            id: 'b1',
            context: TrainingContext.diagnosis,
            observations: [_obs(BehaviorCode.mainPointLate)],
          ),
        ],
        nowAttempts: [
          _attempt(id: 'n1', observations: [_obs(BehaviorCode.clearMainPoint)]),
        ],
        isRetake: false,
      );

      final comparison = evidence.beforeNow as BeforeNowComparison;
      expect(comparison.label, BeforeNowLabel.indicative);
    });

    test('every SkillArea gets exactly one trend, even an untouched one', () {
      final evidence = ProgressEvidence.compute(
        baselineAttempts: [
          _attempt(
            id: 'b1',
            context: TrainingContext.diagnosis,
            observations: [_obs(BehaviorCode.mainPointLate)],
          ),
        ],
        nowAttempts: [
          _attempt(id: 'n1', observations: [_obs(BehaviorCode.clearMainPoint)]),
        ],
        isRetake: false,
      );

      final comparison = evidence.beforeNow as BeforeNowComparison;
      expect(
        comparison.trends.map((t) => t.area).toSet(),
        SkillArea.values.toSet(),
      );
      expect(comparison.trends.length, SkillArea.values.length);
    });
  });

  group('BeforeNow insufficient evidence', () {
    test('a baseline with no recent attempts at all -> insufficient '
        'evidence, not a fabricated comparison', () {
      final evidence = ProgressEvidence.compute(
        baselineAttempts: [
          _attempt(
            id: 'b1',
            context: TrainingContext.diagnosis,
            observations: [_obs(BehaviorCode.mainPointLate)],
          ),
        ],
        nowAttempts: const [],
        isRetake: false,
      );

      expect(evidence.beforeNow, isA<BeforeNowInsufficientEvidence>());
    });

    test('recent attempts with no baseline -> insufficient evidence', () {
      final evidence = ProgressEvidence.compute(
        baselineAttempts: const [],
        nowAttempts: [
          _attempt(id: 'n1', observations: [_obs(BehaviorCode.clearMainPoint)]),
        ],
        isRetake: false,
      );

      expect(evidence.beforeNow, isA<BeforeNowInsufficientEvidence>());
    });

    test('neither baseline nor recent attempts -> insufficient evidence', () {
      final evidence = ProgressEvidence.compute(
        baselineAttempts: const [],
        nowAttempts: const [],
        isRetake: false,
      );

      expect(evidence.beforeNow, isA<BeforeNowInsufficientEvidence>());
    });
  });

  group('excluded contexts (design D33/D37: quick and word never count)', () {
    test('a quick-practice row never contributes evidence, even mixed in '
        'with a valid row in the same now window', () {
      final evidence = ProgressEvidence.compute(
        baselineAttempts: [
          _attempt(
            id: 'b1',
            context: TrainingContext.diagnosis,
            observations: [
              _obs(BehaviorCode.mainPointLate),
              _obs(BehaviorCode.vagueWord),
            ],
          ),
        ],
        nowAttempts: [
          // Excluded: its mainPointLate observation must never count, or
          // thinking would reach the threshold and stop being reported as
          // insufficient.
          _attempt(
            id: 'n-quick',
            context: TrainingContext.quick,
            observations: [_obs(BehaviorCode.mainPointLate)],
          ),
          _attempt(id: 'n-daily', observations: [_obs(BehaviorCode.vagueWord)]),
        ],
        isRetake: false,
      );

      // thinking: only the excluded quick row had a thinking observation in
      // "now" -> below the threshold, never fabricated as a trend.
      expect(
        _trendForArea(evidence.beforeNow, SkillArea.thinking),
        isA<SkillTrendInsufficientEvidence>(),
      );
      // language: fed only by the valid daily row -> still computes
      // normally, proving the exclusion did not break unrelated areas.
      expect(
        _trendForArea(evidence.beforeNow, SkillArea.language),
        isA<SkillTrendComputed>(),
      );
    });

    test('a word-exercise row is excluded; when it is the only "now" row, '
        'the whole comparison reports insufficient evidence', () {
      final evidence = ProgressEvidence.compute(
        baselineAttempts: [
          _attempt(
            id: 'b1',
            context: TrainingContext.diagnosis,
            observations: [_obs(BehaviorCode.paceFast)],
          ),
        ],
        nowAttempts: [
          _attempt(
            id: 'n1',
            context: TrainingContext.word,
            observations: [_obs(BehaviorCode.paceFast)],
          ),
        ],
        isRetake: false,
      );

      expect(evidence.beforeNow, isA<BeforeNowInsufficientEvidence>());
    });
  });

  group('no-number contract (spec progress: never a numeric confidence or '
      'aggregate score anywhere)', () {
    test('ProgressEvidence never renders a digit anywhere, even with '
        'digit-bearing attempt ids', () {
      final fixtures = [
        ProgressEvidence.compute(
          baselineAttempts: [
            _attempt(
              id: 'attempt-001',
              context: TrainingContext.diagnosis,
              observations: [_obs(BehaviorCode.mainPointLate)],
            ),
          ],
          nowAttempts: [
            _attempt(
              id: 'session-42',
              observations: [
                _obs(BehaviorCode.paceFast),
                _obs(BehaviorCode.steadyVolume),
              ],
            ),
          ],
          isRetake: true,
        ),
        ProgressEvidence.compute(
          baselineAttempts: const [],
          nowAttempts: const [],
          isRetake: false,
        ),
        ProgressEvidence.compute(
          baselineAttempts: [
            _attempt(
              id: 'b9',
              context: TrainingContext.diagnosis,
              observations: [_obs(BehaviorCode.vagueWord)],
            ),
          ],
          nowAttempts: [
            _attempt(id: 'n9', observations: [_obs(BehaviorCode.preciseWord)]),
          ],
          isRetake: false,
        ),
      ];

      final forbidden = RegExp('[0-9%]|score|puntaje', caseSensitive: false);
      for (final evidence in fixtures) {
        expect(
          forbidden.hasMatch(evidence.toString()),
          isFalse,
          reason:
              'ProgressEvidence.toString() must never surface a number or '
              'score: "$evidence"',
        );
      }
    });
  });
}
