import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/vocabulary/domain/exercises/production_check.dart';
import 'package:flui/features/vocabulary/presentation/widgets/highlighted_text.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_text_field.dart';
import 'package:material_ui/material_ui.dart';

/// Úsala (2/2): the user's own sentence, then "¿Suena natural?".
class ProductionView extends StatefulWidget {
  const new({
    required this.flow,
    required this.lemma,
    required this.beforePhrase,
    required this.onSubmit,
    required this.onConfirm,
    required this.onRevise,
    required this.onToggle,
    super.key,
    this.busy = false,
  });

  final ProductionFlow flow;
  final String lemma;

  /// A vague phrase the word replaces, used as the situation.
  final String beforePhrase;
  final ValueChanged<String> onSubmit;
  final VoidCallback onConfirm;
  final VoidCallback onRevise;
  final ValueChanged<ProductionRubric> onToggle;
  final bool busy;

  @override
  State<ProductionView> createState() => _ProductionViewState();
}

class _ProductionViewState extends State<ProductionView> {
  late final _controller = TextEditingController(text: widget.flow.sentence);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final flow = widget.flow;
    final issue = flow.issue;
    final type = context.type;
    final title = Semantics(
      header: true,
      child: Text(
        flow.phase == ProductionPhase.writing
            ? l10n.productionTitle
            : l10n.productionSelfCheckTitle,
        style: type.titleL.copyWith(color: FluiColors.charcoal),
      ),
    );

    if (flow.phase != ProductionPhase.writing) {
      final model = flow.modelSentence;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          const SizedBox(height: FluiSpacing.xs),
          Text(
            l10n.productionSelfCheckBody,
            style: type.body.copyWith(color: FluiColors.gray),
          ),
          const SizedBox(height: FluiSpacing.lg),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: FluiColors.greenTint,
              borderRadius: FluiRadii.cardAll,
            ),
            child: Padding(
              padding: const EdgeInsets.all(FluiSpacing.lg),
              child: HighlightedText(
                text: '«${flow.sentence}»',
                forms: flow.forms,
                style: type.bodyL.copyWith(color: FluiColors.charcoal),
              ),
            ),
          ),
          if (model != null) ...[
            const SizedBox(height: FluiSpacing.lg),
            Text(
              l10n.productionModelTitle,
              style: type.label.copyWith(color: FluiColors.gray),
            ),
            const SizedBox(height: FluiSpacing.xxs),
            HighlightedText(
              text: '«$model»',
              forms: flow.forms,
              style: type.body.copyWith(color: FluiColors.gray),
            ),
          ],
          const SizedBox(height: FluiSpacing.lg),
          for (final item in ProductionRubric.values)
            _RubricTile(
              label: switch (item) {
                ProductionRubric.meaning => l10n.productionRubricMeaning,
                ProductionRubric.natural => l10n.productionRubricNatural,
                ProductionRubric.fits => l10n.productionRubricFits,
              },
              checked: flow.confirmed.contains(item),
              onChanged: widget.busy ? null : () => widget.onToggle(item),
            ),
          if (!flow.isRubricComplete) ...[
            const SizedBox(height: FluiSpacing.xs),
            Text(
              l10n.productionRubricPending,
              style: type.body.copyWith(color: FluiColors.gray),
            ),
          ],
          const SizedBox(height: FluiSpacing.lg),
          FluiButton.primary(
            label: l10n.productionYes,
            isLoading: widget.busy,
            onPressed: flow.isRubricComplete ? widget.onConfirm : null,
          ),
          const SizedBox(height: FluiSpacing.sm),
          FluiButton.outline(
            label: l10n.productionNo,
            onPressed: widget.busy ? null : widget.onRevise,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title,
        const SizedBox(height: FluiSpacing.xs),
        Text(
          l10n.productionPrompt(widget.beforePhrase, widget.lemma),
          style: type.bodyL.copyWith(color: FluiColors.charcoal),
        ),
        const SizedBox(height: FluiSpacing.lg),
        FluiTextField(
          label: l10n.productionFieldLabel,
          controller: _controller,
          textCapitalization: TextCapitalization.sentences,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          onSubmitted: widget.onSubmit,
          errorText: switch (issue) {
            ProductionIssue.tooShort => l10n.productionTooShort,
            ProductionIssue.missingWord => l10n.productionMissingWord(
              widget.lemma,
            ),
            ProductionIssue.repeated => l10n.productionRepeatedWords,
            ProductionIssue.copiedModel => l10n.productionTooSimilar,
            null => null,
          },
        ),
        const SizedBox(height: FluiSpacing.lg),
        FluiButton.primary(
          label: l10n.productionSubmit,
          isLoading: widget.busy,
          onPressed: () => widget.onSubmit(_controller.text),
        ),
      ],
    );
  }
}

/// One rubric line: a checkbox the user ticks about their own sentence.
class _RubricTile extends StatelessWidget {
  const new({
    required this.label,
    required this.checked,
    required this.onChanged,
  });

  final String label;
  final bool checked;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged,
      borderRadius: FluiRadii.chipAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: FluiSpacing.xxs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: checked,
              onChanged: onChanged == null ? null : (_) => onChanged!(),
            ),
            const SizedBox(width: FluiSpacing.xs),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: FluiSpacing.sm),
                child: Text(
                  label,
                  style: context.type.body.copyWith(color: FluiColors.charcoal),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
