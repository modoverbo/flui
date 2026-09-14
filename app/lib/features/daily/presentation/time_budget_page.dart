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
import 'package:flui/features/themes/domain/theme.dart';
import 'package:flui/features/themes/presentation/providers/theme_providers.dart';
import 'package:flui/features/themes/presentation/widgets/theme_choice_card.dart';
import 'package:flui/features/themes/presentation/widgets/theme_explorer_sheet.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_glyph.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:flui/shared/widgets/flui_notice.dart';
import 'package:flui/shared/widgets/page_frame.dart';
import 'package:flui/shared/widgets/sticky_cta_dock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide Theme;

/// `/today/time`: the two questions of a new day, asked once per local date.
///
/// "¿Cuánto tiempo tienes hoy?" decides how much fits; "¿Sobre qué tema?"
/// decides which new word shows up. Neither is a commitment: both are asked
/// again tomorrow, and changing either recomputes the same plan.
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
    final selectedThemeId =
        state.selectedThemeId ?? ref.watch(preselectedThemeIdProvider).value;
    final failure = state.failure;

    Future<void> start(TimeBudget budget) async {
      final saved = await controller.start(budget, themeId: selectedThemeId);
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
                  SizedBox(height: layout.blockGap),
                  _ThemeQuestion(selectedThemeId: selectedThemeId),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "¿Sobre qué tema?": three cards, a door to the rest, and a dice.
class _ThemeQuestion extends ConsumerWidget {
  const new({required this.selectedThemeId});

  final String? selectedThemeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final layout = context.layout;
    final controller = ref.read(timeBudgetControllerProvider.notifier);
    final offered = ref.watch(offeredThemesProvider).value ?? const <Theme>[];
    final recommended =
        ref.watch(recommendedThemesProvider).value ?? const <Theme>[];
    final recent = ref.watch(recentThemesProvider).value ?? const <Theme>[];

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const FluiGlyphIcon(
              FluiGlyph.onda,
              color: FluiColors.greenSecondary,
            ),
            const SizedBox(width: FluiSpacing.xs),
            FluiLabel(l10n.themeSectionLabel),
          ],
        ),
        const SizedBox(height: FluiSpacing.sm),
        Semantics(
          header: true,
          child: Text(
            l10n.themeQuestionTitle,
            style: layout.type.titleL.copyWith(color: FluiColors.charcoal),
          ),
        ),
        const SizedBox(height: FluiSpacing.xs),
        Text(
          l10n.themeQuestionBody,
          style: layout.type.bodyL.copyWith(color: FluiColors.gray),
        ),
      ],
    );

    if (offered.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          SizedBox(height: layout.blockGap),
          Text(
            l10n.themeNoneAvailable,
            style: layout.type.body.copyWith(color: FluiColors.gray),
          ),
        ],
      );
    }

    // The chosen theme is always on screen, even when it came from the
    // "Explorar" sheet or from yesterday: a selection you cannot see is a
    // selection you cannot change.
    final shown = <String>{};
    final chosen = offered.where((t) => t.id == selectedThemeId).firstOrNull;
    final mine = [
      for (final theme in recent)
        if (shown.add(theme.id)) theme,
    ];
    final foryou = [
      for (final theme in recommended)
        if (shown.add(theme.id)) theme,
    ];
    final loose = chosen != null && !shown.contains(chosen.id) ? chosen : null;

    Widget card(Theme theme) => Padding(
      padding: const EdgeInsets.only(bottom: FluiSpacing.sm),
      child: ThemeChoiceCard(
        theme: theme,
        selected: theme.id == selectedThemeId,
        onTap: () => controller.selectTheme(theme.id),
      ),
    );

    Future<void> explore() async {
      final picked = await showThemeExplorer(
        context,
        themes: offered,
        selectedId: selectedThemeId,
      );
      if (picked != null) controller.selectTheme(picked.id);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        SizedBox(height: layout.blockGap),
        if (loose != null) card(loose),
        if (mine.isNotEmpty) ...[
          FluiLabel(l10n.themeYours),
          const SizedBox(height: FluiSpacing.xs),
          for (final theme in mine) card(theme),
          const SizedBox(height: FluiSpacing.xs),
        ],
        if (foryou.isNotEmpty) ...[
          FluiLabel(l10n.themeRecommended),
          const SizedBox(height: FluiSpacing.xs),
          for (final theme in foryou) card(theme),
        ],
        const SizedBox(height: FluiSpacing.xs),
        Row(
          children: [
            Expanded(
              child: FluiButton.outline(
                label: l10n.themeExplore,
                onPressed: () => unawaited(explore()),
              ),
            ),
            const SizedBox(width: FluiSpacing.sm),
            Expanded(
              child: FluiButton.text(
                label: l10n.themeSurprise,
                expand: true,
                onPressed: () =>
                    unawaited(controller.surpriseTheme(selectedThemeId)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
