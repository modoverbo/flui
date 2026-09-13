import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/subscription/presentation/controllers/checkout_return_controller.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_plate.dart';
import 'package:flui/shared/widgets/loading_wave.dart';
import 'package:flui/shared/widgets/page_frame.dart';
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
    final layout = context.layout;
    final type = layout.type;
    final state = ref.watch(checkoutReturnControllerProvider);
    final timedOut = state == CheckoutReturnState.timedOut;

    return Scaffold(
      backgroundColor: FluiColors.greenDeep,
      body: FluiPlate.fullBleed(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: PageFrame.column(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: timedOut
                          ? const PlateWaveMark(size: 96, opacity: 0.9)
                          : LoadingWave(
                              semanticLabel: l10n.checkoutReturnActivating,
                              size: 96,
                              color: FluiColors.cream,
                            ),
                    ),
                    SizedBox(height: layout.blockGap),
                    Semantics(
                      header: true,
                      liveRegion: true,
                      child: Text(
                        timedOut
                            ? l10n.checkoutReturnTimeoutTitle
                            : l10n.checkoutReturnActivating,
                        style: type.displayL.copyWith(color: FluiColors.cream),
                      ),
                    ),
                    const SizedBox(height: FluiSpacing.md),
                    Text(
                      timedOut
                          ? l10n.checkoutReturnTimeoutBody
                          : l10n.checkoutReturnActivatingBody,
                      style: type.bodyL.copyWith(color: FluiColors.creamMuted),
                    ),
                    if (timedOut) ...[
                      SizedBox(height: layout.blockGap),
                      FluiButton.accent(
                        label: l10n.checkoutReturnRetry,
                        onPressed: () => ref
                            .read(checkoutReturnControllerProvider.notifier)
                            .retry(),
                      ),
                      const SizedBox(height: FluiSpacing.sm),
                      FluiButton.outline(
                        label: l10n.checkoutReturnBackToPlans,
                        onDark: true,
                        onPressed: () => context.go(AppRoutes.paywall),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
