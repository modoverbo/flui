import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_type_scale.dart';
import 'package:material_ui/material_ui.dart';

/// A wrapping row of single-choice filter chips.
class ChoiceChips<T> extends StatelessWidget {
  const new({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    super.key,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: FluiSpacing.xs,
      runSpacing: FluiSpacing.xs,
      children: [
        for (final value in values)
          ChoiceChip(
            label: Text(labelOf(value)),
            selected: value == selected,
            onSelected: (_) => onSelected(value),
            showCheckmark: false,
            labelStyle: FluiTypeScale.compact.body.copyWith(
              fontWeight: FontWeight.w600,
              color: FluiColors.ink,
            ),
            labelPadding: const EdgeInsets.symmetric(
              horizontal: FluiSpacing.xs,
            ),
            selectedColor: FluiColors.acidLime,
            backgroundColor: FluiColors.softPink,
            side: BorderSide(
              color: value == selected ? FluiColors.ink : FluiColors.ink,
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: FluiRadii.chipAll,
            ),
            materialTapTargetSize: MaterialTapTargetSize.padded,
          ),
      ],
    );
  }
}

/// A chip that expands to show one answer: the objection handler of the
/// paywall, and any other "I have a question first" moment.
class ExpandableChip extends StatefulWidget {
  const new({required this.question, required this.answer, super.key});

  final String question;
  final String answer;

  @override
  State<ExpandableChip> createState() => _ExpandableChipState();
}

class _ExpandableChipState extends State<ExpandableChip> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    const type = FluiTypeScale.compact;
    return Semantics(
      button: true,
      expanded: _open,
      label: widget.question,
      child: Material(
        color: FluiColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: FluiRadii.chipAll,
          side: BorderSide(color: FluiColors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: FluiSpacing.md,
              vertical: FluiSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.question,
                  style: type.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: FluiColors.charcoal,
                  ),
                ),
                if (_open) ...[
                  const SizedBox(height: FluiSpacing.xs),
                  Text(
                    widget.answer,
                    style: type.body.copyWith(color: FluiColors.gray),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
