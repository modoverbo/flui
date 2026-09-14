import 'package:content/src/cli/shortlist.dart';
import 'package:content/src/corpus/candidate_pool.dart';
import 'package:content/src/model/word.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

CandidateRow candidate(
  String lemma, {
  List<String> themes = const ['reuniones'],
  double score = 0.9,
}) => CandidateRow(
  lemma: lemma,
  pos: 'verbo',
  zipf: 4,
  dp: 0.2,
  pedantryProxy: 0.5,
  familySize: 3,
  comodinLeverage: 0.7,
  suggestedThemes: themes,
  score: score,
  flags: const [],
);

Word libraryWord(
  String lemma, {
  List<String> family = const [],
  List<String> confusedWith = const [],
  List<String> comodin = const ['listo'],
}) {
  final map = validWordMap()
    ..['slug'] = lemma
    ..['lemma'] = lemma
    ..['syllables'] = [lemma]
    ..['stressed_syllable'] = 1
    ..['family'] = family;
  final tags = Map<String, Object?>.from(map['tags']! as Map<String, Object?>);
  tags['comodin'] = comodin;
  map['tags'] = tags;
  if (confusedWith.isNotEmpty) {
    map['confusions'] = [
      for (final other in confusedWith)
        {
          'confused_with': other,
          'difference': 'Una diferencia clara entre las dos palabras.',
          'memory_trick': 'Un truco corto.',
        },
    ];
  }
  return Word.fromMap(map);
}

void main() {
  group('shortlistFor', () {
    test('keeps only candidates carrying the theme', () {
      final result = shortlistFor(
        theme: 'reuniones',
        candidates: [
          candidate('plantear'),
          candidate('elogiar', themes: ['elogio-reconocimiento']),
          candidate('acotar', themes: const []),
        ],
        library: const [],
      );

      expect(result.accepted.map((r) => r.lemma), ['plantear']);
    });

    test('keeps the pool ordering and honours the limit', () {
      final result = shortlistFor(
        theme: 'reuniones',
        candidates: [
          candidate('uno', score: 0.5),
          candidate('dos'),
          candidate('tres', score: 0.7),
        ],
        library: const [],
        limit: 2,
      );

      expect(result.accepted.map((r) => r.lemma), ['dos', 'tres']);
    });

    test('rejects a lemma the library already has', () {
      final result = shortlistFor(
        theme: 'reuniones',
        candidates: [candidate('plantear')],
        library: [libraryWord('plantear')],
      );

      expect(result.accepted, isEmpty);
      expect(result.rejected['plantear'], contains('already in the library'));
    });

    test('rejects a family member of an existing word', () {
      final result = shortlistFor(
        theme: 'reuniones',
        candidates: [candidate('planteamiento')],
        library: [
          libraryWord('plantear', family: ['planteamiento']),
        ],
      );

      expect(result.rejected['planteamiento'], contains('family'));
    });

    test('rejects a paronym of an existing lemma', () {
      final result = shortlistFor(
        theme: 'reuniones',
        candidates: [candidate('plantar')],
        library: [libraryWord('plantear')],
      );

      expect(result.rejected['plantar'], contains('paronym'));
    });

    test('rejects a word an existing confusion already names', () {
      final result = shortlistFor(
        theme: 'reuniones',
        candidates: [candidate('suspicaz')],
        library: [
          libraryWord('avispado', confusedWith: ['suspicaz']),
        ],
      );

      expect(result.rejected['suspicaz'], contains('confusion'));
    });

    test('rejects a semantic-set clash with an existing word', () {
      final result = shortlistFor(
        theme: 'reuniones',
        candidates: [candidate('concretamente')],
        library: [libraryWord('concretar')],
      );

      expect(result.rejected['concretamente'], contains('semantic set'));
    });

    test('accepts a candidate unrelated to everything in the library', () {
      final result = shortlistFor(
        theme: 'reuniones',
        candidates: [candidate('vislumbrar')],
        library: [libraryWord('plantear')],
      );

      expect(result.accepted.map((r) => r.lemma), ['vislumbrar']);
      expect(result.rejected, isEmpty);
    });

    test('reports both the accepted rows and why the rest went', () {
      final result = shortlistFor(
        theme: 'reuniones',
        candidates: [candidate('vislumbrar'), candidate('plantar')],
        library: [libraryWord('plantear')],
      );

      expect(result.accepted, hasLength(1));
      expect(result.rejected.keys, ['plantar']);
      expect(result.toJson()['theme'], 'reuniones');
      expect(result.format(), contains('vislumbrar'));
      expect(result.format(), contains('plantar'));
    });
  });
}
