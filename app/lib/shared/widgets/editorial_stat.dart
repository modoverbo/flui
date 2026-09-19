import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:material_ui/material_ui.dart';

/// An oversized numeral with a short label under it: the editorial
/// replacement for a KPI tile (`docs/redesign/01-design-system.md` §2 —
/// "numbers are content, not metadata").
///
/// [value] is rendered through a `FittedBox`, so it shrinks to fit whatever
/// bounded width the caller gives it (a `SizedBox`, a `Wrap` cell, a
/// training card) instead of overflowing at a large text scale. Callers are
/// responsible for never passing a bare "0" — this widget renders whatever
/// it is given, honestly.
class EditorialStat extends StatelessWidget {
  const new({
    required this.value,
    required this.label,
    super.key,
    this.onDark = false,
    this.onTap,
    this.semanticLabel,
    this.caption,
  });

  /// The number, pre-formatted (e.g. `'12'`, `'84 %'`).
  final String value;

  /// The short label under the number, in sentence case — rendered through
  /// `FluiLabel`, which upper-cases it.
  final String label;
  final bool onDark;
  final VoidCallback? onTap;
  final String? semanticLabel;

  /// An optional caption under the label, e.g. precision's rolling window.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final color = onDark ? FluiColors.cream : FluiColors.ink;
    final onTap = this.onTap;
    final caption = this.caption;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: type.numeralHero.copyWith(color: color),
          ),
        ),
        const SizedBox(height: FluiSpacing.xxs),
        FluiLabel(label, onDark: onDark),
        if (caption != null) ...[
          const SizedBox(height: 2),
          Text(
            caption,
            style: type.body.copyWith(
              color: onDark ? FluiColors.creamMuted : FluiColors.gray,
            ),
          ),
        ],
      ],
    );
    return Semantics(
      label: semanticLabel ?? '$value $label',
      excludeSemantics: true,
      button: onTap != null,
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: FluiSpacing.xs),
                child: content,
              ),
            ),
    );
  }
}
