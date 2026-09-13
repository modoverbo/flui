import 'package:flui/features/exercises/domain/production_check.dart';
import 'package:flui/features/exercises/domain/word_forms.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const plantear = WordForms(
    lemma: 'plantear',
    isVerb: true,
    extraForms: ['planteamiento'],
  );

  group('ProductionCheck.validate', () {
    final cases = <(String sentence, ProductionIssue? issue)>[
      ('Quiero plantearte algo importante.', null),
      ('Le planteé cambiar el horario.', null),
      ('Me gustó tu planteamiento del problema.', null),
      ('Plantear algo así.', ProductionIssue.tooShort),
      ('Quiero sacar un tema contigo.', ProductionIssue.missingWord),
      ('', ProductionIssue.tooShort),
      ('Voy a plantar un árbol hoy.', ProductionIssue.missingWord),
    ];
    for (final (sentence, issue) in cases) {
      test('"$sentence" -> $issue', () {
        expect(ProductionCheck.validate(sentence, plantear), issue);
      });
    }
  });

  group('ProductionFlow', () {
    const valid = 'Quiero plantearte algo importante.';

    test('a valid sentence asks the self-check', () {
      final flow = const ProductionFlow(forms: plantear).submit(valid);

      expect(flow.phase, ProductionPhase.selfCheck);
      expect(flow.sentence, valid);
      expect(flow.issue, isNull);
    });

    test('an invalid sentence stays in writing with the issue', () {
      final flow = const ProductionFlow(forms: plantear).submit('Hola.');

      expect(flow.phase, ProductionPhase.writing);
      expect(flow.issue, ProductionIssue.tooShort);
    });

    test('"sí, suena natural" accepts the production', () {
      final flow = const ProductionFlow(forms: plantear)
          .submit(valid)
          .confirmNatural();

      expect(flow.phase, ProductionPhase.accepted);
      expect(flow.isAccepted, isTrue);
    });

    test('"todavía no" returns to writing and keeps the sentence', () {
      final flow = const ProductionFlow(forms: plantear)
          .submit(valid)
          .rejectNatural();

      expect(flow.phase, ProductionPhase.writing);
      expect(flow.sentence, valid);
    });
  });
}
