import 'package:flui/features/exercises/domain/form_recall_check.dart';
import 'package:flui/features/exercises/domain/word_forms.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const perspicaz = WordForms(
    lemma: 'perspicaz',
    isVerb: false,
    extraForms: ['perspicacia'],
  );
  const zanjar = WordForms(lemma: 'zanjar', isVerb: true);
  const tenaz = WordForms(lemma: 'tenaz', isVerb: false);

  group('FormRecallCheck.accepts', () {
    final cases = <(WordForms, String expected, String input, bool ok)>[
      (perspicaz, 'perspicaz', 'perspicaz', true),
      (perspicaz, 'perspicaz', ' PERSPICAZ ', true),
      (perspicaz, 'perspicaz', 'perspikaz', true),
      (perspicaz, 'perspicaz', 'perspicacia', true),
      (perspicaz, 'perspicaz', 'suspicaz', false),
      (perspicaz, 'perspicaz', '', false),
      (zanjar, 'zanjó', 'zanjo', true),
      (zanjar, 'zanjó', 'Zanjó', true),
      (zanjar, 'zanjó', 'zanjar', true),
      (zanjar, 'zanjar', 'zanjr', true),
      // Words under 6 letters must be exact (no typo tolerance).
      (tenaz, 'tenaz', 'tenas', false),
      (tenaz, 'tenaz', 'ténaz', true),
    ];
    for (final (forms, expected, input, ok) in cases) {
      test('${forms.lemma}/$expected accepts "$input": $ok', () {
        expect(
          FormRecallCheck.accepts(input, expectedForm: expected, forms: forms),
          ok,
        );
      });
    }
  });

  group('FormRecallCheck flow', () {
    FormRecallCheck start() =>
        const FormRecallCheck(expectedForm: 'perspicaz', forms: perspicaz);

    test('accepts a right answer without hints', () {
      final check = start().submit('perspicaz');

      expect(check.status, FormRecallStatus.accepted);
      expect(check.hintsUsed, 0);
      expect(check.countsAsDone, isTrue);
    });

    test('wrong answers give hint 1, then hint 2, then reveal', () {
      final one = start().submit('listo');
      expect(one.status, FormRecallStatus.pending);
      expect(one.hintsUsed, 1);
      expect(one.lastAnswerRejected, isTrue);

      final two = one.submit('avispado');
      expect(two.hintsUsed, 2);
      expect(two.firstLetter, 'p');

      final revealed = two.submit('agudo');
      expect(revealed.status, FormRecallStatus.revealed);
      expect(revealed.countsAsDone, isFalse);
    });

    test('accepted after hints still counts as done', () {
      final check = start().takeHint().takeHint().submit('perspicaz');

      expect(check.status, FormRecallStatus.accepted);
      expect(check.countsAsDone, isTrue);
    });

    test('asking for a third hint reveals the word', () {
      final check = start().takeHint().takeHint().takeHint();

      expect(check.status, FormRecallStatus.revealed);
    });

    test('an empty answer is ignored', () {
      final check = start().submit('   ');

      expect(check.hintsUsed, 0);
      expect(check.status, FormRecallStatus.pending);
    });

    test('a resolved check ignores more input', () {
      final accepted = start().submit('perspicaz');

      expect(accepted.submit('otra'), accepted);
      expect(accepted.takeHint(), accepted);
    });
  });
}
