import 'package:flui/features/onboarding/domain/onboarding_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_providers.g.dart';

/// Overridden in `bootstrap.dart` (preferences or in memory) and in tests.
@Riverpod(keepAlive: true)
OnboardingStore onboardingStore(Ref ref) {
  throw UnimplementedError('onboardingStoreProvider must be overridden.');
}

/// The plan chosen before the account existed, if any.
@Riverpod(keepAlive: true)
class PreselectedPlan extends _$PreselectedPlan {
  @override
  Future<String?> build() =>
      ref.watch(onboardingStoreProvider).readSelectedPlanId();

  Future<void> choose(String planId) async {
    state = AsyncData(planId);
    await ref.read(onboardingStoreProvider).writeSelectedPlanId(planId);
  }
}
