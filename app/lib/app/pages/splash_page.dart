import 'dart:async';

import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/subscription/domain/access_gate.dart';
import 'package:flui/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/loading_wave.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Shown while the session and access are restored (app start, reload,
/// deep links). Offers a retry when `my_access()` fails.
class SplashPage extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final failed = ref.watch(accessGateProvider) == AccessGate.error;

    return Scaffold(
      backgroundColor: FluiColors.greenDeep,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(FluiSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LoadingWave(
                  semanticLabel: l10n.commonLoading,
                  color: FluiColors.cream,
                  size: 96,
                ),
                if (failed) ...[
                  const SizedBox(height: FluiSpacing.lg),
                  Text(
                    l10n.splashError,
                    textAlign: TextAlign.center,
                    style: FluiTypography.bodyEmphasis.copyWith(
                      color: FluiColors.cream,
                    ),
                  ),
                  const SizedBox(height: FluiSpacing.md),
                  FluiButton.accent(
                    label: l10n.commonRetry,
                    expand: false,
                    onPressed: () {
                      final userId = ref.read(authUserProvider).value?.id;
                      if (userId == null) return;
                      unawaited(
                        ref
                            .read(
                              accessStatusControllerProvider(userId).notifier,
                            )
                            .refresh(),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
