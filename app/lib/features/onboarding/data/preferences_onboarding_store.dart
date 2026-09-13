import 'dart:convert';

import 'package:flui/features/onboarding/domain/onboarding_answers.dart';
import 'package:flui/features/onboarding/domain/onboarding_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The answers on the device, as one JSON string.
///
/// Every call swallows platform failures: losing two onboarding answers must
/// never block the flow that collects them.
final class PreferencesOnboardingStore implements OnboardingStore {
  const new(this._preferences);

  static const answersKey = 'flui.onboarding.answers';
  static const planKey = 'flui.onboarding.planId';

  final SharedPreferencesAsync _preferences;

  @override
  Future<OnboardingAnswers> readAnswers() async {
    try {
      final raw = await _preferences.getString(answersKey);
      if (raw == null) return OnboardingAnswers.empty;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return OnboardingAnswers.empty;
      return OnboardingAnswers.fromJson(decoded);
    } on Object {
      return OnboardingAnswers.empty;
    }
  }

  @override
  Future<void> writeAnswers(OnboardingAnswers answers) async {
    try {
      await _preferences.setString(answersKey, jsonEncode(answers.toJson()));
    } on Object {
      // Nothing to recover: the flow continues with what is in memory.
    }
  }

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
