import 'package:flui/features/vocabulary/domain/confusability.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/learning_builders.dart';

void main() {
  group('areConfusable (learning-method §7)', () {
    final perspicaz = buildWord(id: 'p', lemma: 'perspicaz');

    test('by confused_word_id from either side', () {
      final suspicaz = buildWord(
        id: 's',
        lemma: 'suspicaz',
        confusions: [
          confusion(wordId: 's', confusedWith: 'otra', confusedWordId: 'p'),
        ],
      );

      expect(areConfusable(perspicaz, suspicaz), isTrue);
      expect(areConfusable(suspicaz, perspicaz), isTrue);
    });

    test('by a case-insensitive confused_with match of the lemma', () {
      final suspicaz = buildWord(
        id: 's',
        lemma: 'Suspicaz',
        confusions: [confusion(wordId: 's', confusedWith: ' PERSPICAZ ')],
      );

      expect(areConfusable(perspicaz, suspicaz), isTrue);
      expect(areConfusable(suspicaz, perspicaz), isTrue);
    });

    test('unrelated words are not confusable', () {
      final zanjar = buildWord(
        id: 'z',
        lemma: 'zanjar',
        confusions: [confusion(wordId: 'z', confusedWith: 'saldar')],
      );

      expect(areConfusable(perspicaz, zanjar), isFalse);
    });

    test('a word is not confusable with itself', () {
      expect(areConfusable(perspicaz, perspicaz), isFalse);
    });
  });
}
