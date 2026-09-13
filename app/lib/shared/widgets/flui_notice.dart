import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:material_ui/material_ui.dart';

enum FluiNoticeTone { hint, info }

/// Short inline message: kind feedback on a soft background, never red.
class FluiNotice extends StatelessWidget {
  const new({
    required this.message,
    super.key,
    this.tone = FluiNoticeTone.hint,
    this.icon,
  });

  final String message;
  final FluiNoticeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, defaultIcon) = switch (tone) {
      FluiNoticeTone.hint => (
        FluiColors.yellowTint,
        FluiColors.charcoal,
        LucideIcons.info,
      ),
      FluiNoticeTone.info => (
        FluiColors.greenTint,
        FluiColors.greenDeep,
        LucideIcons.circle_check,
      ),
    };
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: FluiRadii.mdAll,
        ),
        child: Padding(
          padding: const EdgeInsets.all(FluiSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon ?? defaultIcon, size: 20, color: foreground),
              const SizedBox(width: FluiSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: FluiTypography.body.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
