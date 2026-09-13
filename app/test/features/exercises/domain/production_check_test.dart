import 'package:flui/features/exercises/domain/production_check.dart';
import 'package:flui/features/exercises/domain/word_forms.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const plantear = WordForms(
    lemma: 'plantear',
    isVerb: true,
    extraForms: ['planteamiento'],
  );
  const model = 'Le planteé al equipo una forma distinta de repartir turnos.';

  group('ProductionCheck.validate', () {
    final cases = <(String sentence, ProductionIssue? issue)>[
      ('Quiero plantearte algo importante.', null),
      ('Le planteé cambiar el horario.', null),
      ('Me gustó tu planteamiento del problema.', null),
      ('Plantear algo así.', ProductionIssue.tooShort),
      ('Quiero sacar un tema contigo.', ProductionIssue.missingWord),
      ('', ProductionIssue.tooShort),
      ('Voy a plantar un árbol hoy.', ProductionIssue.missingWord),
      // Long enough, but not a sentence.
      ('plantear plantear plantear plantear', ProductionIssue.repeated),
      ('a a a a plantear', ProductionIssue.repeated),
      // The model sentence typed back is not production.
      (model, ProductionIssue.copiedModel),
      (
        'le planteé al equipo una forma distinta de repartir turnos',
        ProductionIssue.copiedModel,
      ),
    ];
    for (final (sentence, issue) in cases) {
      test('"$sentence" -> $issue', () {
        expect(
          ProductionCheck.validate(sentence, plantear, modelSentence: model),
          issue,
        );
      });
    }
  });

  group('ProductionFlow', () {
    const valid = 'Quiero plantearte algo importante.';
    ProductionFlow start() =>
        const ProductionFlow(forms: plantear, modelSentence: model);

    test('a valid sentence asks the self-check', () {
      final flow = start().submit(valid);

      expect(flow.phase, ProductionPhase.selfCheck);
      expect(flow.sentence, valid);
      expect(flow.issue, isNull);
      expect(flow.isRubricComplete, isFalse);
    });

    test('an invalid sentence stays in writing with the issue', () {
      final flow = start().submit('Hola.');

      expect(flow.phase, ProductionPhase.writing);
      expect(flow.issue, ProductionIssue.tooShort);
    });

    test('an unticked rubric cannot be waved through', () {
      var flow = start().submit(valid).confirmNatural();
      expect(flow.phase, ProductionPhase.selfCheck);

      flow = flow
          .toggle(ProductionRubric.meaning)
          .toggle(ProductionRubric.natural)
          .confirmNatural();

      expect(flow.phase, ProductionPhase.selfCheck);
      expect(flow.isAccepted, isFalse);
    });

    test('every ticked rubric item accepts the production', () {
      var flow = start().submit(valid);
      for (final item in ProductionRubric.values) {
        flow = flow.toggle(item);
      }

      expect(flow.isRubricComplete, isTrue);
      expect(flow.confirmNatural().isAccepted, isTrue);
    });

    test('unticking an item takes the rubric back', () {
      var flow = start().submit(valid);
      for (final item in ProductionRubric.values) {
        flow = flow.toggle(item);
      }
      flow = flow.toggle(ProductionRubric.fits);

      expect(flow.isRubricComplete, isFalse);
      expect(flow.confirmNatural().isAccepted, isFalse);
    });

    test('"quiero ajustarla" returns to writing and clears the rubric', () {
      final flow = start()
          .submit(valid)
          .toggle(ProductionRubric.meaning)
          .rejectNatural();

      expect(flow.phase, ProductionPhase.writing);
      expect(flow.sentence, valid);
      expect(flow.confirmed, isEmpty);
    });
  });
}
