import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:flui/shared/widgets/content_column.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_symbol.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// `/today/time`. Phase B: pick 5, 10, 20 or 30 minutes (preselect
/// yesterday's choice) and plan the session.
class TimeBudgetPage extends StatelessWidget {
  const new({super.key});

  static const previewBudgets = [5, 10, 20, 30];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: FluiSpacing.lg),
            child: ContentColumn(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(child: FluiSymbol(size: 72)),
                  const SizedBox(height: FluiSpacing.xl),
                  Text(
                    l10n.timeBudgetTitle,
                    textAlign: TextAlign.center,
                    style: FluiTypography.h1.copyWith(
                      color: FluiColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: FluiSpacing.sm),
                  Text(
                    l10n.timeBudgetBody,
                    textAlign: TextAlign.center,
                    style: FluiTypography.body.copyWith(color: FluiColors.gray),
                  ),
                  const SizedBox(height: FluiSpacing.xl),
                  ExcludeSemantics(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: FluiSpacing.xs,
                      runSpacing: FluiSpacing.xs,
                      children: [
                        for (final minutes in previewBudgets)
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: FluiColors.surface,
                              borderRadius: FluiRadii.lgAll,
                              border: Border.all(color: FluiColors.outline),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: FluiSpacing.md,
                                vertical: FluiSpacing.sm,
                              ),
                              child: Text(
                                "$minutes'",
                                style: FluiTypography.h2.copyWith(
                                  color: FluiColors.gray,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: FluiSpacing.xl),
                  FluiButton.primary(
                    label: l10n.timeBudgetContinue,
                    onPressed: () => context.go(AppRoutes.today),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
