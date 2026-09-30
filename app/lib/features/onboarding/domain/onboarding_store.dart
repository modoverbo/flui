// A named parameter cannot be private, so the in-memory store's private
// field is assigned in the initializer list.
// ignore_for_file: prefer_initializing_formals

/// Where the plan picked before signup lives until there is an account to
/// attach it to.
abstract interface class OnboardingStore {
  /// The plan the user picked before creating the account, so the paywall
  /// opens on the decision instead of asking again.
  Future<String?> readSelectedPlanId();

  Future<void> writeSelectedPlanId(String planId);
}

/// In-memory store: the fake backend, tests, and any platform where
/// preferences are unavailable.
final class InMemoryOnboardingStore implements OnboardingStore {
  new({String? planId}) : _planId = planId;

  String? _planId;

  @override
  Future<String?> readSelectedPlanId() async => _planId;

  @override
  Future<void> writeSelectedPlanId(String planId) async => _planId = planId;
}
