import 'package:flui/features/vocabulary/domain/semantic_set_rule.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/learning_builders.dart';

void main() {
  group('SemanticSetRule (learning-method §7)', () {
    final contundente = buildWord(
      id: 'c',
      lemma: 'contundente',
      semanticSetId: 'fuerza-de-la-afirmacion',
    );

    test('two words of the same semantic set interfere, either way round', () {
      final matizar = buildWord(
        id: 'm',
        lemma: 'matizar',
        semanticSetId: 'fuerza-de-la-afirmacion',
      );

      expect(SemanticSetRule.interferes(contundente, matizar), isTrue);
      expect(SemanticSetRule.interferes(matizar, contundente), isTrue);
    });

    test('words of different sets do not interfere', () {
      final zanjar = buildWord(
        id: 'z',
        lemma: 'zanjar',
        semanticSetId: 'cierre-de-asuntos',
      );

      expect(SemanticSetRule.interferes(contundente, zanjar), isFalse);
    });

    test('an untagged word never interferes', () {
      final plantear = buildWord(id: 'p', lemma: 'plantear');

      expect(SemanticSetRule.interferes(contundente, plantear), isFalse);
      expect(SemanticSetRule.interferes(plantear, plantear), isFalse);
    });

    test('a blank set id is not a set', () {
      final blank = buildWord(id: 'b', lemma: 'blanca', semanticSetId: '  ');
      final alsoBlank = buildWord(id: 'b2', lemma: 'otra', semanticSetId: '');

      expect(SemanticSetRule.interferes(blank, alsoBlank), isFalse);
    });

    test('a word does not interfere with itself', () {
      expect(SemanticSetRule.interferes(contundente, contundente), isFalse);
    });

    test('sharing a theme is not sharing a semantic set', () {
      // Tinkham (1993, 1997) and Nation (2000): synonyms, antonyms and
      // category mates interfere; thematic clusters do not. Themes are
      // thematic on purpose, so two words of one theme stay introducible.
      final a = buildWord(id: 'a', lemma: 'zanjar', themeIds: ['reuniones']);
      final b = buildWord(id: 'b', lemma: 'plantear', themeIds: ['reuniones']);

      expect(SemanticSetRule.interferes(a, b), isFalse);
    });

    test('the window is the same 7 days as the paronym rule', () {
      expect(SemanticSetRule.interferenceDays, 7);
    });
  });
}
