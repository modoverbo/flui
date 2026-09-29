import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/flows/app_flow.dart';

void main() {
  testWidgets('first day on the fake backend completes a session', (
    tester,
  ) async {
    await runFirstRunFlow(tester);
  });
}
