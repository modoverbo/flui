import 'package:content/src/model/word.dart';
import 'package:content/src/validation/catalog.dart';
import 'package:content/src/validation/library_text.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';
import '../support/validation_harness.dart';

/// A clone of the canonical word with a new identity, so library-level checks
/// can be exercised with a realistic catalog.
Word clone(
  String slug, {
  List<String>? sentences,
  List<Map<String, Object?>>? themes,
  List<String>? comodin,
  List<String>? funcion,
  List<String>? confusedWith,
  List<String>? family,
  String? status,
  int? pedantryRisk,
}) {
  final map = validWordMap()
    ..['slug'] = slug
    ..['lemma'] = slug
    ..['syllables'] = [slug]
    ..['stressed_syllable'] = 1
    ..['family'] = family ?? <String>['$slug-mente']
    ..['status'] = status ?? 'approved'
    ..['pedantry_risk'] = pedantryRisk ?? 1;
  if (themes != null) map['themes'] = themes;
  if (comodin != null || funcion != null) {
    final tags = Map<String, Object?>.from(
      map['tags']! as Map<String, Object?>,
    );
    if (comodin != null) tags['comodin'] = comodin;
    if (funcion != null) tags['funcion'] = funcion;
    map['tags'] = tags;
  }
  if (confusedWith != null) {
    map['confusions'] = [
      for (final other in confusedWith)
        {
          'confused_with': other,
          'difference': 'Una diferencia clara entre las dos palabras.',
          'memory_trick': 'Un truco corto para recordarla.',
        },
    ];
  }
  if (sentences != null) {
    final exercises = (map['exercises']! as List<Object?>)
        .cast<Map<String, Object?>>();
    for (var i = 0; i < exercises.length && i < sentences.length; i++) {
      exercises[i]['sentence'] = sentences[i];
    }
  }
  return Word.fromMap(map);
}

List<Map<String, Object?>> themeRefs(String slug) => [
  {'slug': slug, 'relevance': 3},
];

