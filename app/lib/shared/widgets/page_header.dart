import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:material_ui/material_ui.dart';

/// Title and optional subtitle at the top of a tab.
class PageHeader extends StatelessWidget {
  const new({required this.title, super.key, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = this.subtitle;
    final trailing = this.trailing;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: FluiTypography.h1.copyWith(color: scheme.onSurface),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: FluiSpacing.xxs),
                Text(
                  subtitle,
                  style: FluiTypography.body.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
