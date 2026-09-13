import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/shared/widgets/placeholder_page.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// "Hoy". Phase B: today's session (SessionPlanner, daily_sessions).
class TodayPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PlaceholderPage(
      title: l10n.navToday,
      message: l10n.todayComingSoonBody,
      actionLabel: l10n.timeBudgetTitle,
      onAction: () => context.go(AppRoutes.timeBudget),
    );
  }
}
