import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:material_ui/material_ui.dart';

class SectionHeader extends StatelessWidget {
  const new({required this.title, super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    return Padding(
      padding: const EdgeInsets.only(bottom: FluiSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: FluiTypography.h3.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