void main() {
  group('SentenceUniquenessValidator', () {
    const validator = SentenceUniquenessValidator();

    test('accepts a library whose sentences are all different', () {
      expect(runLibrary(validator, [validWord()]), isEmpty);
    });

    test('flags two words that reuse the same sentence', () {
      final other = clone('plantear');
      expect(runLibrary(validator, [validWord(), other]), isNotEmpty);
    });

    test('flags near duplicates above the Jaccard threshold', () {
      final a = clone(
        'uno',
        sentences: [
          'Andrés confía plenamente en su equipo, pero es tan {{blank}} que detectó el error de las cifras enseguida.',
        ],
      );
      final b = clone(
        'dos',
        sentences: [
          'Andrés confía plenamente en su equipo, pero es tan {{blank}} que detectó el error de las cifras al momento.',
        ],
      );
      final issues = runLibrary(validator, [a, b]);
      expect(issues.map((i) => i.code), contains('sentence_uniqueness'));
    });
  });

  group('TemplateDiversityValidator', () {
    const validator = TemplateDiversityValidator();

    test('accepts the canonical word', () {
      expect(runLibrary(validator, [validWord()]), isEmpty);
    });

    test('rejects three sentences of one word sharing an opening trigram', () {
      final word = clone(
        'uno',
        sentences: [
          'Durante la cena, Ana notó que algo {{blank}} pasaba con su hermano.',
          'Durante la cena, Luis vio que nadie {{blank}} decía la verdad.',
          'Durante la cena, Eva contó que el plan {{blank}} había cambiado.',
        ],
      );
      expect(runLibrary(validator, [word]), isNotEmpty);
    });

    test('rejects a syntactic frame reused beyond the library limit', () {
      final words = [
        for (var i = 0; i < 3; i++)
          clone(
            'palabra$i',
            sentences: [
              for (var j = 0; j < 8; j++)
                'En la reunión de ${_ordinal(i * 8 + j)} el equipo fue muy {{blank}} con el plan.',
            ],
          ),
      ];
      expect(runLibrary(validator, words), isNotEmpty);
    });
  });

  group('NameDiversityValidator', () {
    const validator = NameDiversityValidator();

    test('sleeps on a library too small for a percentage to mean anything', () {
      expect(runLibrary(validator, [validWord()]), isEmpty);
    });

    test('flags a personal name that dominates the library', () {
      final words = [
        for (var i = 0; i < 4; i++)
          clone(
            'palabra$i',
            sentences: [
              for (var j = 0; j < 8; j++)
                'Camila dijo que el punto ${_ordinal(i * 8 + j)} era {{blank}} para todos.',
            ],
          ),
      ];
      final issues = runLibrary(validator, words);
      expect(issues, isNotEmpty);
      expect(issues.first.message.toLowerCase(), contains('camila'));
    });
  });

  group('DuplicateLemmaValidator', () {
    const validator = DuplicateLemmaValidator();

    test('accepts distinct lemmas and families', () {
      expect(
        runLibrary(validator, [clone('uno'), clone('dos')]),
        isEmpty,
      );
    });

    test('rejects two words with the same lemma', () {
      expect(runLibrary(validator, [clone('uno'), clone('uno')]), isNotEmpty);
    });

    test('rejects a lemma that is another word family member', () {
      final a = clone('matizar', family: ['matiz']);
      final b = clone('matiz', family: ['matices']);
      expect(runLibrary(validator, [a, b]), isNotEmpty);
    });

    test('rejects a family member claimed by two words', () {
      final a = clone('uno', family: ['compartida']);
      final b = clone('dos', family: ['compartida']);
      expect(runLibrary(validator, [a, b]), isNotEmpty);
    });
  });

  group('ThemeTaxonomyValidator', () {
    const validator = ThemeTaxonomyValidator();

    test('accepts a theme from the taxonomy', () {
      expect(runWord(validator, validWord()), isEmpty);
    });

    test('rejects an unknown theme slug', () {
      final word = clone('uno', themes: themeRefs('no-existe'));
      expect(runWord(validator, word), isNotEmpty);
    });

    test('rejects an empty theme list', () {
      final word = clone('uno', themes: const []);
      expect(runWord(validator, word), isNotEmpty);
    });

    test('rejects more than three themes', () {
      final word = clone(
        'uno',
        themes: [
          ...themeRefs('reuniones'),
          ...themeRefs('entrevistas'),
          ...themeRefs('negociacion'),
          ...themeRefs('paronimos'),
        ],
      );
      expect(runWord(validator, word), isNotEmpty);
    });

    test('rejects a relevance outside 1..3', () {
      final word = clone(
        'uno',
        themes: [
          {'slug': 'reuniones', 'relevance': 4},
        ],
      );
      expect(runWord(validator, word), isNotEmpty);
    });

    test('rejects a repeated theme', () {
      final word = clone(
        'uno',
        themes: [
          ...themeRefs('reuniones'),
          ...themeRefs('reuniones'),
        ],
      );
      expect(runWord(validator, word), isNotEmpty);
    });
  });

  group('PedantryGateValidator', () {
    const validator = PedantryGateValidator();

    test('accepts an approved word with pedantry risk 2', () {
      expect(runWord(validator, clone('uno', pedantryRisk: 2)), isEmpty);
    });

    test('rejects an approved word with pedantry risk 3', () {
      expect(runWord(validator, clone('uno', pedantryRisk: 3)), isNotEmpty);
    });

    test('allows a draft with pedantry risk 3', () {
      expect(
        runWord(validator, clone('uno', pedantryRisk: 3, status: 'draft')),
        isEmpty,
      );
    });
  });

  group('shareSemanticSet', () {
    Word withSet(
      String slug,
      String? setId, {
      List<String> comodin = const [],
    }) {
      final map = validWordMap()
        ..['slug'] = slug
        ..['lemma'] = slug
        ..['syllables'] = [slug]
        ..['stressed_syllable'] = 1
        ..['semantic_set_id'] = setId;
      final tags = Map<String, Object?>.from(
        map['tags']! as Map<String, Object?>,
      );
      tags['comodin'] = comodin;
      tags['funcion'] = <String>[];
      map['tags'] = tags;
      return Word.fromMap(map);
    }

    test('two words with the same explicit id share a set', () {
      expect(
        shareSemanticSet(
          withSet('contundente', 'fuerza-de-la-afirmacion'),
          withSet('matizar', 'fuerza-de-la-afirmacion'),
        ),
        isTrue,
      );
    });

    test('the explicit id wins over the tag heuristic', () {
      // Same comodín tag, different declared sets: the author has said these
      // are not the same kind of word, and that is the authority.
      expect(
        shareSemanticSet(
          withSet('uno', 'fuerza-de-la-afirmacion', comodin: ['bueno']),
          withSet('dos', 'grado-de-certeza', comodin: ['bueno']),
        ),
        isFalse,
      );
    });

    test('falls back to the tags when a word declares no set', () {
      expect(
        shareSemanticSet(
          withSet('uno', null, comodin: ['bueno']),
          withSet('dos', null, comodin: ['bueno']),
        ),
        isTrue,
      );
      expect(
        shareSemanticSet(
          withSet('uno', 'fuerza-de-la-afirmacion', comodin: ['bueno']),
          withSet('dos', null, comodin: ['bueno']),
        ),
        isTrue,
      );
    });

    test('unrelated words share nothing', () {
      expect(
        shareSemanticSet(
          withSet('uno', 'fuerza-de-la-afirmacion', comodin: ['bueno']),
          withSet('dos', null, comodin: ['listo']),
        ),
        isFalse,
      );
    });
  });

  group('SchedulingSimulationValidator', () {
    const validator = SchedulingSimulationValidator();

    test('fails when a theme cannot feed 90 days', () {
      final words = [
        for (var i = 0; i < 5; i++)
          clone(
            'palabra$i',
            themes: themeRefs('reuniones'),
            comodin: ['c$i'],
            funcion: ['f$i'],
          ),
      ];
      final issues = runLibrary(validator, words);
      expect(issues, isNotEmpty);
      expect(issues.first.message, contains('reuniones'));
    });

    test('passes when the theme has a deep enough pool', () {
      final words = [
        for (var i = 0; i < 95; i++)
          clone(
            'palabra$i',
            themes: themeRefs('reuniones'),
            comodin: ['c$i'],
            funcion: ['f$i'],
          ),
      ];
      expect(runLibrary(validator, words), isEmpty);
    });

    test('starves when every word in the pool shares one semantic set', () {
      final words = [
        for (var i = 0; i < 95; i++)
          clone(
            'palabra$i',
            themes: themeRefs('reuniones'),
            comodin: ['listo'],
            funcion: ['elogiar'],
          ),
      ];
      expect(runLibrary(validator, words), isNotEmpty);
    });

    test('ignores themes with no approved words at all', () {
      final words = [
        for (var i = 0; i < 95; i++)
          clone(
            'palabra$i',
            themes: themeRefs('reuniones'),
            comodin: ['c$i'],
            funcion: ['f$i'],
          ),
      ];
      final issues = runLibrary(validator, words);
      expect(issues.where((i) => i.message.contains('entrevistas')), isEmpty);
    });
  });
}

String _ordinal(int n) => 'punto$n';
