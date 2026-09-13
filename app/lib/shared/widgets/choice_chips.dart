import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_typography.dart';
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
            labelStyle: FluiTypography.label.copyWith(
              color: value == selected ? FluiColors.cream : FluiColors.charcoal,
            ),
            selectedColor: FluiColors.greenDeep,
            backgroundColor: FluiColors.surface,
            side: const BorderSide(color: FluiColors.outline),
            materialTapTargetSize: MaterialTapTargetSize.padded,
          ),
      ],
    );
  }
}
