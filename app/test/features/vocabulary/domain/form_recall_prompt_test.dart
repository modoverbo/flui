import 'package:flui/features/vocabulary/domain/form_recall_prompt.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/learning_builders.dart';

void main() {
  test('masks the word in its example sentence', () {
    final word = buildWord(lemma: 'perspicaz').copyWith(
      exampleSentence: 'Qué observación tan perspicaz: nadie lo notó.',
    );

    final prompt = FormRecallPrompt.forWord(word);

    expect(prompt.before, 'Qué observación tan ');
    expect(prompt.after, ': nadie lo notó.');
    expect(prompt.expectedForm, 'perspicaz');
    expect(prompt.explanation, word.explanation);
  });

  test('expects the inflection used in the sentence', () {
    final word = buildWord(
      lemma: 'zanjar',
      partOfSpeech: PartOfSpeech.verbo,
    ).copyWith(exampleSentence: 'Marta zanjó la discusión con una encuesta.');

    final prompt = FormRecallPrompt.forWord(word);

    expect(prompt.expectedForm, 'zanjó');
    expect(prompt.hasSentence, isTrue);
  });

  test('falls back to the meaning alone when the sentence has no form', () {
    final word = buildWord(lemma: 'zanjar')
        .copyWith(exampleSentence: 'Una frase sin la palabra.');

    final prompt = FormRecallPrompt.forWord(word);

    expect(prompt.hasSentence, isFalse);
    expect(prompt.expectedForm, 'zanjar');
  });
}
