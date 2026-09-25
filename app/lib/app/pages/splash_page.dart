import 'dart:async';

import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/subscription/domain/access_gate.dart';
import 'package:flui/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_logo.dart';
import 'package:flui/shared/widgets/loading_wave.dart';
import 'package:flui/shared/widgets/page_frame.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Shown while the session and access are restored (app start, reload,
/// deep links). Offers a retry when `my_access()` fails.
class SplashPage extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final layout = context.layout;
    final failed = ref.watch(accessGateProvider) == AccessGate.error;

    return Scaffold(
      backgroundColor: FluiColors.paper,
      body: SafeArea(
        child: Center(
          child: PageFrame.column(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FluiLogo(symbolSize: 48),
                SizedBox(height: layout.blockGap),
                LoadingWave(semanticLabel: l10n.commonLoading, size: 72),
                if (failed) ...[
                  SizedBox(height: layout.blockGap),
                  Text(
                    l10n.splashError,
                    textAlign: TextAlign.center,
                    style: layout.type.bodyL.copyWith(color: FluiColors.ink),
                  ),
                  const SizedBox(height: FluiSpacing.md),
                  FluiButton.primary(
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
