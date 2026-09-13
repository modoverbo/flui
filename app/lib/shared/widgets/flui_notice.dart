import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:material_ui/material_ui.dart';

enum FluiNoticeTone { hint, info, onDark }

/// Short inline message: kind feedback on a soft background, never red.
class FluiNotice extends StatelessWidget {
  const new({
    required this.message,
    super.key,
    this.tone = FluiNoticeTone.hint,
    this.icon,
    this.glyph,
  });

  final String message;
  final FluiNoticeTone tone;
  final IconData? icon;

  /// A custom glyph instead of a Lucide icon.
  final Widget? glyph;

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
      FluiNoticeTone.onDark => (
        FluiColors.greenDeep,
        FluiColors.cream,
        LucideIcons.circle_check,
      ),
    };
    final glyph = this.glyph;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: FluiRadii.cardAll,
        ),
        child: Padding(
          padding: const EdgeInsets.all(FluiSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTheme(
                data: IconThemeData(color: foreground, size: 18),
                child: glyph ?? Icon(icon ?? defaultIcon),
              ),
              const SizedBox(width: FluiSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: context.type.body.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
