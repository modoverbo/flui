import 'dart:async';

import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_theme.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:flui/features/auth/presentation/controllers/sign_out_controller.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/profile/presentation/subscription_summary.dart';
import 'package:flui/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:flui/shared/widgets/content_column.dart';
import 'package:flui/shared/widgets/empty_state.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_card.dart';
import 'package:flui/shared/widgets/section_header.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// "Tu progreso". Phase A: greeting, plan status and sign out.
/// Phase B adds streaks, weekly consistency and word stats.
class ProgressPage extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final user = ref.watch(authUserProvider).value;
    final access = ref.watch(currentAccessProvider);
    final signingOut = ref.watch(signOutControllerProvider);
    final name = user?.displayName;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: FluiSpacing.lg),
          child: ContentColumn(
            maxWidth: FluiSpacing.appContentMaxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Theme(
                  data: FluiTheme.progressSurface(),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: FluiColors.progressSurface,
                      borderRadius: FluiRadii.xlAll,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(FluiSpacing.lg),
                      child: Semantics(
                        header: true,
                        child: Text(
                          name == null
                              ? l10n.progressGreetingAnonymous
                              : l10n.progressGreeting(name),
                          style: FluiTypography.h1.copyWith(
                            color: FluiColors.cream,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: FluiSpacing.xl),
                SectionHeader(title: l10n.progressPlanTitle),
                FluiCard(
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.badge_check,
                        color: FluiColors.greenDeep,
                      ),
                      const SizedBox(width: FluiSpacing.md),
                      Expanded(
                        child: Text(
                          subscriptionSummary(l10n, access),
                          style: FluiTypography.bodyEmphasis.copyWith(
                            color: FluiColors.charcoal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: FluiSpacing.xl),
                EmptyState(
                  title: l10n.commonComingSoon,
                  message: l10n.wordsComingSoonBody,
                ),
                const SizedBox(height: FluiSpacing.lg),
                FluiButton.outline(
                  label: l10n.progressSignOut,
                  icon: LucideIcons.log_out,
                  isLoading: signingOut,
                  onPressed: () => unawaited(
                    ref.read(signOutControllerProvider.notifier).signOut(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
