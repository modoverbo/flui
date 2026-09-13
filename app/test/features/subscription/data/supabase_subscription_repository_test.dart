import 'package:flui/features/subscription/data/supabase_subscription_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/supabase_recorder.dart';

void main() {
  group('SupabaseSubscriptionRepository.fetchPlans', () {
    test('reads active plans in ascending sort order', () async {
      final recorder = SupabaseRecorder(
        respond: (_) => [
          {
            'id': 'monthly',
            'billing_period_days': 30,
            'price_cents': 699,
            'currency': 'USD',
            'label': 'Mensual',
            'savings_label': null,
            'sort_order': 1,
          },
        ],
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseSubscriptionRepository(recorder.client)
          .fetchPlans();

      expect(result.valueOrNull!.single.id, 'monthly');
      final url = recorder.last.url;
      expect(url.path, '/rest/v1/subscription_plans');
      expect(url.queryParameters['active'], 'eq.true');
      expect(url.queryParameters['order'], startsWith('sort_order.asc'));
    });
  });
}
