import 'dart:async';

import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/l10n/failure_messages.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/daily/domain/time_budget.dart';
import 'package:flui/features/daily/presentation/controllers/time_budget_controller.dart';
import 'package:flui/features/daily/presentation/widgets/budget_choice_card.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_glyph.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:flui/shared/widgets/flui_notice.dart';
import 'package:flui/shared/widgets/page_frame.dart';
import 'package:flui/shared/widgets/sticky_cta_dock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// `/today/time`: "¿Cuánto tiempo tienes hoy?", asked once per local day.
class TimeBudgetPage extends ConsumerWidget {
  const new({super.key});

  static String lineFor(AppLocalizations l10n, TimeBudget budget) =>
      switch (budget) {
        TimeBudget.five => l10n.timeBudgetFiveLine,
        TimeBudget.ten => l10n.timeBudgetTenLine,
        TimeBudget.twenty => l10n.timeBudgetTwentyLine,
        TimeBudget.thirty => l10n.timeBudgetThirtyLine,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final layout = context.layout;
    final preselected = ref.watch(preselectedBudgetProvider);
    final state = ref.watch(timeBudgetControllerProvider);
    final controller = ref.read(timeBudgetControllerProvider.notifier);
    final selected =
        state.selected ??
        preselected.value ??
        (preselected.hasError ? TimeBudget.fallback : null);
    final failure = state.failure;

    Future<void> start(TimeBudget budget) async {
      final saved = await controller.start(budget);
      if (saved && context.mounted) context.go(AppRoutes.today);
    }

    return Scaffold(
      body: StickyCtaDock(
        dock: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (failure != null) ...[
              FluiNotice(message: failureMessage(l10n, failure)),
              const SizedBox(height: FluiSpacing.sm),
            ],
            FluiButton.primary(
              label: l10n.timeBudgetStart,
              isLoading: state.saving,
              onPressed: selected == null
                  ? null
                  : () => unawaited(start(selected)),
            ),
          ],
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(
              bottom: StickyCtaDock.reservedHeight,
            ),
            child: PageFrame.column(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: layout.blockGap),
                  Row(
                    children: [
                      const FluiGlyphIcon(
                        FluiGlyph.goal,
                        color: FluiColors.greenSecondary,
                      ),
                      const SizedBox(width: FluiSpacing.xs),
                      FluiLabel(l10n.todayBentoTimeLabel),
                    ],
                  ),
                  const SizedBox(height: FluiSpacing.sm),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.timeBudgetTitle,
                      style: layout.type.titleL.copyWith(
                        color: FluiColors.charcoal,
                      ),
                    ),
                  ),
                  const SizedBox(height: FluiSpacing.xs),
                  Text(
                    l10n.timeBudgetBody,
                    style: layout.type.bodyL.copyWith(color: FluiColors.gray),
                  ),
                  SizedBox(height: layout.blockGap),
                  for (final budget in TimeBudget.values) ...[
                    BudgetChoiceCard(
                      minutes: budget.minutes,
                      line: lineFor(l10n, budget),
                      selected: budget == selected,
                      onTap: () => controller.select(budget),
                    ),
                    const SizedBox(height: FluiSpacing.sm),
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
