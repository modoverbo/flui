import 'package:flui/features/onboarding/domain/onboarding_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The plan picked before signup, on the device.
///
/// Every call swallows platform failures: losing the pre-signup plan choice
/// must never block the flow that collects it.
final class PreferencesOnboardingStore implements OnboardingStore {
  const new(this._preferences);

  static const planKey = 'flui.onboarding.planId';

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> readSelectedPlanId() async {
    try {
      return await _preferences.getString(planKey);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> writeSelectedPlanId(String planId) async {
    try {
      await _preferences.setString(planKey, planId);
    } on Object {
      // See writeAnswers.
    }
  }
}
