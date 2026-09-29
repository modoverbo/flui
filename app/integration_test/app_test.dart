import 'package:integration_test/integration_test.dart';

import 'flows/app_flow.dart';
import 'flows/spoken_usala.dart';

/// The single `integration_test` bundle entry point. `flutter test
/// integration_test -d flutter-tester` (CI's own exact command, see
/// `.github/workflows/app-ci.yml` and AGENTS.md) launches the
/// `flutter-tester` device once per `_test.dart` file it finds — with only
/// this one file present, every flow shares that single launch instead of
/// each flow relaunching the device (which this sandbox's `flutter-tester`
/// cannot always do reliably back-to-back).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerAppFlowTests();
  registerSpokenUsalaTests();
}
