import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:flui/features/subscription/presentation/controllers/checkout_return_controller.dart';
import 'package:flui/shared/widgets/content_column.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_symbol.dart';
import 'package:flui/shared/widgets/loading_wave.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// `/checkout/return`: Whop sends the user here; wait for the webhook.
/// The router moves on to the time budget as soon as access is granted.
class CheckoutReturnPage extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(checkoutReturnControllerProvider);
    final timedOut = state == CheckoutReturnState.timedOut;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: FluiSpacing.lg),
            child: ContentColumn(
              child: Column(
                children: [
                  if (timedOut)
                    const FluiSymbol(size: 72)
                  else
                    LoadingWave(
                      semanticLabel: l10n.checkoutReturnActivating,
                      size: 96,
                    ),
                  const SizedBox(height: FluiSpacing.xl),
                  Text(
                    timedOut
                        ? l10n.checkoutReturnTimeoutTitle
                        : l10n.checkoutReturnActivating,
                    textAlign: TextAlign.center,
                    style: FluiTypography.h1.copyWith(
                      color: FluiColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: FluiSpacing.sm),
                  Text(
                    timedOut
                        ? l10n.checkoutReturnTimeoutBody
                        : l10n.checkoutReturnActivatingBody,
                    textAlign: TextAlign.center,
                    style: FluiTypography.body.copyWith(color: FluiColors.gray),
                  ),
                  if (timedOut) ...[
                    const SizedBox(height: FluiSpacing.xl),
                    FluiButton.primary(
                      label: l10n.checkoutReturnRetry,
                      onPressed: () => ref
                          .read(checkoutReturnControllerProvider.notifier)
                          .retry(),
                    ),
                    const SizedBox(height: FluiSpacing.sm),
                    FluiButton.outline(
                      label: l10n.checkoutReturnBackToPlans,
                      onPressed: () => context.go(AppRoutes.paywall),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
