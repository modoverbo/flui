import 'package:content/src/library/challenge_source.dart';
import 'package:content/src/validation/challenge_runner.dart';
import 'package:test/test.dart';

ChallengeSource _source(String slug, Map<String, Object?> raw) =>
    ChallengeSource(path: 'challenges/$slug.yml', slug: slug, raw: raw);

Map<String, Object?> _validTraining(String slug, {int difficulty = 1}) => {
  'slug': slug,
  'status': 'approved',
  'purpose': 'training',
  'diagnosis_slot': null,
  'skill': 'thinking',
  'mode': 'think_and_speak',
  'difficulty': difficulty,
  'prompt': 'Cuéntame una decisión pequeña que mejoró tu día.',
  'cue': 'Empieza por la decisión y luego di qué cambió.',
  'focus': 'Di tu idea principal en la primera frase.',
  'focus_behaviors': ['main_point_late'],
  'transfer_prompts': [
    'Ahora cuéntame una decisión que cambiarías si pudieras.',
  ],
  'target_seconds': 30,
};

Map<String, Object?> _validDiagnosis(String slug, {int slot = 1}) => {
  'slug': slug,
  'status': 'approved',
  'purpose': 'diagnosis',
  'diagnosis_slot': slot,
  'skill': 'voice',
  'mode': null,
  'difficulty': 1,
  'prompt': 'Cuéntame cómo fue tu semana.',
  'cue': null,
  'focus': 'Habla con un ritmo constante, sin apurarte.',
  'focus_behaviors': <String>[],
  'transfer_prompts': <String>[],
  'target_seconds': 30,
};

void main() {
  const runner = ChallengeValidationRunner();

  test('a broken file reports a parse error and never a model issue', () {
    final report = runner.run([
      const ChallengeSource(
        path: 'challenges/broken.yml',
        slug: 'broken',
        raw: {},
        parseError: 'unexpected character',
      ),
    ]);
    expect(report.issuesBySlug['broken'], hasLength(1));
    expect(report.issuesBySlug['broken']!.single.code, 'yaml');
    expect(report.passed, isFalse);
  });

  test(
    'per-file issues surface under their own slug, not as library issues',
    () {
      final report = runner.run([
        _source(
          'decision-que-mejoro-tu-dia',
          _validTraining(
            'decision-que-mejoro-tu-dia',
          )..['focus_behaviors'] = ['vague_word'],
        ),
      ]);
      expect(
        report.issuesBySlug['decision-que-mejoro-tu-dia'],
        isNotEmpty,
      );
      // Library-level coverage still fails (only 1 of 4 modes covered), but
      // the focus_behaviors mismatch itself must stay a per-file issue.
      expect(
        report.issuesBySlug['decision-que-mejoro-tu-dia']!.any(
          (i) => i.code == 'focus_behaviors_catalog',
        ),
        isTrue,
      );
    },
  );

  test('the library pass runs across every successfully parsed challenge', () {
    final report = runner.run([
      _source('a', _validDiagnosis('a')),
      _source('a-again', _validDiagnosis('a-again')),
    ]);
    // Both diagnosis_slot 1 challenges use context that duplicates nothing,
    // but slots 2 and 3 have zero approved challenges — a library issue, not
    // tied to either file's own slug.
    expect(
      report.libraryIssues.any(
        (i) =>
            i.code == 'diagnosis_slot_coverage' && i.location.contains('[2]'),
      ),
      isTrue,
    );
    expect(report.passed, isFalse);
  });

  test(
    'includeLibraryPass: false skips the coverage/uniqueness checks for a '
    'single-challenge run',
    () {
      final report = runner.run([
        _source('a', _validDiagnosis('a')),
      ], includeLibraryPass: false);
      expect(report.libraryIssues, isEmpty);
      expect(report.passed, isTrue);
    },
  );

  test('a fully covered, clean library passes with zero blocking issues', () {
    final sources = [
      for (var slot = 1; slot <= 3; slot++)
        for (var variant = 0; variant < 2; variant++)
          _source(
            'diagnostico-$slot-$variant',
            _validDiagnosis('diagnostico-$slot-$variant', slot: slot),
          ),
      for (final mode in [
        'think_and_speak',
        'speak_with_precision',
        'master_your_voice',
        'real_situations',
      ])
        for (var difficulty = 1; difficulty <= 3; difficulty++)
          _source(
            'entreno-${mode.replaceAll('_', '-')}-$difficulty',
            _validTraining(
              'entreno-${mode.replaceAll('_', '-')}-$difficulty',
              difficulty: difficulty,
            )..['mode'] = mode,
          ),
    ];
    final report = runner.run(sources);
    expect(
      report.allIssues.where((i) => i.isBlocking),
      isEmpty,
      reason: report.format(),
    );
    expect(report.passed, isTrue);
    expect(report.parsedCount, sources.length);
  });
}
