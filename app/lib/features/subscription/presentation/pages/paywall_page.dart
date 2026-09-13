import 'dart:async';

import 'package:flui/core/l10n/failure_messages.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/auth/presentation/controllers/sign_out_controller.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/onboarding/domain/onboarding_answers.dart';
import 'package:flui/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:flui/features/subscription/presentation/controllers/checkout_controller.dart';
import 'package:flui/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:flui/features/subscription/presentation/widgets/paywall_flow.dart';
import 'package:flui/shared/widgets/empty_state.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_logo.dart';
import 'package:flui/shared/widgets/flui_notice.dart';
import 'package:flui/shared/widgets/loading_wave.dart';
import 'package:flui/shared/widgets/page_frame.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// `/paywall`: the same three pages, now with an account behind them.
///
/// When the user already chose a plan before signing up, the flow opens on
/// the decision instead of walking them through the pitch a second time.
class PaywallPage extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends ConsumerState<PaywallPage> {
  String? _selectedPlanId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final plans = ref.watch(subscriptionPlansProvider);
    final checkout = ref.watch(checkoutControllerProvider);
    final signingOut = ref.watch(signOutControllerProvider);
    final user = ref.watch(authUserProvider).value;
    final answers =
        ref.watch(onboardingAnswersControllerProvider).value ??
        OnboardingAnswers.empty;
    final preselected = ref.watch(preselectedPlanProvider).value;
    final failure = checkout.failure;

    return Scaffold(
      body: switch (plans) {
        AsyncValue(hasValue: true, :final value?) when value.isNotEmpty =>
          PaywallFlow(
            mode: PaywallMode.checkout,
            plans: value,
            name: user?.displayName,
            answers: answers,
            initialStep: preselected == null
                ? PaywallStep.plan
                : PaywallStep.choose,
            selectedPlanId: _selectedPlanId ?? preselected,
            isBusy: checkout.isBusy,
            onSelected: (id) => setState(() => _selectedPlanId = id),
            onFinish: (id) => unawaited(
              ref.read(checkoutControllerProvider.notifier).start(id),
            ),
            header: _Header(
              signingOut: signingOut,
              onSignOut: () => unawaited(
                ref.read(signOutControllerProvider.notifier).signOut(),
              ),
            ),
            footer: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (failure != null) ...[
                  const SizedBox(height: FluiSpacing.sm),
                  FluiNotice(message: failureMessage(l10n, failure)),
                ],
                if (checkout.status == CheckoutStatus.alreadySubscribed) ...[
                  const SizedBox(height: FluiSpacing.sm),
                  FluiNotice(
                    message: l10n.paywallAlreadySubscribed,
                    tone: FluiNoticeTone.info,
                  ),
                ],
              ],
            ),
          ),
        AsyncValue(hasValue: true) || AsyncError() => SafeArea(
          child: PageFrame.column(
            child: Padding(
              padding: const EdgeInsets.only(top: FluiSpacing.xl),
              child: EmptyState(
                title: l10n.paywallPlansError,
                message: l10n.errorNetwork,
                actionLabel: l10n.commonRetry,
                onAction: () => ref.invalidate(subscriptionPlansProvider),
              ),
            ),
          ),
        ),
        _ => Center(child: LoadingWave(semanticLabel: l10n.commonLoading)),
      },
    );
  }
}

class _Header extends StatelessWidget {
  const new({required this.signingOut, required this.onSignOut});

  final bool signingOut;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return PageFrame.column(
      child: Row(
        children: [
          const Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: FluiLogo(symbolSize: 28),
              ),
            ),
          ),
          FluiButton.text(
            label: context.l10n.paywallSignOut,
            isLoading: signingOut,
            onPressed: onSignOut,
          ),
        ],
      ),
    );
  }
}
