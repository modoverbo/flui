import 'package:flui/features/vocabulary/domain/exercises/form_recall_check.dart';
import 'package:flui/features/vocabulary/domain/exercises/word_forms.dart';
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

  group('FormRecallCheck.submitHeard', () {
    FormRecallCheck start() =>
        const FormRecallCheck(expectedForm: 'perspicaz', forms: perspicaz);

    test(
      'an empty transcript leaves the state unchanged, no hint consumed',
      () {
        final check = start().submitHeard('   ');

        expect(check.status, FormRecallStatus.pending);
        expect(check.hintsUsed, 0);
        expect(check.lastHeard, isNull);
        expect(check, start());
      },
    );

    test('a matching heard transcript accepts and stores lastHeard', () {
      final check = start().submitHeard('Yo diría que es muy perspicaz');

      expect(check.status, FormRecallStatus.accepted);
      expect(check.hintsUsed, 0);
      expect(check.countsAsDone, isTrue);
      expect(check.lastHeard, 'Yo diría que es muy perspicaz');
    });

    test('a mismatching heard transcript gives hints with typed parity', () {
      final one = start().submitHeard('creo que es muy listo');
      expect(one.status, FormRecallStatus.pending);
      expect(one.hintsUsed, 1);
      expect(one.lastAnswerRejected, isTrue);
      expect(one.lastHeard, 'creo que es muy listo');

      final two = one.submitHeard('diría que es avispado');
      expect(two.hintsUsed, 2);
      expect(two.firstLetter, 'p');

      final revealed = two.submitHeard('me parece agudo');
      expect(revealed.status, FormRecallStatus.revealed);
      expect(revealed.countsAsDone, isFalse);
    });

    test('a resolved check ignores more heard input too', () {
      final accepted = start().submitHeard('qué persona tan perspicaz');

      expect(accepted.submitHeard('otra cosa'), accepted);
    });
  });
}
