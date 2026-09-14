import 'dart:convert';

import 'package:content/src/sql/seed_sql_parser.dart';

/// Turns the rows of `supabase/seed.sql` into word maps ready to be written as
/// `content/words/<slug>.yml`.
///
/// One-shot: after the import, the YAML files are the source of truth and the
/// seed is generated from them.
List<Map<String, Object?>> importSeedWords(String sql) {
  final rows = parseSeedRows(sql);
  final words = rows['words'] ?? const <Map<String, Object?>>[];
  final confusions = rows['word_confusions'] ?? const <Map<String, Object?>>[];
  final exercises = rows['exercises'] ?? const <Map<String, Object?>>[];
  final options = rows['exercise_options'] ?? const <Map<String, Object?>>[];
  final readings = rows['readings'] ?? const <Map<String, Object?>>[];

  final optionsByExercise = <String, List<Map<String, Object?>>>{};
  for (final option in options) {
    optionsByExercise
        .putIfAbsent(option['exercise_id']! as String, () => [])
        .add(option);
  }

  final imported = <Map<String, Object?>>[];
  for (final row in words) {
    final id = row['id']! as String;
    final slug = row['slug']! as String;
    final replaces = (jsonDecode(row['replaces']! as String) as List<Object?>)
        .cast<Map<String, Object?>>();

    List<Map<String, Object?>> childrenOf(List<Map<String, Object?>> table) =>
        [
          for (final child in table)
            if (child['word_id'] == id) child,
        ]..sort(
          (a, b) => ((a['position'] as int?) ?? 0).compareTo(
            (b['position'] as int?) ?? 0,
          ),
        );

    imported.add(<String, Object?>{
      'schema_version': 1,
      'id': id,
      'sort_order': row['sort_order'],
      'slug': slug,
      // The imported seed predates the validator suite: it is `approved`
      // because it is live content, and `content:validate` is expected to
      // report exactly how it falls short of the new rules.
      'status': 'approved',
      'lemma': row['lemma'],
      'part_of_speech': row['part_of_speech'],
      'syllables': (row['syllables']! as List<Object?>).cast<String>(),
      'stressed_syllable': row['stressed_syllable'],
      'ipa_latam': row['ipa_latam'],
      'ipa_es': row['ipa_es'],
      'explanation': row['explanation'],
      'example_sentence': row['example_sentence'],
      'register': row['register'],
      'pedantry_risk': row['pedantry_risk'],
      'usage_tip': row['usage_tip'],
      'when_not_to_use': row['when_not_to_use'],
      'collocations': (row['collocations']! as List<Object?>).cast<String>(),
      'replaces': [
        for (final pair in replaces)
          {'before': pair['before'], 'after': pair['after']},
      ],
      'family': (row['family']! as List<Object?>).cast<String>(),
      'semantic_set_id': row['semantic_set_id'],
      'themes': <Map<String, Object?>>[],
      'tags': <String, Object?>{
        'comodin': <String>[],
        'funcion': <String>[],
        'canal': 'ambos',
        'formalidad': 'neutral',
        'variedad': 'panhispanico',
      },
      'confusions': [
        for (final confusion in confusions)
          if (confusion['word_id'] == id)
            {
              'confused_with': confusion['confused_with'],
              'difference': confusion['difference'],
              'memory_trick': confusion['memory_trick'],
            },
      ],
      'exercises': [
        for (final exercise in childrenOf(exercises))
          {
            'id': exercise['id'],
            'position': exercise['position'],
            'sentence': exercise['sentence'],
            'hint_general': exercise['hint_general'],
            'explanation': exercise['explanation'],
            'options': [
              for (final option
                  in (optionsByExercise[exercise['id']] ??
                        <Map<String, Object?>>[])
                    ..sort(
                      (a, b) => (a['position']! as int).compareTo(
                        b['position']! as int,
                      ),
                    ))
                {
                  'position': option['position'],
                  'text': option['text'],
                  'is_correct': option['is_correct'],
                  'distractor_type': option['distractor_type'],
                  'why_not': option['why_not'],
                  'hint_specific': option['hint_specific'],
                },
            ],
          },
      ],
      'readings': [
        for (final reading in childrenOf(readings))
          {
            'position': reading['position'],
            'scene': reading['scene'],
            'conversation_type': reading['conversation_type'],
            'title': reading['title'],
            'body': reading['body'],
            'before_phrase': reading['before_phrase'],
            'after_phrase': reading['after_phrase'],
          },
      ],
      'provenance': <String, Object?>{
        'generator': 'content:import from supabase/seed.sql',
        'gate': null,
        'checked_on': null,
      },
    });
  }
  return imported;
}
