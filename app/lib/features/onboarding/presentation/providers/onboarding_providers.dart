import 'package:flui/features/onboarding/domain/onboarding_answers.dart';
import 'package:flui/features/onboarding/domain/onboarding_store.dart';
import 'package:flui/features/reading/domain/reading.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_providers.g.dart';

/// Overridden in `bootstrap.dart` (preferences or in memory) and in tests.
@Riverpod(keepAlive: true)
OnboardingStore onboardingStore(Ref ref) {
  throw UnimplementedError('onboardingStoreProvider must be overridden.');
}

/// The two pre-signup answers. Every change is written through, because the
/// user may close the tab between the question and the account.
@Riverpod(keepAlive: true)
class OnboardingAnswersController extends _$OnboardingAnswersController {
  @override
  Future<OnboardingAnswers> build() =>
      ref.watch(onboardingStoreProvider).readAnswers();

  Future<void> toggleContext(Scene scene) async {
    final current = state.value ?? OnboardingAnswers.empty;
    await _save(
      current.withContext(scene, selected: !current.contexts.contains(scene)),
    );
  }

  Future<void> chooseTone(SpeakingTone tone) async {
    final current = state.value ?? OnboardingAnswers.empty;
    await _save(current.withTone(tone));
  }

  Future<void> _save(OnboardingAnswers answers) async {
    state = AsyncData(answers);
    await ref.read(onboardingStoreProvider).writeAnswers(answers);
  }
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
