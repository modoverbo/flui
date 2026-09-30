import 'dart:async';

import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:flui/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:flui/features/subscription/presentation/widgets/paywall_flow.dart';
import 'package:flui/shared/widgets/empty_state.dart';
import 'package:flui/shared/widgets/loading_wave.dart';
import 'package:flui/shared/widgets/page_frame.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// `/plan`: the paywall before the account exists.
///
/// The plans are public (`subscription_plans` is readable by `anon`), so the
/// user sees the real prices, picks one, and only then is asked for an email.
/// The choice is kept on the device and the real paywall opens straight on
/// the decision afterwards.
class PlanPreviewPage extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final plans = ref.watch(subscriptionPlansProvider);
    final selected = ref.watch(preselectedPlanProvider).value;

    return Scaffold(
      body: switch (plans) {
        AsyncValue(hasValue: true, :final value?) when value.isNotEmpty =>
          // No skill profile is ever passed here: this page runs before the
          // account exists, and diagnosis only runs after signup+trial
          // start (spec `spoken-diagnosis`), so a profile can never exist
          // yet (U14b).
          PaywallFlow(
            mode: PaywallMode.preview,
            plans: value,
            selectedPlanId: selected,
            onSelected: (id) => unawaited(
              ref.read(preselectedPlanProvider.notifier).choose(id),
            ),
            onFinish: (id) async {
              await ref.read(preselectedPlanProvider.notifier).choose(id);
              if (context.mounted) context.go(AppRoutes.register);
            },
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
