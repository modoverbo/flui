import 'dart:async';

import 'package:flui/core/l10n/failure_messages.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:flui/features/auth/presentation/controllers/sign_out_controller.dart';
import 'package:flui/features/subscription/domain/subscription_plan.dart';
import 'package:flui/features/subscription/presentation/controllers/checkout_controller.dart';
import 'package:flui/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:flui/features/subscription/presentation/widgets/plan_card.dart';
import 'package:flui/shared/widgets/content_column.dart';
import 'package:flui/shared/widgets/empty_state.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_logo.dart';
import 'package:flui/shared/widgets/flui_notice.dart';
import 'package:flui/shared/widgets/loading_wave.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// "Empieza tus 7 días gratis": choose a plan and open the Whop checkout.
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

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: FluiSpacing.lg),
          child: ContentColumn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: FluiLogo(symbolSize: 32),
                        ),
                      ),
                    ),
                    FluiButton.text(
                      label: l10n.paywallSignOut,
                      isLoading: signingOut,
                      onPressed: () => unawaited(
                        ref.read(signOutControllerProvider.notifier).signOut(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: FluiSpacing.xl),
                Semantics(
                  header: true,
                  child: Text(
                    l10n.paywallTitle,
                    style: FluiTypography.h1.copyWith(
                      color: FluiColors.charcoal,
                    ),
                  ),
                ),
                const SizedBox(height: FluiSpacing.xs),
                Text(
                  l10n.paywallSubtitle,
                  style: FluiTypography.body.copyWith(color: FluiColors.gray),
                ),
                const SizedBox(height: FluiSpacing.lg),
                switch (plans) {
                  AsyncValue(hasValue: true, :final value?) => _Plans(
                    plans: value,
                    selectedPlanId: _selectedPlanId ?? recommendedPlanId(value),
                    enabled: !checkout.isBusy,
                    onSelected: (id) => setState(() => _selectedPlanId = id),
                    onStart: (id) => unawaited(
                      ref.read(checkoutControllerProvider.notifier).start(id),
                    ),
                    checkout: checkout,
                  ),
                  AsyncError() => EmptyState(
                    title: l10n.paywallPlansError,
                    message: l10n.errorNetwork,
                    actionLabel: l10n.commonRetry,
                    onAction: () => ref.invalidate(subscriptionPlansProvider),
                  ),
                  _ => Padding(
                    padding: const EdgeInsets.all(FluiSpacing.xl),
                    child: Center(
                      child: LoadingWave(semanticLabel: l10n.commonLoading),
                    ),
                  ),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Plans extends StatelessWidget {
  const new({
    required this.plans,
    required this.selectedPlanId,
    required this.enabled,
    required this.onSelected,
    required this.onStart,
    required this.checkout,
  });

  final List<SubscriptionPlan> plans;
  final String? selectedPlanId;
  final bool enabled;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onStart;
  final CheckoutState checkout;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final recommended = recommendedPlanId(plans);
    final selected = selectedPlanId;
    final failure = checkout.failure;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final plan in plans) ...[
          PlanCard(
            plan: plan,
            selected: plan.id == selected,
            recommended: plan.id == recommended,
            onSelected: enabled ? () => onSelected(plan.id) : () {},
          ),
          const SizedBox(height: FluiSpacing.sm),
        ],
        const SizedBox(height: FluiSpacing.sm),
        FluiNotice(
          message: l10n.paywallTerms,
          tone: FluiNoticeTone.info,
          icon: LucideIcons.shield_check,
        ),
        const SizedBox(height: FluiSpacing.lg),
        if (failure != null) ...[
          FluiNotice(message: failureMessage(l10n, failure)),
          const SizedBox(height: FluiSpacing.md),
        ],
        if (checkout.status == CheckoutStatus.alreadySubscribed) ...[
          FluiNotice(
            message: l10n.paywallAlreadySubscribed,
            tone: FluiNoticeTone.info,
          ),
          const SizedBox(height: FluiSpacing.md),
        ],
        FluiButton.primary(
          label: l10n.paywallCta,
          isLoading: checkout.isBusy,
          onPressed: selected == null ? null : () => onStart(selected),
        ),
        if (checkout.status == CheckoutStatus.redirecting) ...[
          const SizedBox(height: FluiSpacing.sm),
          Text(
            l10n.paywallOpeningCheckout,
            textAlign: TextAlign.center,
            style: FluiTypography.caption.copyWith(color: FluiColors.gray),
          ),
        ],
      ],
    );
  }
}
