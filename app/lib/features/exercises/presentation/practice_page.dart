import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/l10n/failure_messages.dart';
import 'package:flui/core/l10n/formatters.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:flui/features/daily/presentation/today_page.dart';
import 'package:flui/features/exercises/presentation/providers/practice_overview.dart';
import 'package:flui/shared/widgets/content_column.dart';
import 'package:flui/shared/widgets/empty_state.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_card.dart';
import 'package:flui/shared/widgets/loading_wave.dart';
import 'package:flui/shared/widgets/page_header.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// "Practica": due reviews and a review-only session.
class PracticePage extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final overview = ref.watch(practiceOverviewProvider);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: FluiSpacing.lg),
          child: ContentColumn(
            maxWidth: FluiSpacing.appContentMaxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  title: l10n.navPractice,
                  subtitle: l10n.practiceSubtitle,
                ),
                const SizedBox(height: FluiSpacing.lg),
                switch (overview) {
                  AsyncValue(hasValue: true, :final value?)
                      when value.dueCount > 0 =>
                    FluiCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(
                            LucideIcons.repeat,
                            color: FluiColors.greenDeep,
                          ),
                          const SizedBox(height: FluiSpacing.sm),
                          Text(
                            l10n.practiceDueCount(value.dueCount),
                            style: FluiTypography.h2.copyWith(
                              color: FluiColors.charcoal,
                            ),
                          ),
                          const SizedBox(height: FluiSpacing.lg),
                          FluiButton.primary(
                            label: l10n.practiceStart,
                            onPressed: () =>
                                context.go(AppRoutes.sessionReview),
                          ),
                        ],
                      ),
                    ),
                  AsyncValue(hasValue: true, :final value?) => EmptyState(
                    title: value.hasWords
                        ? l10n.practiceAllDone
                        : l10n.navPractice,
                    message: switch (value.nextDueOn) {
                      final due? => l10n.practiceNextDue(
                        formatLongDate(due.toDateTime()),
                      ),
                      null => l10n.practiceNoWords,
                    },
                  ),
                  AsyncError(:final error) => EmptyState(
                    title: l10n.todayLoadError,
                    message: error is Failure
                        ? failureMessage(l10n, error)
                        : l10n.errorUnexpected,
                    actionLabel: l10n.commonRetry,
                    onAction: () => retryLearningData(ref),
                  ),
                  _ => Center(
                    child: LoadingWave(semanticLabel: l10n.commonLoading),
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
