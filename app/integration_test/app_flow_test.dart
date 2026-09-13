import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/app_flow.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'first day: register → paywall → time budget → session → progress',
    (tester) async {
      await runFirstRunFlow(tester);
    },
  );
}
