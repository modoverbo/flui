import 'package:flui/features/subscription/data/fake_subscription_repository.dart';
import 'package:flui/features/subscription/presentation/widgets/paywall_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  testWidgets(
    'a viewport shorter than the dock never throws negative constraints',
    (tester) async {
      await tester.pumpFlui(
        PaywallFlow(
          mode: PaywallMode.preview,
          plans: FakeSubscriptionRepository.seedPlans,
          selectedPlanId: null,
          onSelected: (_) {},
          onFinish: (_) {},
        ),
        surfaceSize: const Size(360, 120),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Seguir'), findsOneWidget);
    },
  );
}
