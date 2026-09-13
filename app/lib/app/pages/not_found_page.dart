import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/shared/widgets/content_column.dart';
import 'package:flui/shared/widgets/empty_state.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class NotFoundPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ContentColumn(
            child: EmptyState(
              title: l10n.notFoundTitle,
              message: l10n.appTitle,
              actionLabel: l10n.notFoundAction,
              onAction: () => context.go(AppRoutes.root),
            ),
          ),
        ),
      ),
    );
  }
}
