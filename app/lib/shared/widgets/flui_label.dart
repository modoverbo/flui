import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_type_scale.dart';
import 'package:material_ui/material_ui.dart';

/// An eyebrow: 13 px, semibold, +6 % tracking, set in caps.
///
/// The copy stays sentence case in the ARB file; the caps are typography.
class FluiLabel extends StatelessWidget {
  const new(this.text, {super.key, this.color, this.onDark = false});

  final String text;
  final Color? color;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      FluiTypeScale.labelText(text),
      style: context.type.label.copyWith(
        color:
            color ??
            (onDark ? FluiColors.creamMuted : FluiColors.greenSecondary),
      ),
      // Screen readers should hear the word, not the shouting.
      semanticsLabel: text,
    );
  }
}

/// A section header: the eyebrow, its glyph and an optional trailing action.
class SectionHeader extends StatelessWidget {
  const new({
    required this.title,
    super.key,
    this.glyph,
    this.trailing,
    this.onDark = false,
  });

  final String title;

  /// A `FluiGlyphIcon` at the section size, never inside a tinted box.
  final Widget? glyph;
  final Widget? trailing;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final glyph = this.glyph;
    final trailing = this.trailing;
    return Padding(
      padding: const EdgeInsets.only(bottom: FluiSpacing.md),
      child: Row(
        children: [
          if (glyph != null) ...[
            IconTheme(
              data: IconThemeData(
                color: onDark
                    ? FluiColors.creamMuted
                    : FluiColors.greenSecondary,
              ),
              child: glyph,
            ),
            const SizedBox(width: FluiSpacing.xs),
          ],
          Expanded(
            child: Semantics(
              header: true,
              child: FluiLabel(title, onDark: onDark),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// The title of a screen, in [FluiTypeScale.titleL].
class PageHeader extends StatelessWidget {
  const new({
    required this.title,
    super.key,
    this.subtitle,
    this.trailing,
    this.onDark = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
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
                  style: type.titleL.copyWith(
                    color: onDark ? FluiColors.cream : FluiColors.charcoal,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: FluiSpacing.xs),
                Text(
                  subtitle,
                  style: type.body.copyWith(
                    color: onDark ? FluiColors.creamMuted : FluiColors.gray,
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
