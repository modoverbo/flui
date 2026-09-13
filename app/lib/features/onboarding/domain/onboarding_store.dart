// Named parameters cannot be private, so the private fields of the
// in-memory store are assigned in the initializer list.
// ignore_for_file: prefer_initializing_formals

import 'package:flui/features/onboarding/domain/onboarding_answers.dart';

/// Where the pre-signup answers live until there is an account to attach
/// them to.
abstract interface class OnboardingStore {
  Future<OnboardingAnswers> readAnswers();

  Future<void> writeAnswers(OnboardingAnswers answers);

  /// The plan the user picked before creating the account, so the paywall
  /// opens on the decision instead of asking again.
  Future<String?> readSelectedPlanId();

  Future<void> writeSelectedPlanId(String planId);
}

/// In-memory store: the fake backend, tests, and any platform where
/// preferences are unavailable.
final class InMemoryOnboardingStore implements OnboardingStore {
  new({OnboardingAnswers answers = OnboardingAnswers.empty, String? planId})
    : _answers = answers,
      _planId = planId;

  OnboardingAnswers _answers;
  String? _planId;

  @override
  Future<OnboardingAnswers> readAnswers() async => _answers;

  @override
  Future<void> writeAnswers(OnboardingAnswers answers) async =>
      _answers = answers;

  @override
  Future<String?> readSelectedPlanId() async => _planId;

  @override
  Future<void> writeSelectedPlanId(String planId) async => _planId = planId;
}
