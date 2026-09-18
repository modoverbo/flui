import 'package:content/src/model/catalogue.dart';
import 'package:content/src/model/word.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

/// A catalogue word with a new identity, its family and its confusions.
Word entry(
  String lemma, {
  List<String> family = const [],
  List<String> confusedWith = const [],
  String status = 'approved',
}) => Word.fromMap(
  validWordMap()
    ..['slug'] = lemma
    ..['lemma'] = lemma
    ..['syllables'] = [lemma]
    ..['stressed_syllable'] = 1
    ..['status'] = status
    ..['family'] = family
    ..['confusions'] = [
      for (final other in confusedWith)
        {
          'confused_with': other,
          'difference': 'Una diferencia clara entre las dos palabras.',
          'memory_trick': 'Un truco corto para recordarla.',
        },
    ],
);

void main() {
  group('Catalogue', () {
    test('finds a word by its lemma, ignoring case and accents', () {
      final cesion = entry('cesión');
      final catalogue = Catalogue.of([cesion, entry('concesión')]);

      expect(catalogue.wordNamed('cesión'), same(cesion));
      expect(catalogue.wordNamed('Cesion'), same(cesion));
      expect(catalogue.wordNamed('  CESIÓN  '), same(cesion));
    });

    test('finds a word by one of its family members', () {
      final consensuar = entry('consensuar', family: ['consenso']);
      final catalogue = Catalogue.of([consensuar]);

      expect(catalogue.wordNamed('consenso'), same(consensuar));
      expect(catalogue.wordNamed('Consenso'), same(consensuar));
    });

    test('a lemma wins over another word claiming it as family', () {
      final improvisar = entry('improvisar', family: ['improvisado']);
      final improvisado = entry('improvisado');
      final catalogue = Catalogue.of([improvisar, improvisado]);

      expect(catalogue.wordNamed('improvisado'), same(improvisado));
    });

    test('does not know a word that is not in the catalogue', () {
      expect(Catalogue.of([entry('talante')]).wordNamed('tajante'), isNull);
    });

    test('resolves the confusion a word declares', () {
      final tajante = entry('tajante');
      final talante = entry('talante', confusedWith: ['tajante']);
      final catalogue = Catalogue.of([talante, tajante]);

      expect(
        catalogue.confusableOf(talante, talante.confusions.single),
        same(tajante),
      );
    });

    test('leaves a confusion outside the catalogue unresolved', () {
      final talante = entry('talante', confusedWith: ['semblante']);

      expect(
        Catalogue.of([talante]).confusableOf(talante, talante.confusions.single),
        isNull,
      );
    });

    test('never resolves a confusion to the word that declares it', () {
      // A word may name one of its own family members; that is a note about
      // itself, not a link to another catalogue entry.
      final ensayar = entry(
        'ensayar',
        family: ['ensayo'],
        confusedWith: ['ensayo'],
      );

      expect(
        Catalogue.of([ensayar]).confusableOf(ensayar, ensayar.confusions.single),
        isNull,
      );
    });
  });
}
