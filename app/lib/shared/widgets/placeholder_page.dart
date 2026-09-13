import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:flui/shared/widgets/content_column.dart';
import 'package:flui/shared/widgets/empty_state.dart';
import 'package:material_ui/material_ui.dart';

/// Branded "Muy pronto" screen for destinations that Phase B implements.
class PlaceholderPage extends StatelessWidget {
  const new({
    required this.title,
    required this.message,
    super.key,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: FluiSpacing.lg),
          child: ContentColumn(
            maxWidth: FluiSpacing.appContentMaxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: FluiTypography.h1.copyWith(
                      color: FluiColors.charcoal,
                    ),
                  ),
                ),
                const SizedBox(height: FluiSpacing.xxl),
                EmptyState(
                  title: context.l10n.commonComingSoon,
                  message: message,
                  actionLabel: actionLabel,
                  onAction: onAction,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
