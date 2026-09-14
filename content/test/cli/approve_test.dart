import 'package:content/src/cli/approve.dart';
import 'package:test/test.dart';

void main() {
  group('planPromotion', () {
    test('promotes every gated word', () {
      final plan = planPromotion({
        'perspicaz': 'gated',
        'matizar': 'gated',
      });

      expect(plan.promoted, ['matizar', 'perspicaz']);
      expect(plan.skipped, isEmpty);
    });

    test('leaves a draft alone and says why', () {
      final plan = planPromotion({'agilizar': 'draft'});

      expect(plan.promoted, isEmpty);
      expect(plan.skipped['agilizar'], contains('draft'));
    });

    test('leaves a validated word alone: it has not been through the gate', () {
      final plan = planPromotion({'agilizar': 'validated'});

      expect(plan.promoted, isEmpty);
      expect(plan.skipped['agilizar'], contains('validated'));
    });

    test('leaves an already approved word alone', () {
      final plan = planPromotion({'zanjar': 'approved'});

      expect(plan.promoted, isEmpty);
      expect(plan.skipped['zanjar'], contains('approved'));
    });

    test('promotes only the named word', () {
      final plan = planPromotion({
        'perspicaz': 'gated',
        'matizar': 'gated',
      }, onlySlug: 'matizar');

      expect(plan.promoted, ['matizar']);
      expect(plan.skipped, isEmpty);
    });

    test('the named word is skipped when it is not gated', () {
      final plan = planPromotion({
        'agilizar': 'draft',
      }, onlySlug: 'agilizar');

      expect(plan.promoted, isEmpty);
      expect(plan.skipped['agilizar'], contains('draft'));
    });

    test('is deterministic and sorted', () {
      final plan = planPromotion({
        'zanjar': 'gated',
        'ameno': 'gated',
        'matizar': 'gated',
      });

      expect(plan.promoted, ['ameno', 'matizar', 'zanjar']);
    });
  });
}
