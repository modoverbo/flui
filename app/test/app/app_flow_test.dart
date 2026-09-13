import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/app_flow.dart';

void main() {
  testWidgets('first run on the fake backend reaches the shell', (
    tester,
  ) async {
    await runFirstRunFlow(tester);
  });
}
